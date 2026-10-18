# Conduce de Salida — Flutter 3.6.2

ÚNICOS CAMBIOS respecto a la versión Flutter fiel al original:

1. **Historial permanente en SQLite**: cada salida cuyo PDF se guarda se registra sin caducidad. Búsqueda desde el mismo formulario por fecha, responsable, localidad y materiales; se puede recuperar un registro para reutilizarlo. Los registros previamente existentes se importan si siguen disponibles.
2. **Paleta de interfaz verde, azul y gris claro**, sin alterar las dimensiones, estructura ni los colores del reporte PDF original.

Se conservan captura, vista previa, logo original, documento carta de dos sectores, botón único Guardar y enviar y Outlook. También se conserva la corrección SafeArea de las barras Android.

El historial se almacena localmente en el dispositivo. **Desinstalar la aplicación o borrar sus datos elimina la base**; no desinstales la versión anterior sin salvar sus registros. Una actualización exige que el APK tenga la misma firma Android que la versión instalada (la compilación CI actual usa firma de pruebas, no un certificado comercial persistente).

Fuentes: `Conduce_de_Salida_Flutter_v3.6.2_fuentes.zip`.

[Carpeta en Drive](https://drive.google.com/drive/folders/14qh7wBVkcqQM2wawgtyrAupHlx2NXFBM).
