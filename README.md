# Conduce Salida — Android

Aplicación Android para completar el **conduce de salida de herramientas, materiales y otros bienes**.

- Logo SEABOARD y documento original en hoja carta, dos sectores independientes.
- Artículos en texto continuo por sector: cada artículo se agrega separado por guiones; ajuste automático de líneas hasta ocho renglones por sector.
- PDF con la hoja como imagen. Botones independientes para guardar en Descargas y enviar el archivo directamente por Outlook.
- Word y Excel editables; sin base de datos ni servicios externos.
- Interfaz offline mediante WebView con archivos HTML/CSS/JS locales.

## 📱 Descargar e instalar

1. Abre [Actions](../../actions/workflows/construir-apk.yml).
2. Abre la ejecución **más reciente con marca verde** de «Compilar APK - Conduce Salida».
3. En la sección **Artifacts** descarga **Conduce-Salida-Android-APK**.
4. Extrae el ZIP y copia `app-debug.apk` a tu teléfono Android.
5. Ábrelo en el teléfono y permite la instalación desde ese origen si Android lo solicita.

La APK está firmada automáticamente por Android con la **clave de depuración** y es para pruebas. Para distribución permanente se requiere firma de producción y gestión de versiones.

## Construir en GitHub

La compilación automática se ejecuta con cada push a `main`, sin que necesites instalar Android Studio ni tener un PC de desarrollo. También se puede ejecutar manualmente desde Actions.

## Estructura de código

- `app/src/main/assets/www`: formulario HTML, CSS, JavaScript y exportadores.
- `app/src/main/java`: Android WebView y proveedor `content://` de archivos compartidos.
- `app/src/main/res`: nombre e ícono de la app.
- `.github/workflows/construir-apk.yml`: compilación y artefacto APK.

No almacena formularios en una base de datos; los documentos compartidos se conservan temporalmente en la caché de Android.

## Guardar / Outlook — versión 3.2

- **Guardar en Descargas:** Android 10+ deposita PDF, Word o Excel en `Descargas/Conduce Salida` (archivos visibles desde Archivos). En Android 8 y 9 se abre el selector del sistema para escoger una carpeta, como Descargas.
- **Enviar por Outlook:** abre exclusivamente Microsoft Outlook con el archivo adjunto preparado. Necesitas Outlook instalado y una cuenta configurada; revisas y envías manualmente el correo. No abre Gmail.
- Las exportaciones siguen siendo locales; no se solicita acceso a la cuenta de correo.

## v3.3 — campo dinámico de materiales

En cada sector se agrega texto continuo sin columnas internas ni límite fijo de cantidad de artículos. El documento reserva 8 renglones visibles por sector y avisa cuando un artículo no cabe. El resto del conduce, la exportación Word/Excel editable y el PDF como imagen mantienen su estructura.


## Respaldo temporal v3.4 (Android)

- Conserva únicamente dos registros locales: el **borrador actual** y el **último conduce**, usando `SharedPreferences` con acceso privado a la app.
- El borrador se actualiza mientras se captura información; el último se guarda al exportar o al pulsar «Limpiar formulario».
- Los botones «Recuperar último conduce» y «Continuar borrador» permiten cargar la información y seguir editándola.
- Cada registro expira a las **24 horas desde su última actualización**. La app lo elimina cuando se vuelve a leer o al abrirla después de expirar. No almacena PDFs ni historial permanente.
- Los documentos guardados en Descargas no se borran al vencer el respaldo temporal.
- Mantiene la exportación a PDF, Word y Excel y el envío por Outlook.


## v3.5 — Bloqueo por tipo de salida

- Al seleccionar **Terceros**, solo el panel izquierdo de terceros permite captura.
- Al seleccionar **Interno**, solo el panel derecho de personal interno permite captura.
- Si no se ha seleccionado el tipo, ambos paneles permanecen desactivados y la exportación solicita elegir uno.
- Los datos del sector inactivo no se incluyen en la vista previa ni en Word, Excel, PDF o respaldo temporal.
- Cambiar accidentalmente de tipo conserva los valores de la sesión hasta volver a seleccionarlo, pero estos no se exportan.
- La estructura del documento físico se mantiene con ambos lados, uno de ellos vacío.


## v3.6 — PDF único y historial de 24 horas

**Exclusivamente dos cambios funcionales:**

- Un solo botón **Guardar y enviar**: prepara el PDF como imagen, lo guarda en Descargas/Conduce Salida (Android 10+) y, una vez guardado, abre Microsoft Outlook con el PDF adjunto. El usuario confirma el envío en Outlook; no hay Word/Excel ni botones adicionales. Android 8/9 necesita elegir carpeta en el selector del sistema para guardar antes de abrir Outlook.
- **Historial 24 horas**: conserva cada conduce generado como registro independiente en almacenamiento privado Android. Se listan fecha, hora, localidad y persona que retira. Al tocar una fila se recupera toda la información editable. Los registros caducan 24 horas después de su creación, sin borrar los PDF descargados. El último respaldo de versiones anteriores se importa una única vez si aún está vigente.