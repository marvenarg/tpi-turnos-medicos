# TPI - Sistema de Turnos Médicos

Trabajo Práctico Integrador de la materia **Base de Datos II** de la Tecnicatura Universitaria en Programación a Distancia - UTN.

El proyecto consiste en una API backend para la gestión de turnos médicos utilizando **TypeScript**, **Express**, **Mongoose** y **MongoDB Atlas**.

## Objetivo

Desarrollar un sistema que permita administrar:

- Pacientes.
- Médicos.
- Turnos médicos.
- Relaciones entre pacientes, médicos y turnos.
- Bajas lógicas sin eliminar físicamente los documentos.
- Persistencia de datos en MongoDB Atlas.
- Respaldo de la base de datos mediante `mongodump`.
- Compresión de los respaldos mediante Zstandard.
- Ejecución de backups tanto en Linux/macOS como en Windows.

## Tecnologías utilizadas

- Node.js
- TypeScript
- Express
- Mongoose
- MongoDB Atlas
- dotenv
- tsx
- Inquirer
- Bash
- Windows Batch
- PowerShell
- curl
- jq
- MongoDB Command Line Database Tools
- `mongodump`
- `mongorestore`
- `tar`
- Zstandard (`zstd`)

---

# Modelo de datos

El sistema utiliza tres colecciones principales:

- `pacientes`
- `medicos`
- `turnos`

## Pacientes

Contiene información personal y administrativa del paciente.

Campos principales:

- `dni`
- `nombre`
- `apellido`
- `fechaNacimiento`
- `contacto`
  - `telefono`
  - `email`
- `obraSocial`
  - `nombre`
  - `numeroAfiliado`
- `activo`
- `fechaBaja`
- `createdAt`
- `updatedAt`

Los datos de contacto y obra social se encuentran embebidos dentro del documento del paciente.

Ejemplo:

```json
{
  "dni": "30123456",
  "nombre": "Juan",
  "apellido": "Perez",
  "contacto": {
    "telefono": "2235551234",
    "email": "juan@email.com"
  },
  "obraSocial": {
    "nombre": "OSDE",
    "numeroAfiliado": "123456"
  },
  "activo": true,
  "fechaBaja": null
}
```

## Médicos

Contiene la información correspondiente a los profesionales médicos.

Campos principales:

- `nombre`
- `apellido`
- `matricula`
  - `numero`
  - `tipo`
  - `jurisdiccion`
- `especialidad`
- `disponibilidad`
- `obrasSocialesAceptadas`
- `contacto`
- `activo`
- `fechaBaja`
- `createdAt`
- `updatedAt`

La matrícula, disponibilidad, información de contacto y obras sociales aceptadas se almacenan mediante **Embedding**.

La disponibilidad se registra mediante fechas concretas en formato `AAAA-MM-DD` y rangos horarios `HH:mm`. El esquema de Mongoose valida que `dia` respete el formato de fecha y que `horaDesde` y `horaHasta` respeten el formato `HH:mm`, evitando valores de texto como `"Lunes"` o `"Martes"`. Al reservar un turno, el horario seleccionado se elimina de la disponibilidad del médico dentro de la misma transacción utilizada para crear el turno.

Ejemplo:

```json
{
  "nombre": "Ana",
  "apellido": "Gomez",
  "matricula": {
    "numero": "12345",
    "tipo": "provincial",
    "jurisdiccion": "Buenos Aires"
  },
  "especialidad": "Cardiologia",
  "disponibilidad": [
    {
      "dia": "2026-11-10",
      "horaDesde": "10:30",
      "horaHasta": "11:00"
    }
  ],
  "obrasSocialesAceptadas": [
    "OSDE",
    "IOMA"
  ],
  "contacto": {
    "telefono": "2235559999",
    "email": "ana.gomez@clinica.com"
  },
  "activo": true,
  "fechaBaja": null
}
```

## Turnos

Representa la relación entre pacientes y médicos.

Campos principales:

- `pacienteId`
- `medicoId`
- `fechaHora`
- `motivo`
- `estado`
- `observaciones`
- `activo`
- `fechaBaja`
- `createdAt`
- `updatedAt`

Los campos `pacienteId` y `medicoId` almacenan referencias a documentos pertenecientes a las colecciones `pacientes` y `medicos`.

El campo `fechaHora` se almacena como texto en formato:

```text
AAAA-MM-DDTHH:mm:00
```

