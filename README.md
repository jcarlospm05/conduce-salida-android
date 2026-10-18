# Conduce de Salida — Flutter (fiel al original)

Esta rama contiene la conversión a contenedor Flutter del proyecto Android v3.6.
**Sin rediseños.** Conserva intactos el HTML/CSS/JS, reporte carta, logo e icono y los controles de captura/vista previa, guardado PDF y apertura de Outlook. El WebView original se integra en Flutter mediante AndroidView y la capa nativa Java conserva el puente; no es una reescritura total a Dart.

[Descargar código fuente Flutter (ZIP)](./CONDUCE_DE_SALIDA_Flutter_fiel_v1.zip)

## Compilación
GitHub Actions → **Flutter Conduce de Salida - APK** → artefacto **Conduce-de-Salida-Flutter-APK**.

La fuente de referencia es Conduce de Salida Android v3.6, incluido el historial de 24 horas, exactamente como estaba. La versión Flutter se instala separadamente y NO importa datos de la APK anterior automáticamente. Esta versión necesita prueba en un Android real.

[Carpeta del proyecto en Drive](https://drive.google.com/drive/folders/14qh7wBVkcqQM2wawgtyrAupHlx2NXFBM)
