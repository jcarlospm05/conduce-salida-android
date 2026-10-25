@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo No se encontro Flutter en este equipo.
  echo Este archivo necesita Flutter y el SDK Android ya configurados.
  echo No se ha creado ningun APK. Consulta LEER_PRIMERO.txt.
  pause
  exit /b 1
)
echo Preparando PM Buques Supervisor para Android...
call flutter create --no-pub --platforms=android --org local.pmbuques --project-name pm_buques_supervisor .
if errorlevel 1 goto error
call flutter pub get
if errorlevel 1 goto error
call flutter analyze
if errorlevel 1 goto error
call flutter test
if errorlevel 1 goto error
call flutter build apk --release
if errorlevel 1 goto error
echo.
echo APK creado en build\app\outputs\flutter-apk\app-release.apk
explorer "build\app\outputs\flutter-apk"
pause
exit /b 0
:error
echo.
echo La preparacion o las pruebas no terminaron. No se confirma un APK nuevo.
pause
exit /b 1