Este formato coincide con los horarios disponibles registrados en la agenda del médico y es validado por el esquema de Mongoose.

De esta forma se implementa **Linking** entre las colecciones.

Ejemplo:

```json
{
  "pacienteId": "ObjectId",
  "medicoId": "ObjectId",
  "fechaHora": "2026-11-10T10:30:00",
  "motivo": "Control cardiologico",
  "estado": "pendiente",
  "activo": true,
  "fechaBaja": null
}
```

---

# Embedding y Linking

## Embedding

Se utiliza Embedding para almacenar información que pertenece directamente a una entidad y que normalmente se consulta junto con ella.

Ejemplos:

- Datos de contacto de un paciente.
- Obra social de un paciente.
- Matrícula de un médico.
- Disponibilidad de un médico.
- Obras sociales aceptadas por un médico.

## Linking

Se utiliza Linking para relacionar entidades independientes.

La colección `turnos` contiene referencias a:

- `pacienteId` → colección `pacientes`.
- `medicoId` → colección `medicos`.

Esto permite evitar duplicación de información y mantener separados los datos de cada entidad.

Mongoose permite recuperar la información relacionada mediante `populate()`.

---

# Transacciones y reserva de turnos

La creación de un turno se realiza mediante una **transacción de MongoDB** utilizando sesiones de Mongoose.

Dentro de la misma operación:

1. se verifica que el paciente exista y se encuentre activo;
2. se verifica que el médico exista, esté activo y tenga disponible el horario solicitado;
3. el horario seleccionado se elimina de la disponibilidad del médico mediante `$pull`;
4. se crea el nuevo turno.

Si cualquiera de estas operaciones falla, la transacción se revierte mediante `abortTransaction()`.

De esta forma, la reserva del turno y la actualización de la disponibilidad del médico se realizan de manera atómica, evitando estados inconsistentes o reservas simultáneas sobre el mismo horario.

---

# Baja lógica

El sistema no elimina físicamente los documentos.

Todos los registros principales poseen inicialmente:

```json
{
  "activo": true,
  "fechaBaja": null
}
```

Cuando se realiza una baja lógica:

```json
{
  "activo": false,
  "fechaBaja": "fecha de la baja"
}
```

Las operaciones de lectura muestran únicamente documentos que posean:

```json
{
  "activo": true
}
```

En el caso de un turno dado de baja, también se modifica su estado a:

```text
cancelado
```

De esta forma el documento continúa almacenado en MongoDB, pero deja de aparecer en las consultas normales de la aplicación.

---

# Estados de los turnos

Los estados posibles son:

- `pendiente`
- `confirmado`
- `atendido`
- `cancelado`

---

# API REST

La aplicación se ejecuta por defecto en:

```text
http://localhost:3002
```

## Pacientes

```text
POST   /api/pacientes
GET    /api/pacientes
GET    /api/pacientes/:id
PATCH  /api/pacientes/:id
DELETE /api/pacientes/:id
```

## Médicos

```text
POST   /api/medicos
GET    /api/medicos
GET    /api/medicos/:id
PATCH  /api/medicos/:id
DELETE /api/medicos/:id
```

## Turnos

```text
POST   /api/turnos
GET    /api/turnos
GET    /api/turnos/:id
PATCH  /api/turnos/:id
DELETE /api/turnos/:id
```

Las operaciones `PATCH` permiten realizar actualizaciones parciales. En campos embebidos puede utilizarse notación de punto, por ejemplo:

```json
{
  "contacto.telefono": "2235557777"
}
```

De esta manera se modifica únicamente el teléfono sin reemplazar el resto del subdocumento `contacto`.

Las rutas de actualización ejecutan las validaciones del esquema de Mongoose, de modo que los datos modificados deben respetar las mismas restricciones definidas en los modelos.

---

# Cliente de consola

El proyecto incluye un cliente interactivo de consola implementado con **Inquirer**:

```text
src/cli_crud.ts
```

El CLI permite operar sobre la API sin utilizar herramientas externas como Postman.

Desde el menú pueden realizarse operaciones CRUD sobre:

- pacientes;
- médicos;
- turnos.

También permite:

- cargar disponibilidad horaria de los médicos;
- seleccionar un horario disponible al crear un turno;
- modificar parcialmente determinados campos mediante `PATCH`;
- realizar bajas lógicas;
- consultar registros por ID;
- listar registros activos.

