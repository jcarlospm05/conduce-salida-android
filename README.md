# PORTA — Control de Salidas · Flutter 1.0

**Proyecto independiente de la app histórica.** Esta rama no modifica `main`.

## Código fuente
Descarga `PORTA_Control_Salidas_Flutter_v1.0_fuentes.zip` y descomprímelo. Dentro están los módulos Flutter de formularios, PDF carta, SQLite, auditoría, historial, exportación, Android y la compilación de web.

## Compilar
```bash
cd porta_control_salidas
flutter create . --platforms android,web --org com.bobc --project-name porta_control_salidas
mkdir -p android/app/src/main/kotlin/com/bobc/porta_control_salidas
cp android_native/MainActivity.kt android/app/src/main/kotlin/com/bobc/porta_control_salidas/MainActivity.kt
flutter pub get
flutter test
flutter build apk --debug
flutter build web
```

No se ha compilado ni probado aún en dispositivo físico. El logo del reporte es una recreación temporal (ver fuente original) y la fidelidad PDF requiere comparación visual con el formato autorizado. Para un APK de distribución comercial se necesita firma estable.

Fuente adicional y copia en Drive: https://drive.google.com/drive/folders/14qh7wBVkcqQM2wawgtyrAupHlx2NXFBM
