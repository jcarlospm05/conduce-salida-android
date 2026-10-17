# Formulario de salida — Android v3.0

La aplicación reproduce el formulario HTML v2.3, su logo SEABOARD y el documento carta con dos sectores y matrices de 3 × 7 (21 artículos por sector). La interfaz se adapta al celular con pestañas **Capturar datos** y **Vista previa**, sin modificar la hoja carta original.

## Función de compartir

Selecciona **Guardar y compartir**, elige PDF (imagen), Word (editable) o Excel (editable) y confirma. La APK genera el archivo localmente y abre el menú Compartir de Android. Selecciona **Gmail** u **Outlook**, escribe la dirección y envíalo como adjunto. En la computadora se abre el PDF y se imprime en papel carta. También podrás compartir los archivos a WhatsApp si esa app acepta el tipo de archivo.

El PDF se crea a partir de la hoja HTML original mediante un lienzo y se inserta en una hoja PDF de **612 × 792 pt**. No se necesita internet para llenar el formulario o generar archivos; enviar el correo sí necesita una aplicación de correo configurada y conexión.

Los archivos se guardan temporalmente en el caché privado de Android para compartirlos; la aplicación **no mantiene una base de datos de conduce** ni sube datos a ningún servidor.

## Compilar mediante GitHub (sin instalar Android Studio)

1. Crea un **repositorio privado nuevo** en GitHub; sube **el contenido interno** de esta carpeta, incluidas `.github/workflows/construir-apk.yml` y `app/`.
2. En el repositorio ve a **Actions → Compilar APK de Formulario de salida → Run workflow** (o espera a que finalice la ejecución automática después del push a `main`).
3. Al completarse, abre la ejecución y descarga el artefacto **Formulario-de-salida-APK**. Dentro estará **app-debug.apk**.
4. Transfiere el APK al celular e instálalo. Android puede solicitar autorización para instalar desde ese origen. Mantén esa autorización restringida a fuentes de confianza.

El `app-debug.apk` es para prueba personal y **todavía no está compilado en este ZIP**. Para distribuir comercialmente la aplicación, compila una versión de lanzamiento **firmada con una clave propia**, aumenta `versionCode` y configura una política de actualizaciones.

## Compilar en Android Studio

1. Abre Android Studio (con Android SDK 35 y JDK 17) y selecciona **Open** en esta carpeta.
2. Si Android Studio solicita una distribución de Gradle, utiliza Gradle 8.9. Puedes generar el wrapper con `gradle wrapper --gradle-version 8.9` en una máquina con Gradle instalado. **No se incluye `gradle-wrapper.jar`**.
3. Sincroniza el proyecto y usa **Build → Build Bundle(s) / APK(s) → Build APK(s)**.
4. APK resultante: `app/build/outputs/apk/debug/app-debug.apk`.

## Archivo principal y tecnología

- `app/src/main/assets/www/index.html`: copia adaptada del formulario original.
- `app/src/main/assets/www/Recursos/`: CSS, JS, Bootstrap, logo y exportadores locales.
- `app/src/main/java/com/bobc/formulariosalida/MainActivity.java`: WebView offline y puente de archivos al menú Compartir.
- `SharedFileProvider.java`: proveedor `content://` seguro para adjuntar los archivos a Gmail/Outlook.
- `.github/workflows/construir-apk.yml`: crea un APK de prueba automáticamente en un runner Android de GitHub.

**Estado de verificación:** el código web y la descarga a través del puente JS pueden comprobarse aquí, pero la APK debe **compilarse y probarse en un entorno con Android SDK y dispositivo/emulador**; este paquete es el **proyecto fuente**, no una APK compilada.