Para utilizarlo, la API debe estar ejecutándose en:

```text
http://localhost:3002
```

---

# Ejemplo de creación de un paciente

```bash
curl -X POST http://localhost:3002/api/pacientes \
-H "Content-Type: application/json" \
-d '{
  "dni":"30123456",
  "nombre":"Juan",
  "apellido":"Perez",
  "contacto":{
    "telefono":"2235551234",
    "email":"juan@email.com"
  },
  "obraSocial":{
    "nombre":"OSDE",
    "numeroAfiliado":"123456"
  }
}'
```

# Ejemplo de creación de un médico

```bash
curl -X POST http://localhost:3002/api/medicos \
-H "Content-Type: application/json" \
-d '{
  "nombre":"Ana",
  "apellido":"Gomez",
  "matricula":{
    "numero":"12345",
    "tipo":"provincial",
    "jurisdiccion":"Buenos Aires"
  },
  "especialidad":"Cardiologia",
  "disponibilidad":[
    {
      "dia":"2026-11-10",
      "horaDesde":"08:00",
      "horaHasta":"08:30"
    }
  ],
  "obrasSocialesAceptadas":[
    "OSDE",
    "IOMA"
  ],
  "contacto":{
    "telefono":"2235559999",
    "email":"ana.gomez@clinica.com"
  }
}'
```

# Ejemplo de creación de un turno

```bash
curl -X POST http://localhost:3002/api/turnos \
-H "Content-Type: application/json" \
-d '{
  "pacienteId":"ID_PACIENTE",
  "medicoId":"ID_MEDICO",
  "fechaHora":"2026-11-10T10:30:00",
  "motivo":"Control cardiologico"
}'
```

# Consulta de turnos

```bash
curl http://localhost:3002/api/turnos
```

La consulta utiliza `populate()` para mostrar los datos relacionados del paciente y del médico.

# Actualización de un turno

```bash
curl -X PATCH http://localhost:3002/api/turnos/ID_TURNO \
-H "Content-Type: application/json" \
-d '{
  "estado":"confirmado"
}'
```

# Baja lógica de un turno

```bash
curl -X DELETE http://localhost:3002/api/turnos/ID_TURNO
```

La operación no elimina físicamente el documento.

El turno queda almacenado con:

```json
{
  "estado": "cancelado",
  "activo": false,
  "fechaBaja": "fecha de la baja"
}
```

---

# Instalación

Clonar el repositorio:

```bash
git clone URL_DEL_REPOSITORIO
```

Ingresar al proyecto:

```bash
cd tpi-turnos-medicos
```

Instalar las dependencias:

```bash
npm install
```

Este comando instala todas las dependencias declaradas en `package.json`, incluyendo **Inquirer**, utilizado por el cliente interactivo de consola.

No es necesario instalar Inquirer por separado si el proyecto fue clonado con el `package.json` actualizado. En caso de incorporarlo manualmente a un proyecto que todavía no lo tenga declarado, puede instalarse con:

```bash
npm install inquirer
```

---

# Dependencias externas para los backups

Además de las dependencias instaladas mediante `npm`, los scripts de respaldo requieren herramientas de línea de comandos instaladas en el sistema operativo.

## MongoDB Command Line Database Tools

Los scripts utilizan principalmente:

```text
mongodump
mongorestore
```

Estas utilidades forman parte de **MongoDB Command Line Database Tools**.

No es necesario instalar MongoDB Server localmente para disponer de estas herramientas.

Si la base de datos se encuentra alojada en MongoDB Atlas y solamente se requieren las utilidades de backup y restauración, puede instalarse únicamente la suite MongoDB Database Tools.

Descarga oficial:

https://www.mongodb.com/try/download/database-tools

Desde el sitio oficial puede seleccionarse:

- versión;
- sistema operativo o distribución;
- arquitectura;
- formato del paquete.

Después de la instalación puede comprobarse:

```bash
mongodump --version
mongorestore --version
```

En Windows:

```bat
mongodump --version
mongorestore --version
```

Si los comandos no son reconocidos, debe verificarse que el directorio que contiene MongoDB Database Tools se encuentre incluido en la variable de entorno `PATH`.

## Zstandard

Los scripts de backup comprimen los respaldos utilizando **Zstandard**.

### Debian y distribuciones derivadas

```bash
sudo apt install zstd
```

Verificación:

```bash
zstd --version
```

### Windows

