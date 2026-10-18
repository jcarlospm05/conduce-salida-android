package com.bobc.formulariosalida;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.SharedPreferences;
import android.content.ContentValues;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;
import org.json.JSONObject;
import org.json.JSONArray;
import java.util.UUID;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/** Interfaz HTML local: guardar en Descargas o redactar correo con adjunto en Outlook. */
public final class MainActivity extends Activity {
    private static final int REQUEST_CREATE_DOCUMENT = 406;
    private static final String OUTLOOK_PACKAGE = "com.microsoft.office.outlook";
    // Solo dos registros privados: borrador de trabajo y último conduce, 24 horas.
    private static final String TEMP_PREFS = "conduce_temporal_24h";
    private static final long TEMP_TTL_MS = 24L * 60L * 60L * 1000L;
    private static final int TEMP_MAX_LENGTH = 120_000;
    private static final String HISTORY_KEY = "historial_conduces_json";

    // Los conduces realizados se almacenan por 24 horas, de forma independiente.
    private JSONArray activeHistory() {
        JSONArray raw;
        try { raw = new JSONArray(tempPreferences().getString(HISTORY_KEY, "[]")); }
        catch (Exception e) { raw = new JSONArray(); }
        JSONArray valid = new JSONArray();
        final long now = System.currentTimeMillis();
        for (int i = 0; i < raw.length(); i++) {
            JSONObject item = raw.optJSONObject(i);
            if (item == null || item.optJSONObject("data") == null) continue;
            long ts = item.optLong("savedAt", 0L);
            if (ts > 0 && ts <= now + 60_000L && now - ts < TEMP_TTL_MS)
                valid.put(item);
        }
        if (valid.length() != raw.length()) persistHistory(valid);
        return valid;
    }

    private void persistHistory(JSONArray list) {
        tempPreferences().edit().putString(HISTORY_KEY, list.toString()).commit();
    }

    private void migratePreviousConduceOnce() {
        SharedPreferences prefs = tempPreferences();
        if (prefs.getBoolean("historial_legacy_migrado", false)) return;
        // La versión anterior conservaba un único conduce, que no queremos perder.
        String old = prefs.getString("ultimo_json", "");
        long ts = prefs.getLong("ultimo_fecha", 0);
        long now = System.currentTimeMillis();
        if (!old.isEmpty() && ts > 0 && ts <= now + 60_000L && now - ts < TEMP_TTL_MS) {
            try {
                JSONObject entry = new JSONObject();
                entry.put("id", "anterior-" + ts);
                entry.put("savedAt", ts);
                entry.put("data", new JSONObject(old));
                JSONArray history = activeHistory();
                history.put(entry);
                persistHistory(history);
            } catch (Exception ignored) { }
        }
        prefs.edit().putBoolean("historial_legacy_migrado", true).commit();
    }

    private void registerCompletedConduce(JSONObject snapshot) {
        if (snapshot == null) return;
        try {
            migratePreviousConduceOnce();
            JSONArray history = activeHistory();
            JSONObject item = new JSONObject();
            item.put("id", UUID.randomUUID().toString());
            item.put("savedAt", System.currentTimeMillis());
            item.put("data", snapshot);
            history.put(item);
            persistHistory(history);
            String eventJs = "window.conduceHistorialActualizado && window.conduceHistorialActualizado();";
            if (webView != null) webView.evaluateJavascript(eventJs, null);
        } catch (Exception e) { message("El PDF se guardó, pero falló su registro temporal."); }
    }

    private SharedPreferences tempPreferences() {
        return getSharedPreferences(TEMP_PREFS, MODE_PRIVATE);
    }

