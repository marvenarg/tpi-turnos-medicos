@echo off
setlocal EnableExtensions

REM ============================================================
REM Backup MongoDB Atlas - Windows
REM Requiere:
REM   - mongodump
REM   - tar
REM   - zstd
REM   - variable de entorno MONGODB_URI
REM ============================================================

REM Obtiene la raiz del proyecto aunque el script se ejecute
REM desde otra carpeta.
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"

REM Carpeta base de respaldos
set "BASE=%PROJECT_ROOT%\resguardos_tpi"

REM Obtiene fecha y hora con formato estable:
REM YYYY-MM-DD_HH-MM-SS
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "FECHA_HORA=%%I"

REM Rutas de trabajo
set "DESTINO=%BASE%\%FECHA_HORA%"
set "TEMP=%DESTINO%\dump"
set "TARFILE=%DESTINO%\backup_%FECHA_HORA%.tar"
set "ARCHIVO=%DESTINO%\backup_%FECHA_HORA%.tar.zst"

echo.
echo ==========================================
echo   Backup de MongoDB Atlas
echo ==========================================
echo.

REM ------------------------------------------------------------
REM Verificar variable de conexion
REM ------------------------------------------------------------

if not defined MONGODB_URI (
    echo ERROR: La variable MONGODB_URI no esta definida.
    echo.
    echo Ejemplo:
    echo set "MONGODB_URI=mongodb+srv://USUARIO:PASSWORD@cluster.mongodb.net/turnos_medicos"
    echo.
    exit /b 1
)

REM ------------------------------------------------------------
REM Verificar herramientas necesarias
REM ------------------------------------------------------------

where mongodump >nul 2>&1
if errorlevel 1 (
    echo ERROR: mongodump no se encuentra disponible en PATH.
    echo Instale MongoDB Command Line Database Tools.
    exit /b 1
)

where tar >nul 2>&1
if errorlevel 1 (
    echo ERROR: tar no se encuentra disponible en PATH.
    exit /b 1
)

where zstd >nul 2>&1
if errorlevel 1 (
    echo ERROR: zstd no se encuentra disponible en PATH.
    exit /b 1
)

REM ------------------------------------------------------------
REM Crear directorios de trabajo
REM ------------------------------------------------------------

if not exist "%BASE%" (
    mkdir "%BASE%"
)

mkdir "%TEMP%"

if errorlevel 1 (
    echo ERROR: No se pudo crear el directorio del backup.
    exit /b 1
)

echo Fecha y hora: %FECHA_HORA%
echo Directorio del respaldo:
echo %DESTINO%
echo.

REM ------------------------------------------------------------
REM Ejecutar mongodump
REM ------------------------------------------------------------

echo Ejecutando mongodump...
echo.

mongodump --uri="%MONGODB_URI%" --out="%TEMP%"

if errorlevel 1 (
    echo.
    echo ERROR: mongodump finalizo con errores.
    goto :ERROR_CLEANUP
)

REM ------------------------------------------------------------
REM Crear archivo TAR
REM ------------------------------------------------------------

echo.
echo Generando archivo TAR...

tar -cf "%TARFILE%" -C "%DESTINO%" "dump"

if errorlevel 1 (
    echo ERROR: No se pudo generar el archivo TAR.
    goto :ERROR_CLEANUP
)

REM ------------------------------------------------------------
REM Comprimir con Zstandard
REM ------------------------------------------------------------

echo.
echo Comprimiendo con Zstandard...

zstd -f "%TARFILE%" -o "%ARCHIVO%"

if errorlevel 1 (
    echo ERROR: No se pudo comprimir el backup.
    goto :ERROR_CLEANUP
)

REM ------------------------------------------------------------
REM Limpiar archivos temporales
REM ------------------------------------------------------------

del /Q "%TARFILE%"
rmdir /S /Q "%TEMP%"

echo.
echo ==========================================
echo   Backup finalizado correctamente
echo ==========================================
echo.
echo Archivo generado:
echo %ARCHIVO%
echo.

exit /b 0


:ERROR_CLEANUP

echo.
echo Limpiando archivos temporales...

if exist "%TARFILE%" (
    del /Q "%TARFILE%"
)

if exist "%TEMP%" (
    rmdir /S /Q "%TEMP%"
)

echo.
echo El backup no pudo completarse.
exit /b 1