Debe instalarse una versión de Zstandard compatible con Windows.

El ejecutable `zstd` debe estar disponible mediante la variable de entorno `PATH`.

Puede comprobarse desde CMD:

```bat
zstd --version
```

## tar

Ambos scripts utilizan `tar` para generar el archivo que posteriormente se comprime con Zstandard.

En Linux suele estar disponible por defecto.

Puede comprobarse mediante:

```bash
tar --version
```

En Windows:

```bat
tar --version
```

Si no estuviera disponible, deberá instalarse una implementación compatible o agregarse al `PATH`.

---

# Variables de entorno

Crear un archivo `.env` a partir de `.env.example`.

Ejemplo:

```env
MONGODB_URI=mongodb+srv://USUARIO:PASSWORD@cluster.mongodb.net/turnos_medicos
PORT=3002
```

El archivo `.env` contiene información sensible y no debe incluirse en el repositorio.

El archivo `.gitignore` debe contener:

```gitignore
node_modules/
dist/
.env
resguardos_tpi/
```

---

# Ejecución de la aplicación

```bash
npm run dev
```

Salida esperada:

```text
Conexión exitosa a MongoDB Atlas
Servidor ejecutándose en http://localhost:3002
```

Con la API en ejecución, el cliente de consola puede iniciarse directamente con:

```bash
npx tsx src/cli_crud.ts
```

El cliente utiliza **Inquirer** para mostrar menús interactivos y solicitar los datos necesarios para las operaciones CRUD.

---


# Estructura del proyecto

```text
tpi-turnos-medicos/
├── src/
│   ├── config/
│   │   └── database.ts
│   ├── models/
│   │   ├── Paciente.ts
│   │   ├── Medico.ts
│   │   └── Turno.ts
│   ├── routes/
│   │   ├── pacientes.routes.ts
│   │   ├── medicos.routes.ts
│   │   └── turnos.routes.ts
│   ├── cli_crud.ts
│   └── index.ts
├── scripts/
│   ├── backup_linux.sh
│   ├── backup_windows.bat
│   ├── test_crud_linux.sh
│   └── test_crud_windows.ps1
├── .env
├── .env.example
├── .gitignore
├── package.json
├── package-lock.json
├── tsconfig.json
└── README.md
```

---

# Pruebas automatizadas del CRUD

El proyecto incluye scripts de prueba automatizada para verificar el funcionamiento de las operaciones CRUD contra la API.

Los scripts disponibles son:

```text
scripts/
├── test_crud_linux.sh
└── test_crud_windows.ps1
```

Las pruebas reutilizan datos identificados como TEST para evitar duplicar pacientes, médicos y turnos principales en ejecuciones sucesivas.

El flujo general incluye:

1. verificación de disponibilidad de la API;
2. creación o reutilización de 5 pacientes TEST;
3. creación o reutilización de 5 médicos TEST;
4. creación o reutilización de 5 turnos TEST;
5. evidencia de los registros obtenidos mediante consultas;
6. pruebas `GET` por ID;
7. pruebas `PATCH` sobre paciente, médico y turno;
8. creación de un turno especial nuevo para probar la baja lógica;
9. ejecución de `DELETE`;
10. validación de que el turno quede con:
    - `estado: "cancelado"`;
    - `activo: false`;
    - `fechaBaja` registrada;
11. verificación de que el turno dado de baja ya no aparezca en el listado de turnos activos;
12. presentación de un resumen final con el resultado de las pruebas.

Los scripts muestran evidencia en consola de los documentos creados o reutilizados, incluyendo identificadores y datos representativos.

## Prueba CRUD en Linux

El script se encuentra en:

```text
scripts/test_crud_linux.sh
```

### Requisitos

Deben estar disponibles:

```text
bash
curl
jq
```

En Debian y distribuciones derivadas pueden instalarse mediante:

```bash
sudo apt install curl jq
```

Puede ser necesario otorgar permisos de ejecución:

```bash
chmod +x scripts/test_crud_linux.sh
```

Con la API ejecutándose en `http://localhost:3002`, la prueba puede iniciarse desde la raíz del proyecto:

```bash
./scripts/test_crud_linux.sh
```

También puede utilizarse una URL diferente definiendo la variable `API_URL`:

```bash
API_URL=http://localhost:3002 ./scripts/test_crud_linux.sh
```

## Prueba CRUD en Windows

El script se encuentra en:

```text
scripts\test_crud_windows.ps1
```

