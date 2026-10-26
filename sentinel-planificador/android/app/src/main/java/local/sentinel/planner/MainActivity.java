package local.sentinel.planner;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import androidx.core.content.FileProvider;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import org.json.JSONObject;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Offline project tracker only. No operational SENTINEL/SharePoint data. */
public final class MainActivity extends Activity {
    private static final String HOST = "appassets.androidplatform.net";
    private static final String HOME = "https://" + HOST + "/index.html";
    private static final int CREATE_EXPORT = 1001, IMPORT_JSON = 1002;
    static final int MAX_BYTES = 15 * 1024 * 1024;
    private WebView web;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private ValueCallback<Uri[]> importCallback;
    private String pendingExport = "";
    private boolean pickerActive, pageReady;
    private final List<String> messages = new ArrayList<>();

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        if (saved != null) {
            pendingExport = saved.getString("pendingExport", "");
            pickerActive = saved.getBoolean("pickerActive", false);
            if (pickerActive && pendingExport.isEmpty()) {
                pickerActive = false;
                messages.add("La preparación de la exportación fue interrumpida. Exporta otra vez; tus tareas siguen en la app.");
            }
            if (saved.getBoolean("importActive", false))
                messages.add("La importación fue interrumpida al recrear la pantalla. Vuelve a elegir el JSON; tus tareas anteriores se conservan.");
            ArrayList<String> old = saved.getStringArrayList("messages");
            if (old != null) messages.addAll(old);
        }
        web = new WebView(this);
        setContentView(web);
        ViewCompat.setOnApplyWindowInsetsListener(web, (view, insets) -> {
            androidx.core.graphics.Insets bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom);
            return insets;
        });
        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(true); // SAF JSON only; network/file URLs remain blocked.
        settings.setAllowFileAccessFromFileURLs(false);
        settings.setAllowUniversalAccessFromFileURLs(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setSupportMultipleWindows(false);
        settings.setMediaPlaybackRequiresUserGesture(true);
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG);
        web.addJavascriptInterface(new PlannerBridge(), "PlannerBridge");
        web.setWebViewClient(new WebViewClient() {
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (!local(uri)) return deny();
                String path = uri.getPath();
                if (path == null || path.equals("/")) path = "/index.html";
                if (path.contains("..") || path.contains("\\") || path.indexOf('\0') >= 0) return deny();
                try {
                    InputStream stream = getAssets().open(path.substring(1));
                    WebResourceResponse response = new WebResourceResponse(mime(path), "UTF-8", stream);
                    java.util.Map<String, String> headers = new java.util.HashMap<>();
                    headers.put("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'");
                    headers.put("X-Content-Type-Options", "nosniff");
                    response.setResponseHeaders(headers);
                    return response;
                } catch (IOException e) { return deny(); }
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return !local(request.getUrl());
            }
            @Override public void onPageFinished(WebView view, String url) {
                if (!HOME.equals(url)) return;
                pageReady = true;
                for (String message : new ArrayList<>(messages)) deliver(message);
                messages.clear();
            }
        });
        web.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (importCallback != null) importCallback.onReceiveValue(null);
                importCallback = callback;
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("*/*");
                intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/json", "text/json", "text/plain", "application/octet-stream"});
                try { startActivityForResult(intent, IMPORT_JSON); }
                catch (ActivityNotFoundException e) {
                    importCallback.onReceiveValue(null); importCallback = null;
                    result("No hay selector de documentos disponible para importar JSON.");
                }
                return true;
            }
        });
        web.setDownloadListener((url, userAgent, disposition, type, size) -> result("Usa Exportar JSON o Compartir para guardar tus archivos."));
        web.loadUrl(HOME);
    }

    private static boolean local(Uri uri) {
        return "https".equals(uri.getScheme()) && HOST.equals(uri.getHost()) && (uri.getPort() == -1 || uri.getPort() == 443) && uri.getUserInfo() == null;
    }
    private static String mime(String path) {
        if (path.endsWith(".js")) return "application/javascript";
        if (path.endsWith(".css")) return "text/css";
        if (path.endsWith(".json")) return "application/json";
        if (path.endsWith(".svg")) return "image/svg+xml";
        if (path.endsWith(".png")) return "image/png";
        return "text/html";
    }
    private static WebResourceResponse deny() {
        return new WebResourceResponse("text/plain", "UTF-8", 403, "Blocked", java.util.Collections.emptyMap(), new ByteArrayInputStream(new byte[0]));
    }
    static String safeName(String name) {
        String clean = name == null ? "SENTINEL-export.json" : name.replaceAll("[^A-Za-z0-9._-]", "_");
        clean = clean.replaceAll("^[.]+", "");
        if (clean.trim().isEmpty()) clean = "SENTINEL-export.json";
        return clean.substring(0, Math.min(clean.length(), 150));
    }
    static String safeMime(String type) {
        return "application/json".equals(type) ? "application/json" : "text/plain";
    }
    File prepareFile(String name, String text) throws IOException {
        if (text == null || text.length() > MAX_BYTES) throw new IOException("El archivo excede 15 MB.");
        byte[] data = text.getBytes(StandardCharsets.UTF_8);
        if (data.length > MAX_BYTES) throw new IOException("El archivo excede 15 MB.");
        File directory = new File(getCacheDir(), "exports/" + UUID.randomUUID());
        if (!directory.mkdirs()) throw new IOException("No se pudo preparar el archivo local.");
        File file = new File(directory, safeName(name));
        try (FileOutputStream out = new FileOutputStream(file)) { out.write(data); }
        return file;
    }
    private void result(String message) {
        main.post(() -> { if (!pageReady || web == null) messages.add(message); else deliver(message); });
    }
    private void deliver(String message) {
        web.evaluateJavascript("if(typeof window.sentinelNativeResult==='function'){window.sentinelNativeResult(" + JSONObject.quote(message) + ");}", null);
    }
    public final class PlannerBridge {
        @JavascriptInterface public void saveFile(String name, String text, String type) {
            main.post(() -> {
                if (pickerActive || !pendingExport.isEmpty()) { result("Ya hay una exportación pendiente. Termina o cancela el selector antes de exportar otra vez."); return; }
                pickerActive = true;
                io.execute(() -> {
                    try {
                        File file = prepareFile(name, text);
                        main.post(() -> {
                            if (isFinishing() || isDestroyed()) {
                                file.delete(); pickerActive = false;
                                return;
                            }
                            pendingExport = file.getAbsolutePath();
                            Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                            intent.addCategory(Intent.CATEGORY_OPENABLE);
                            intent.setType(safeMime(type));
                            intent.putExtra(Intent.EXTRA_TITLE, file.getName());
                            try { startActivityForResult(intent, CREATE_EXPORT); }
                            catch (ActivityNotFoundException e) { finishExport("No hay selector de documentos. El seguimiento sigue guardado en la app."); }
                        });
                    } catch (IOException e) { main.post(() -> { pickerActive = false; result("No se pudo exportar: " + e.getMessage()); }); }
                });
            });
        }
        @JavascriptInterface public void shareFile(String name, String text, String type) {
            io.execute(() -> {
                try {
                    File file = prepareFile(name, text);
                    main.post(() -> {
                        if (isFinishing() || isDestroyed()) return;
                        Uri uri = FileProvider.getUriForFile(MainActivity.this, getPackageName() + ".files", file);
                        Intent intent = new Intent(Intent.ACTION_SEND);
                        intent.setType(safeMime(type));
                        intent.putExtra(Intent.EXTRA_STREAM, uri);
                        intent.setClipData(ClipData.newRawUri("SENTINEL", uri));
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                        try {
                            startActivity(Intent.createChooser(intent, "Compartir seguimiento SENTINEL"));
                            result("Archivo preparado. Elige la aplicación para compartirlo; verifica allí que se haya enviado.");
                        } catch (ActivityNotFoundException e) { result("No hay aplicaciones disponibles para compartir."); }
                    });
                } catch (IOException e) { result("No se pudo compartir: " + e.getMessage()); }
            });
        }
        @JavascriptInterface public void copyText(String text) {
            if (text == null || text.length() > MAX_BYTES) { result("El texto excede el tamaño permitido."); return; }
            main.post(() -> {
                try {
                    ClipboardManager clipboard = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
                    clipboard.setPrimaryClip(ClipData.newPlainText("SENTINEL", text));
                    result("Texto copiado. Pégalo en el chat o documento de destino.");
                } catch (RuntimeException e) { result("No se pudo copiar. Usa Exportar o Compartir."); }
            });
        }
        @JavascriptInterface public void openMasterDocument() {
            main.post(() -> {
                String link = getString(R.string.master_document_url);
                Uri uri = Uri.parse(link);
                if (!"https".equals(uri.getScheme()) || !"docs.google.com".equals(uri.getHost()) || link.contains("REEMPLAZAR")) {
                    result("El documento maestro todavía no está configurado en esta versión."); return;
                }
                try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); }
                catch (ActivityNotFoundException e) { result("No hay aplicación para abrir el documento maestro."); }
            });
        }
    }
    private void finishExport(String message) {
        if (!pendingExport.isEmpty()) new File(pendingExport).delete();
        pendingExport = ""; pickerActive = false; result(message);
    }
    @Override protected void onActivityResult(int request, int code, Intent data) {
        super.onActivityResult(request, code, data);
        if (request == IMPORT_JSON) {
            ValueCallback<Uri[]> callback = importCallback; importCallback = null;
            if (callback == null) { result("El selector fue interrumpido. Vuelve a importar el JSON; no se reemplazaron tus tareas."); return; }
            Uri uri = code == RESULT_OK && data != null ? data.getData() : null;
            if (uri != null && !"content".equals(uri.getScheme())) uri = null;
            callback.onReceiveValue(uri == null ? null : new Uri[]{uri});
            if (uri == null) result("Importación cancelada. Tus tareas no cambiaron.");
        }
        if (request == CREATE_EXPORT) {
            Uri uri = code == RESULT_OK && data != null ? data.getData() : null;
            if (uri == null) { finishExport("Exportación cancelada. Tus tareas siguen en la app; aún no se guardó el archivo externo."); return; }
            if (!"content".equals(uri.getScheme()) || pendingExport.isEmpty()) { finishExport("No se pudo recuperar el archivo pendiente. Exporta de nuevo; tus tareas siguen en la app."); return; }
            // Copy synchronously: a short <=15MB local operation avoids losing ownership
            // between activity recreation and completion; source remains until success/failure.
            try (InputStream in = new FileInputStream(pendingExport); OutputStream out = getContentResolver().openOutputStream(uri, "wt")) {
                if (out == null) throw new IOException("No se pudo abrir el destino.");
                byte[] buffer = new byte[32768]; int count;
                while ((count = in.read(buffer)) != -1) out.write(buffer, 0, count);
                out.flush();
                finishExport("Archivo exportado correctamente.");
            } catch (IOException | SecurityException e) { finishExport("No se pudo guardar el archivo externo. Exporta otra vez; tus tareas siguen en la app."); }
        }
    }
    @Override protected void onSaveInstanceState(Bundle state) {
        state.putString("pendingExport", pendingExport);
        state.putBoolean("pickerActive", pickerActive);
        state.putBoolean("importActive", importCallback != null);
        state.putStringArrayList("messages", new ArrayList<>(messages));
        super.onSaveInstanceState(state);
    }
    @Override public void onBackPressed() {
        web.evaluateJavascript("(function(){var r=document.getElementById('reportDialog');if(r&&r.open){r.close();return true;}var d=document.getElementById('taskDialog');if(d&&d.open){document.getElementById('closeDialog').click();return true;}return false;})()", value -> { if (!"true".equals(value)) MainActivity.super.onBackPressed(); });
    }
    @Override protected void onDestroy() {
        if (importCallback != null) { importCallback.onReceiveValue(null); importCallback = null; }
        if (web != null) { web.removeJavascriptInterface("PlannerBridge"); web.destroy(); web = null; }
        io.shutdown();
        super.onDestroy();
    }
    WebView webForTest() { return web; }
}
