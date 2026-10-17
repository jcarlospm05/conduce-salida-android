package com.bobc.formulariosalida;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ClipData;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import java.io.File;
import java.io.FileOutputStream;

/** Aplicación local: interfaz HTML v2.3 intacta y compartir Android nativo. */
public final class MainActivity extends Activity {
    private WebView webView;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(Color.rgb(23, 55, 84));
        getWindow().setNavigationBarColor(Color.rgb(23, 55, 84));
        webView = new WebView(this);
        webView.setBackgroundColor(Color.WHITE);
        webView.setWebViewClient(new WebViewClient());
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(false); // Datos de captura solo en memoria.
        settings.setAllowFileAccess(true);  // Recursos locales /android_asset/.
        settings.setAllowContentAccess(false);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setDefaultTextEncodingName("UTF-8");
        webView.addJavascriptInterface(new ShareBridge(), "ConduceAndroid");
        setContentView(webView);
        webView.loadUrl("file:///android_asset/www/index.html");
    }

    private final class ShareBridge {
        private String name;
        private String mime;
        private StringBuilder encoded;
        private static final int MAX_BASE64 = 24_000_000;

        @JavascriptInterface public synchronized void startShare(String filename, String contentType) {
            String safe = filename == null ? "Conduce_Salida.pdf" : filename.replaceAll("[^a-zA-Z0-9_.-]", "_");
            if (!safe.matches("[a-zA-Z0-9_.-]{1,110}\\.(pdf|docx|xlsx)")) {
                name = null; encoded = null;
                showError("Nombre de archivo no válido."); return;
            }
            name = safe;
            if (safe.endsWith(".pdf")) mime = "application/pdf";
            else if (safe.endsWith(".docx")) mime = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
            else mime = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            encoded = new StringBuilder(200_000);
        }

        @JavascriptInterface public synchronized void appendChunk(String text) {
            if (encoded == null || text == null) return;
            if (encoded.length() + text.length() > MAX_BASE64) {
                encoded = null; showError("Archivo demasiado grande para compartir."); return;
            }
            encoded.append(text);
        }

        @JavascriptInterface public synchronized void finishShare() {
            if (encoded == null || name == null) return;
            final String filename = name;
            final String type = mime;
            byte[] data;
            try { data = Base64.decode(encoded.toString(), Base64.DEFAULT); }
            catch (IllegalArgumentException ex) { encoded = null; showError("El archivo generado no es válido."); return; }
            encoded = null;
            try {
                File dir = new File(getCacheDir(), "compartidos");
                if (!dir.exists() && !dir.mkdirs()) throw new Exception("No se pudo crear la carpeta temporal.");
                File dest = new File(dir, filename);
                try (FileOutputStream out = new FileOutputStream(dest)) { out.write(data); }
                final Uri uri = new Uri.Builder().scheme("content")
                    .authority(getPackageName() + ".shared").appendPath(filename).build();
                runOnUiThread(() -> share(uri, type));
            } catch (Exception ex) { showError("No se pudo compartir el documento: " + ex.getMessage()); }
        }

        private void showError(String text) {
            runOnUiThread(() -> Toast.makeText(MainActivity.this, text, Toast.LENGTH_LONG).show());
        }
    }

    private void share(Uri uri, String mime) {
        Intent send = new Intent(Intent.ACTION_SEND);
        send.setType(mime);
        send.putExtra(Intent.EXTRA_STREAM, uri);
        send.putExtra(Intent.EXTRA_SUBJECT, "Conduce de salida");
        send.putExtra(Intent.EXTRA_TEXT, "Adjunto el conduce de salida en formato " + (mime.equals("application/pdf") ? "PDF (hoja carta)." : "editable."));
        send.setClipData(ClipData.newRawUri("Conduce de salida", uri));
        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        try { startActivity(Intent.createChooser(send, "Enviar conduce por correo u otra aplicación")); }
        catch (Exception e) { Toast.makeText(this, "No hay una aplicación para compartir este archivo.", Toast.LENGTH_LONG).show(); }
    }

    @Override public void onBackPressed() {
        if (webView == null) { super.onBackPressed(); return; }
        webView.evaluateJavascript("Boolean(window.conduceVolverAndroid&&window.conduceVolverAndroid())", result -> {
            if (!"true".equals(result)) {
                new AlertDialog.Builder(this).setTitle("Cerrar formulario")
                    .setMessage("Los datos sin compartir se perderán. ¿Salir?")
                    .setNegativeButton("Cancelar", null)
                    .setPositiveButton("Salir", (dialog, which) -> finish()).show();
            }
        });
    }

    @Override protected void onDestroy() {
        if (webView != null) {
            webView.removeJavascriptInterface("ConduceAndroid");
            webView.destroy();webView = null;
        }
        super.onDestroy();
    }
}