La versión de Windows utiliza PowerShell y no requiere `jq`, ya que procesa las respuestas JSON mediante las herramientas nativas `Invoke-RestMethod` y `ConvertTo-Json`.

Con la API en ejecución puede iniciarse desde PowerShell:

```powershell
.\scripts\test_crud_windows.ps1
```

Si la política de ejecución de PowerShell impide iniciar el script, puede habilitarse temporalmente para la sesión actual:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\test_crud_windows.ps1
```

Este cambio afecta únicamente al proceso actual de PowerShell.

## Resultado esperado

Al finalizar correctamente, ambos scripts muestran un resumen similar a:

```text
============================================================
PRUEBA CRUD FINALIZADA CORRECTAMENTE
============================================================
Pacientes TEST disponibles : 5
Médicos TEST disponibles   : 5
Turnos TEST principales    : 5
GET                        : OK
PATCH                      : OK
DELETE lógico              : OK
============================================================
```

La prueba de baja lógica también muestra evidencia del turno antes y después del `DELETE`, permitiendo comprobar los cambios de `estado`, `activo`, `fechaBaja` y `updatedAt`.


---

# MongoDB Atlas

La aplicación utiliza MongoDB Atlas como servicio remoto de base de datos.

La base utilizada es:

```text
turnos_medicos
```

Colecciones:

```text
pacientes
medicos
turnos
```

La configuración de Atlas contempla:

- Database Access.
- Network Access.
- Cluster remoto.
- Usuario de base de datos.
- URI de conexión mediante `mongodb+srv://`.

---

# Backups

El proyecto incluye dos scripts:

```text
scripts/
├── backup_linux.sh
└── backup_windows.bat
```

Ambos realizan el mismo flujo general:

1. Verifican que exista la variable `MONGODB_URI`.
2. Verifican las herramientas necesarias.
3. Obtienen fecha y hora.
4. Crean una subcarpeta dentro de `resguardos_tpi` con ese valor.
5. Crean dentro de ella un directorio temporal de trabajo.
6. Ejecutan `mongodump` contra MongoDB Atlas.
7. Generan los archivos BSON y sus metadatos.
8. Crean un archivo TAR.
9. Comprimen el respaldo mediante Zstandard.
10. Generan un archivo `.tar.zst` dentro de la subcarpeta correspondiente.
11. Eliminan los archivos temporales.

Los respaldos se almacenan dentro de:

```text
resguardos_tpi/
```

Ambos scripts utilizan el mismo directorio base para mantener un criterio uniforme entre Linux/macOS y Windows.

Ejemplo:

```text
resguardos_tpi/
├── 2026-10-27_12-45-10/
│   └── backup_2026-10-27_12-45-10.tar.zst
├── 2026-10-27_15-30-25/
│   └── backup_2026-10-27_15-30-25.tar.zst
└── 2026-10-27_20-12-41/
    └── backup_2026-10-27_20-12-41.tar.zst
```

Cada respaldo se guarda dentro de una subcarpeta identificada por fecha y hora. De esta forma se cumple con la estructura requerida por el TPI y se permite realizar múltiples respaldos durante el mismo día sin sobrescribir backups anteriores.

---

# Backup en Linux/macOS

El script se encuentra en:

```text
scripts/backup_linux.sh
```

## Requisitos

Deben estar disponibles:

```text
mongodump
tar
zstd
bash
```

Verificación:

```bash
mongodump --version
tar --version
zstd --version
```

## Variable de conexión

El script utiliza:

```text
MONGODB_URI
```

Puede cargarse desde `.env` mediante:

```bash
export $(grep -v '^#' .env | xargs)
```

## Permisos

Puede ser necesario otorgar permisos de ejecución:

```bash
chmod +x scripts/backup_linux.sh
```

## Ejecución

Desde la raíz del proyecto:

```bash
./scripts/backup_linux.sh
```

El archivo generado tendrá un formato similar a:

```text
resguardos_tpi/2026-10-27_18-30-45/backup_2026-10-27_18-30-45.tar.zst
```

---

# Backup en Windows

El script se encuentra en:

```text
scripts\backup_windows.bat
```

## Requisitos

Deben estar disponibles mediante `PATH`:

```text
mongodump
tar
zstd
```

Verificación desde CMD:

```bat
mongodump --version
tar --version
zstd --version
```

## Variable de conexión

El script **no almacena credenciales directamente en el archivo**.