    private WebView webView;
    private File pendingLegacyFile;
    private JSONObject pendingLegacySnapshot;
    private boolean pendingLegacyOutlook;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(Color.rgb(23, 55, 84));
        getWindow().setNavigationBarColor(Color.rgb(23, 55, 84));
        webView = new WebView(this);
        webView.setBackgroundColor(Color.WHITE);
        webView.setWebViewClient(new WebViewClient());
        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(false);
        s.setAllowFileAccess(true);
        s.setAllowContentAccess(false);
        s.setBuiltInZoomControls(false);
        s.setDisplayZoomControls(false);
        s.setDefaultTextEncodingName("UTF-8");
        webView.addJavascriptInterface(new DocumentBridge(), "ConduceAndroid");
        setContentView(webView);
        webView.loadUrl("file:///android_asset/www/index.html");
    }

    private final class DocumentBridge {
        private static final int MAX_BASE64 = 24_000_000;
        private String action = "download";
        private JSONObject pendingSnapshot = null;
        private String name;
        private String mime;
        private StringBuilder encoded;

        // JS -> Android: almacenamiento privado por aplicación, sin nube ni permisos.
        @JavascriptInterface public synchronized boolean guardarTemporal(String tipo, String json) {
            if (!"borrador".equals(tipo) && !"ultimo".equals(tipo)) return false;
            if (json == null || json.length() > TEMP_MAX_LENGTH) return false;
            try {
                JSONObject checked = new JSONObject(json);
                if (checked.length() == 0) return false;
                tempPreferences().edit()
                    .putString(tipo + "_json", checked.toString())
                    .putLong(tipo + "_fecha", System.currentTimeMillis())
                    .apply();
                return true;
            } catch (Exception e) { return false; }
        }

        @JavascriptInterface public synchronized String leerTemporal(String tipo) {
            if (!"borrador".equals(tipo) && !"ultimo".equals(tipo)) return "";
            SharedPreferences prefs = tempPreferences();
            String json = prefs.getString(tipo + "_json", "");
            long fecha = prefs.getLong(tipo + "_fecha", 0L);
            long now = System.currentTimeMillis();
            if (json == null || json.isEmpty() || fecha <= 0L) return "";
            if (fecha > now + 60_000L || now - fecha >= TEMP_TTL_MS) {
                borrarTemporal(tipo);
                return "";
            }
            try {
                JSONObject wrapper = new JSONObject();
                wrapper.put("savedAt", fecha);
                wrapper.put("data", new JSONObject(json));
                return wrapper.toString();
            } catch (Exception ex) {
                borrarTemporal(tipo);
                return "";
            }
        }

        @JavascriptInterface public synchronized void borrarTemporal(String tipo) {
            if (!"borrador".equals(tipo) && !"ultimo".equals(tipo)) return;
            tempPreferences().edit().remove(tipo + "_json").remove(tipo + "_fecha").apply();
        }


        @JavascriptInterface public synchronized String listarConduces() {
            migratePreviousConduceOnce();
            JSONArray hist = activeHistory();
            JSONArray summaries = new JSONArray();
            for (int i = hist.length() - 1; i >= 0; i--) {
                JSONObject entry = hist.optJSONObject(i);
                if (entry == null) continue;
                JSONObject d = entry.optJSONObject("data");
                if (d == null) continue;
                JSONObject row = new JSONObject();
                try {
                    row.put("id", entry.optString("id"));
                    row.put("savedAt", entry.optLong("savedAt"));
                    row.put("fecha", d.optString("fecha"));
                    row.put("hora", d.optString("hora"));
                    row.put("localidad", d.optString("localidad"));
                    String quien = d.optString("entNombre").trim();
                    if (quien.isEmpty()) quien = "Terceros".equals(d.optString("tipo"))
                        ? d.optString("chofer") : d.optString("nombreInterno");
                    row.put("persona", quien);
                    summaries.put(row);
                } catch (Exception ignored) { }
            }
            return summaries.toString();
        }

        @JavascriptInterface public synchronized String recuperarConduce(String id) {
            if (id == null || id.length() > 90) return "";
            JSONArray hist = activeHistory();
            for (int i = 0; i < hist.length(); i++) {
                JSONObject record = hist.optJSONObject(i);
                if (record != null && id.equals(record.optString("id"))) {
                    JSONObject data = record.optJSONObject("data");
                    if (data != null) return data.toString();
                }
            }
            return "";
        }

        @JavascriptInterface public synchronized boolean setPendingConduce(String json) {
            pendingSnapshot = null;
            if (json == null || json.length() > TEMP_MAX_LENGTH) return false;
            try {
                pendingSnapshot = new JSONObject(json);
                return true;
            } catch (Exception ex) { return false; }
        }

        @JavascriptInterface public synchronized void setAction(String requested) {
            action = "save_outlook".equals(requested) ? "save_outlook"
                : "outlook".equals(requested) ? "outlook" : "download";
        }

        @JavascriptInterface public synchronized void startShare(String filename, String contentType) {
            String safe = filename == null ? "Conduce_Salida.pdf" : filename.replaceAll("[^a-zA-Z0-9_.-]", "_");
            if (!safe.matches("[a-zA-Z0-9_.-]{1,110}\\.(pdf|docx|xlsx)")) {
                name = null; encoded = null;
                message("Nombre de archivo no válido."); return;
            }
            name = safe;
            mime = safe.endsWith(".pdf") ? "application/pdf" : safe.endsWith(".docx")
                ? "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            encoded = new StringBuilder(200_000);
        }

        @JavascriptInterface public synchronized void appendChunk(String chunk) {
            if (encoded == null || chunk == null) return;
            if (encoded.length() + chunk.length() > MAX_BASE64) {
                encoded = null; message("El documento excede el tamaño permitido."); return;
            }
            encoded.append(chunk);
        }

        @JavascriptInterface public synchronized void finishShare() {
            if (encoded == null || name == null) return;
            byte[] data;
            try { data = Base64.decode(encoded.toString(), Base64.DEFAULT); }
            catch (IllegalArgumentException e) {
                encoded = null; message("No se pudo leer el documento generado."); return;
            }
            encoded = null;
            String selectedAction = action;
            String type = mime;
            String filename = withTimestamp(name);
            JSONObject snapshot = pendingSnapshot;
            pendingSnapshot = null;
            action = "download";
            if ("save_outlook".equals(selectedAction)) {
                if (!"application/pdf".equals(type) || snapshot == null) {
                    message("No se pudo preparar el PDF o los datos del conduce."); return;
                }
                runOnUiThread(() -> savePdfAndSendOutlook(data, filename, snapshot));
            } else if ("outlook".equals(selectedAction)) {
                try {
                    File dir = new File(getCacheDir(), "compartidos");
                    if (!dir.exists() && !dir.mkdirs()) throw new IOException("No se pudo preparar el adjunto.");
                    File cached = new File(dir, filename);
                    try (FileOutputStream out = new FileOutputStream(cached)) { out.write(data); }
                    Uri uri = new Uri.Builder().scheme("content")
                        .authority(getPackageName() + ".shared").appendPath(filename).build();
                    runOnUiThread(() -> openOutlook(uri, type));
                } catch (Exception e) { message("Error preparando Outlook: " + e.getMessage()); }
            } else {
                runOnUiThread(() -> saveDocument(data, filename, type));
            }
        }

        private String withTimestamp(String filename) {
            int dot = filename.lastIndexOf('.');
            String suffix = new SimpleDateFormat("_HHmmss_SSS", Locale.US).format(new Date());
            return filename.substring(0, dot) + suffix + filename.substring(dot);
        }
    }

    /** Primero guardar PDF real; solo después registrar y abrir Outlook con el adjunto. */
    private void savePdfAndSendOutlook(byte[] pdf, String filename, JSONObject snapshot) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // Android 8/9: se requiere escoger una carpeta mediante el selector de Android.
            try {
                File dir = new File(getCacheDir(), "pendiente");
                if (!dir.exists() && !dir.mkdirs()) throw new IOException("Carpeta inaccesible.");
                pendingLegacyFile = new File(dir, filename);
                try (FileOutputStream output = new FileOutputStream(pendingLegacyFile)) { output.write(pdf); }
                pendingLegacySnapshot = snapshot;
                pendingLegacyOutlook = true;
                Intent create = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                create.addCategory(Intent.CATEGORY_OPENABLE);
                create.setType("application/pdf");
                create.putExtra(Intent.EXTRA_TITLE, filename);
                startActivityForResult(create, REQUEST_CREATE_DOCUMENT);
            } catch (Exception e) { message("No se pudo guardar el PDF: " + e.getMessage()); }
            return;
        }
        Uri uri = null;
        try {
            ContentValues cv = new ContentValues();
            cv.put(MediaStore.MediaColumns.DISPLAY_NAME, filename);
            cv.put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf");
            cv.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Conduce Salida");
            cv.put(MediaStore.MediaColumns.IS_PENDING, 1);
            uri = getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv);
            if (uri == null) throw new IOException("Android no permitió crear el PDF.");
            try (OutputStream output = getContentResolver().openOutputStream(uri)) {
                if (output == null) throw new IOException("No se pudo abrir el destino.");
                output.write(pdf);
            }
            ContentValues done = new ContentValues();
            done.put(MediaStore.MediaColumns.IS_PENDING, 0);
            getContentResolver().update(uri, done, null, null);
            registerCompletedConduce(snapshot);
            message("PDF guardado en Descargas / Conduce Salida. Abriendo Outlook…");
            openOutlook(uri, "application/pdf");
        } catch (Exception e) {
            if (uri != null) getContentResolver().delete(uri, null, null);
            message("No se pudo guardar el PDF; Outlook no se abrirá: " + e.getMessage());
        }
    }

    private void saveDocument(byte[] data, String filename, String mime) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // Android 8-9: selector SAF, sin permisos invasivos de almacenamiento.
            try {
                File dir = new File(getCacheDir(), "pendiente");
                if (!dir.exists() && !dir.mkdirs()) throw new IOException("Error de carpeta.");
                pendingLegacyFile = new File(dir, filename);
                try (FileOutputStream out = new FileOutputStream(pendingLegacyFile)) { out.write(data); }
                Intent create = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                create.addCategory(Intent.CATEGORY_OPENABLE);
                create.setType(mime);
                create.putExtra(Intent.EXTRA_TITLE, filename);
                startActivityForResult(create, REQUEST_CREATE_DOCUMENT);
            } catch (Exception e) { message("No se pudo abrir Guardar como: " + e.getMessage()); }
            return;
        }
        Uri uri = null;
        try {
            ContentValues cv = new ContentValues();
            cv.put(MediaStore.MediaColumns.DISPLAY_NAME, filename);
            cv.put(MediaStore.MediaColumns.MIME_TYPE, mime);
            cv.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Conduce Salida");
            cv.put(MediaStore.MediaColumns.IS_PENDING, 1);
            uri = getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv);
            if (uri == null) throw new IOException("Android no autorizó la descarga.");
            try (OutputStream out = getContentResolver().openOutputStream(uri)) {
                if (out == null) throw new IOException("No se pudo abrir el archivo.");
                out.write(data);
            }
            ContentValues done = new ContentValues();
            done.put(MediaStore.MediaColumns.IS_PENDING, 0);
            getContentResolver().update(uri, done, null, null);
            message("Guardado en Descargas / Conduce Salida / " + filename);
        } catch (Exception e) {
            if (uri != null) getContentResolver().delete(uri, null, null);
            message("No se pudo guardar en Descargas: " + e.getMessage());
        }
    }

    @Override protected void onActivityResult(int request, int result, Intent intent) {
        super.onActivityResult(request, result, intent);
        if (request != REQUEST_CREATE_DOCUMENT) return;
        File cached = pendingLegacyFile;
        pendingLegacyFile = null;
        if (result != RESULT_OK || intent == null || intent.getData() == null || cached == null) {
            pendingLegacyOutlook = false;
            pendingLegacySnapshot = null;
            message("No se guardó el documento."); return;
        }
        try (java.io.FileInputStream in = new java.io.FileInputStream(cached);
             OutputStream out = getContentResolver().openOutputStream(intent.getData())) {
            if (out == null) throw new IOException("El destino no está disponible.");
            byte[] buf = new byte[16384]; int n;
            while ((n = in.read(buf)) >= 0) out.write(buf, 0, n);
            if (pendingLegacyOutlook) {
                registerCompletedConduce(pendingLegacySnapshot);
                message("PDF guardado. Abriendo Outlook…");
                openOutlook(intent.getData(), "application/pdf");
            } else message("Documento guardado en la carpeta que elegiste.");
        } catch (Exception e) { message("No se pudo guardar: " + e.getMessage()); }
        finally {
            cached.delete();
            pendingLegacyOutlook = false;
            pendingLegacySnapshot = null;
        }
    }

    private void openOutlook(Uri uri, String mime) {
        Intent email = new Intent(Intent.ACTION_SEND);
        email.setPackage(OUTLOOK_PACKAGE); // No abre Gmail ni un selector genérico.
        email.setType(mime);
        email.putExtra(Intent.EXTRA_STREAM, uri);
        email.putExtra(Intent.EXTRA_SUBJECT, "Conduce de salida");
        email.putExtra(Intent.EXTRA_TEXT, "Adjunto el conduce de salida para imprimir en hoja carta.");
        email.setClipData(ClipData.newRawUri("Conduce de salida", uri));
        email.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        try {
            grantUriPermission(OUTLOOK_PACKAGE, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivity(email);
        } catch (ActivityNotFoundException ex) {
            new AlertDialog.Builder(this)
                .setTitle("Outlook no está disponible")
                .setMessage("Instala Microsoft Outlook o inicia sesión en la aplicación para enviar el PDF.")
                .setNegativeButton("Cancelar", null)
                .setPositiveButton("Abrir Google Play", (dialog, which) -> {
                    Intent link = new Intent(Intent.ACTION_VIEW,
                        Uri.parse("https://play.google.com/store/apps/details?id=" + OUTLOOK_PACKAGE));
                    try { startActivity(link); } catch (Exception ignored) {
                        message("No se pudo abrir Google Play.");
                    }
                }).show();
        } catch (Exception ex) { message("No se pudo abrir Outlook: " + ex.getMessage()); }
    }

    private void message(String text) {
        runOnUiThread(() -> {
            Toast.makeText(this, text, Toast.LENGTH_LONG).show();
            if (webView != null) {
                String js = "window.conduceAvisoAndroid && window.conduceAvisoAndroid(" +
                    org.json.JSONObject.quote(text) + ");";
                webView.evaluateJavascript(js, null);
            }
        });
    }

    @Override public void onBackPressed() {
        if (webView == null) { super.onBackPressed(); return; }
        webView.evaluateJavascript("(function(){try{window.conduceGuardarTemporalAhora&&window.conduceGuardarTemporalAhora()}catch(e){}return Boolean(window.conduceVolverAndroid&&window.conduceVolverAndroid())})()", result -> {
            if (!"true".equals(result)) {
                new AlertDialog.Builder(this).setTitle("Cerrar formulario")
                    .setMessage("Podrás recuperar el borrador durante 24 horas. ¿Salir?")
                    .setNegativeButton("Cancelar", null)
                    .setPositiveButton("Salir", (dialog, which) -> finish()).show();
            }
        });
    }

    @Override protected void onDestroy() {
        if (webView != null) {
            webView.removeJavascriptInterface("ConduceAndroid");
            webView.destroy(); webView = null;
        }
        super.onDestroy();
    }
}