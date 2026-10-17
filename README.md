# Conduce Salida — Android

Aplicación Android para completar el **conduce de salida de herramientas, materiales y otros bienes**.

- Logo SEABOARD y documento original en hoja carta, dos sectores independientes.
- Hasta 21 materiales por sector (matriz invisible 3 × 7).
- PDF con la hoja como imagen, compartible por correo mediante el menú nativo Android.
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