Antes de ejecutarlo debe estar definida la variable:

```text
MONGODB_URI
```

Ejemplo desde CMD:

```bat
set "MONGODB_URI=mongodb+srv://USUARIO:PASSWORD@cluster.mongodb.net/turnos_medicos"
```

## Ejecución

Desde la raíz del proyecto:

```bat
scripts\backup_windows.bat
```

## Funcionamiento

El script de Windows:

1. Determina automáticamente la raíz del proyecto.
2. Obtiene la fecha y hora en formato estable:
   `YYYY-MM-DD_HH-MM-SS`.
3. Comprueba que `MONGODB_URI` esté definida.
4. Comprueba que `mongodump`, `tar` y `zstd` estén disponibles.
5. Crea una subcarpeta dentro de `resguardos_tpi` identificada por fecha y hora.
6. Crea dentro de ella un directorio temporal `dump`.
7. Ejecuta `mongodump`.
8. Genera un archivo `.tar` dentro de la subcarpeta del respaldo.
9. Comprime el archivo mediante Zstandard.
10. Genera el archivo final `.tar.zst` dentro de la misma subcarpeta.
11. Elimina el archivo TAR y el directorio temporal `dump`.
12. Si ocurre un error, intenta limpiar los archivos temporales creados durante la ejecución.

El resultado tendrá un formato similar a:

```text
resguardos_tpi\2026-10-27_18-30-45\backup_2026-10-27_18-30-45.tar.zst
```

---

# Consultar el contenido de un backup

## Linux/macOS

```bash
tar --zstd -tf resguardos_tpi/FECHA_HORA/backup_FECHA_HORA.tar.zst
```

## Windows

Si la versión instalada de `tar` soporta Zstandard:

```bat
tar --zstd -tf resguardos_tpi\FECHA_HORA\backup_FECHA_HORA.tar.zst
```

---

# Extracción de un backup

## Linux/macOS

```bash
mkdir restauracion

tar --zstd -xf \
  resguardos_tpi/FECHA_HORA/backup_FECHA_HORA.tar.zst \
  -C restauracion
```

## Windows

```bat
mkdir restauracion

tar --zstd -xf resguardos_tpi\FECHA_HORA\backup_FECHA_HORA.tar.zst -C restauracion
```

Luego podrán encontrarse los archivos BSON y de metadatos generados originalmente por `mongodump`.

---

# Restauración

Los datos extraídos pueden restaurarse utilizando `mongorestore`.

## Linux/macOS

```bash
mongorestore \
  --uri="$MONGODB_URI" \
  RUTA_DEL_BACKUP_EXTRAIDO/turnos_medicos
```

## Windows

```bat
mongorestore --uri="%MONGODB_URI%" RUTA_DEL_BACKUP_EXTRAIDO\turnos_medicos
```

La restauración debe realizarse cuidadosamente para evitar sobrescribir información existente de forma involuntaria.

---

# RPO y RTO

## RPO

Se establece un RPO de **24 horas**, considerando una política de ejecución diaria del respaldo.

Esto significa que, ante una pérdida total de los datos, podrían perderse como máximo los cambios realizados desde el último backup.

## RTO

Se establece un RTO estimado de **1 hora**.

Este tiempo contempla:

- extracción del respaldo;
- ejecución de `mongorestore`;
- comprobación de los documentos restaurados;
- verificación de la conexión de la aplicación;
- recuperación del funcionamiento normal del sistema.

---

# Seguridad

El archivo `.env` no debe almacenarse en el repositorio porque contiene la URI y las credenciales utilizadas para acceder a MongoDB Atlas.

Por esta razón se utiliza:

```text
.env.example
```

como referencia de las variables necesarias para ejecutar el proyecto.

Ejemplo:

```env
MONGODB_URI=mongodb+srv://USUARIO:PASSWORD@cluster.mongodb.net/turnos_medicos
PORT=3002
```

Los scripts de backup tampoco almacenan credenciales directamente.

La conexión con MongoDB Atlas se obtiene mediante:

```text
MONGODB_URI
```

Las credenciales reales no deben escribirse en archivos versionados ni incluirse en commits.

---

# Autores

**Grupo 24**

- Nombre Apellido 1
- Nombre Apellido 2
- Nombre Apellido 3

Trabajo realizado para la materia **Base de Datos II**.

**Tecnicatura Universitaria en Programación a Distancia - UTN**