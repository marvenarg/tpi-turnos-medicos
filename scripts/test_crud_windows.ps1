$ErrorActionPreference = "Stop"

$ApiUrl = if ($env:API_URL) { $env:API_URL } else { "http://localhost:3002" }

# ============================================================
# Prueba automatizada CRUD - Sistema de Turnos Médicos
# Windows PowerShell
#
# Requiere:
#   - PowerShell
#   - API ejecutándose en http://localhost:3002
#
# Características:
#   - Reutiliza pacientes y médicos TEST existentes.
#   - Evita duplicar los 5 turnos principales.
#   - No elimina datos ajenos a la prueba.
#   - Prueba POST, GET, PATCH y DELETE lógico.
#   - Genera una prueba DELETE nueva en cada ejecución.
# ============================================================

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message"
}

function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Error "ERROR: $Message"
    exit 1
}

function Invoke-Api {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "POST", "PATCH", "DELETE")]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [object]$Body = $null
    )

    $Uri = "$ApiUrl$Path"

    try {
        if ($null -ne $Body) {
            $Json = $Body | ConvertTo-Json -Depth 10

            return Invoke-RestMethod `
                -Method $Method `
                -Uri $Uri `
                -ContentType "application/json" `
                -Body $Json
        }

        return Invoke-RestMethod `
            -Method $Method `
            -Uri $Uri
    }
    catch {
        $detail = $_.Exception.Message

        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $detail = $_.ErrorDetails.Message
        }

        Fail "$Method $Uri -> $detail"
    }
}

function Show-Json {
    param([object]$Value)

    $Value | ConvertTo-Json -Depth 10
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Prueba automatizada CRUD - Sistema de Turnos Médicos"
Write-Host "API: $ApiUrl"
Write-Host "============================================================"
Write-Host ""

# ------------------------------------------------------------
# Comprobar API
# ------------------------------------------------------------

Write-Info "Comprobando que la API esté disponible..."

try {
    [void](Invoke-Api -Method GET -Path "/api/pacientes")
}
catch {
    Fail "La API no responde en $ApiUrl. Ejecute primero: npm run dev"
}

Write-Ok "API disponible."

# ------------------------------------------------------------
# Datos de prueba
# ------------------------------------------------------------

$Dnis = @(
    "99000001",
    "99000002",
    "99000003",
    "99000004",
    "99000005"
)

$PacienteNombres = @(
    "Paciente Test Uno",
    "Paciente Test Dos",
    "Paciente Test Tres",
    "Paciente Test Cuatro",
    "Paciente Test Cinco"
)

$PacienteApellidos = @(
    "Automatizado",
    "Automatizado",
    "Automatizado",
    "Automatizado",
    "Automatizado"
)

$Matriculas = @(
    "TEST001",
    "TEST002",
    "TEST003",
    "TEST004",
    "TEST005"
)

$MedicoNombres = @(
    "Medico Test Uno",
    "Medico Test Dos",
    "Medico Test Tres",
    "Medico Test Cuatro",
    "Medico Test Cinco"
)

$MedicoApellidos = @(
    "Automatizado",
    "Automatizado",
    "Automatizado",
    "Automatizado",
    "Automatizado"
)

$Especialidades = @(
    "Clinica",
    "Cardiologia",
    "Pediatria",
    "Dermatologia",
    "Traumatologia"
)

$Fechas = @(
    "2099-11-10",
    "2099-11-11",
    "2099-11-12",
    "2099-11-13",
    "2099-11-14"
)

$Horas = @(
    "09:00",
    "10:00",
    "11:00",
    "12:00",
    "13:00"
)

$HorasHasta = @(
    "09:30",
    "10:30",
    "11:30",
    "12:30",
    "13:30"
)

$PacienteIds = @()
$MedicoIds = @()
$TurnoIds = @()

# ------------------------------------------------------------
# 1. Crear o reutilizar 5 pacientes
# ------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host "1. Pacientes"
Write-Host "------------------------------------------------------------"

for ($i = 0; $i -lt $Dnis.Count; $i++) {
    $dni = $Dnis[$i]

    $pacientes = @(Invoke-Api -Method GET -Path "/api/pacientes")
    $paciente = $pacientes |
        Where-Object { $_.dni -eq $dni } |
        Select-Object -First 1

    if ($null -ne $paciente) {
        $pacienteId = [string]$paciente._id
        Write-Info "Paciente DNI $dni ya existe. Se reutiliza."
    }
    else {
        $body = @{
            dni      = $dni
            nombre   = $PacienteNombres[$i]
            apellido = $PacienteApellidos[$i]
            contacto = @{
                telefono = "22355500$($i + 1)"
                email    = "paciente.test$($i + 1)@example.com"
            }
            obraSocial = @{
                nombre         = "TEST_OS"
                numeroAfiliado = "TEST-$dni"
            }
        }

        $respuesta = Invoke-Api -Method POST -Path "/api/pacientes" -Body $body
        $pacienteId = [string]$respuesta._id

        Write-Ok "Paciente DNI $dni creado."
    }

    if ([string]::IsNullOrWhiteSpace($pacienteId)) {
        Fail "No se pudo obtener el ID del paciente DNI $dni."
    }

    $PacienteIds += $pacienteId
}

Write-Host ""
Write-Host "Evidencia - Pacientes TEST:"

$pacientesEvidencia = @(
    Invoke-Api -Method GET -Path "/api/pacientes"
) |
Where-Object { $Dnis -contains $_.dni } |
ForEach-Object {
    [pscustomobject]@{
        id       = $_._id
        dni      = $_.dni
        nombre   = "$($_.nombre) $($_.apellido)"
        telefono = $_.contacto.telefono
    }
}

Show-Json $pacientesEvidencia

# ------------------------------------------------------------
# 2. Crear o reutilizar 5 médicos
# ------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host "2. Médicos"
Write-Host "------------------------------------------------------------"

for ($i = 0; $i -lt $Matriculas.Count; $i++) {
    $matricula = $Matriculas[$i]

    $medicos = @(Invoke-Api -Method GET -Path "/api/medicos")
    $medico = $medicos |
        Where-Object { $_.matricula.numero -eq $matricula } |
        Select-Object -First 1

    if ($null -ne $medico) {
        $medicoId = [string]$medico._id
        Write-Info "Médico matrícula $matricula ya existe. Se reutiliza."
    }
    else {
        $body = @{
            nombre       = $MedicoNombres[$i]
            apellido     = $MedicoApellidos[$i]
            matricula    = @{
                numero       = $matricula
                tipo         = "provincial"
                jurisdiccion = "Buenos Aires"
            }
            especialidad = $Especialidades[$i]
            obrasSocialesAceptadas = @("TEST_OS")
            contacto     = @{
                telefono = "22356600$($i + 1)"
                email    = "medico.test$($i + 1)@example.com"
            }
        }

        $respuesta = Invoke-Api -Method POST -Path "/api/medicos" -Body $body
        $medicoId = [string]$respuesta._id

        Write-Ok "Médico matrícula $matricula creado."
    }

    if ([string]::IsNullOrWhiteSpace($medicoId)) {
        Fail "No se pudo obtener el ID del médico matrícula $matricula."
    }

    $MedicoIds += $medicoId
}

Write-Host ""
Write-Host "Evidencia - Médicos TEST:"

$medicosEvidencia = @(
    Invoke-Api -Method GET -Path "/api/medicos"
) |
Where-Object { $Matriculas -contains $_.matricula.numero } |
ForEach-Object {
    [pscustomobject]@{
        id           = $_._id
        matricula    = $_.matricula.numero
        nombre       = "$($_.nombre) $($_.apellido)"
        especialidad = $_.especialidad
    }
}

Show-Json $medicosEvidencia

# ------------------------------------------------------------
# 3. Crear o reutilizar 5 turnos
# ------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host "3. Turnos"
Write-Host "------------------------------------------------------------"

for ($i = 0; $i -lt $Fechas.Count; $i++) {
    $pacienteId = $PacienteIds[$i]
    $medicoId = $MedicoIds[$i]
    $fecha = $Fechas[$i]
    $hora = $Horas[$i]
    $horaHasta = $HorasHasta[$i]
    $fechaHora = "${fecha}T${hora}:00"

    $turnos = @(Invoke-Api -Method GET -Path "/api/turnos")

    $turno = $turnos |
        Where-Object {
            $pid = if ($_.pacienteId -is [string]) {
                $_.pacienteId
            }
            else {
                [string]$_.pacienteId._id
            }

            $mid = if ($_.medicoId -is [string]) {
                $_.medicoId
            }
            else {
                [string]$_.medicoId._id
            }

            $pid -eq $pacienteId -and
            $mid -eq $medicoId -and
            $_.fechaHora -eq $fechaHora
        } |
        Select-Object -First 1

    if ($null -ne $turno) {
        $turnoId = [string]$turno._id
        Write-Info "Turno $fechaHora ya existe. Se reutiliza."
        $TurnoIds += $turnoId
        continue
    }

    $medicoActual = Invoke-Api -Method GET -Path "/api/medicos/$medicoId"

    $slotExiste = @(
        $medicoActual.disponibilidad |
        Where-Object {
            $_.dia -eq $fecha -and
            $_.horaDesde -eq $hora -and
            $_.horaHasta -eq $horaHasta
        }
    ).Count -gt 0

    if (-not $slotExiste) {
        $bodyDisponibilidad = @{
            '$push' = @{
                disponibilidad = @{
                    dia       = $fecha
                    horaDesde = $hora
                    horaHasta = $horaHasta
                }
            }
        }

        [void](Invoke-Api `
            -Method PATCH `
            -Path "/api/medicos/$medicoId" `
            -Body $bodyDisponibilidad)

        Write-Ok "Disponibilidad $fecha $hora agregada al médico $($Matriculas[$i])."
    }

    $bodyTurno = @{
        pacienteId = $pacienteId
        medicoId   = $medicoId
        fechaHora  = $fechaHora
        motivo     = "Turno automatizado TEST $($i + 1)"
    }

    $respuesta = Invoke-Api -Method POST -Path "/api/turnos" -Body $bodyTurno
    $turnoId = [string]$respuesta._id

    if ([string]::IsNullOrWhiteSpace($turnoId)) {
        Fail "No se pudo crear el turno $fechaHora."
    }

    $TurnoIds += $turnoId
    Write-Ok "Turno $fechaHora creado."
}

Write-Host ""
Write-Host "Evidencia - Turnos TEST creados:"

$turnosEvidencia = @(
    Invoke-Api -Method GET -Path "/api/turnos"
) |
Where-Object { $_.motivo -like "Turno automatizado TEST*" } |
ForEach-Object {
    $paciente = if ($_.pacienteId -is [string]) {
        $_.pacienteId
    }
    else {
        "$($_.pacienteId.nombre) $($_.pacienteId.apellido)"
    }

    $medico = if ($_.medicoId -is [string]) {
        $_.medicoId
    }
    else {
        "$($_.medicoId.nombre) $($_.medicoId.apellido)"
    }

    [pscustomobject]@{
        id        = $_._id
        fechaHora = $_.fechaHora
        estado    = $_.estado
        paciente  = $paciente
        medico    = $medico
        motivo    = $_.motivo
    }
}

Show-Json $turnosEvidencia

# ------------------------------------------------------------
# 4. GET por ID
# ------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host "4. Pruebas GET"
Write-Host "------------------------------------------------------------"

Write-Host ""
Write-Host "GET paciente por ID:"

$pacienteGet = Invoke-Api -Method GET -Path "/api/pacientes/$($PacienteIds[0])"

Show-Json ([pscustomobject]@{
    id       = $pacienteGet._id
    dni      = $pacienteGet.dni
    nombre   = "$($pacienteGet.nombre) $($pacienteGet.apellido)"
    contacto = $pacienteGet.contacto
    activo   = $pacienteGet.activo
})

Write-Ok "GET paciente por ID."

Write-Host ""
Write-Host "GET médico por ID:"

$medicoGet = Invoke-Api -Method GET -Path "/api/medicos/$($MedicoIds[0])"

Show-Json ([pscustomobject]@{
    id           = $medicoGet._id
    matricula    = $medicoGet.matricula.numero
    nombre       = "$($medicoGet.nombre) $($medicoGet.apellido)"
    especialidad = $medicoGet.especialidad
    activo       = $medicoGet.activo
})

Write-Ok "GET médico por ID."

Write-Host ""
Write-Host "GET turno por ID:"

$turnoGet = Invoke-Api -Method GET -Path "/api/turnos/$($TurnoIds[0])"

$turnoPaciente = if ($turnoGet.pacienteId -is [string]) {
    $turnoGet.pacienteId
}
else {
    "$($turnoGet.pacienteId.nombre) $($turnoGet.pacienteId.apellido)"
}

$turnoMedico = if ($turnoGet.medicoId -is [string]) {
    $turnoGet.medicoId
}
else {
    "$($turnoGet.medicoId.nombre) $($turnoGet.medicoId.apellido)"
}

Show-Json ([pscustomobject]@{
    id        = $turnoGet._id
    fechaHora = $turnoGet.fechaHora
    estado    = $turnoGet.estado
    paciente  = $turnoPaciente
    medico    = $turnoMedico
    motivo    = $turnoGet.motivo
    activo    = $turnoGet.activo
})

Write-Ok "GET turno por ID."

# ------------------------------------------------------------
# 5. PATCH
# ------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host "5. Pruebas PATCH"
Write-Host "------------------------------------------------------------"

$bodyPaciente = @{
    'contacto.telefono' = "2235999001"
}

[void](Invoke-Api `
    -Method PATCH `
    -Path "/api/pacientes/$($PacienteIds[0])" `
    -Body $bodyPaciente)

Write-Ok "PATCH paciente: teléfono actualizado con notación de punto."

$pacientePatch = Invoke-Api -Method GET -Path "/api/pacientes/$($PacienteIds[0])"

Show-Json ([pscustomobject]@{
    id       = $pacientePatch._id
    dni      = $pacientePatch.dni
    telefono = $pacientePatch.contacto.telefono
})

$bodyMedico = @{
    'contacto.telefono' = "2235999101"
}

[void](Invoke-Api `
    -Method PATCH `
    -Path "/api/medicos/$($MedicoIds[0])" `
    -Body $bodyMedico)

Write-Ok "PATCH médico: teléfono actualizado con notación de punto."

$medicoPatch = Invoke-Api -Method GET -Path "/api/medicos/$($MedicoIds[0])"

Show-Json ([pscustomobject]@{
    id        = $medicoPatch._id
    matricula = $medicoPatch.matricula.numero
    telefono  = $medicoPatch.contacto.telefono
})

$bodyTurnoPatch = @{
    estado = "confirmado"
}

[void](Invoke-Api `
    -Method PATCH `
    -Path "/api/turnos/$($TurnoIds[0])" `
    -Body $bodyTurnoPatch)

Write-Ok "PATCH turno: estado actualizado a confirmado."

$turnoPatch = Invoke-Api -Method GET -Path "/api/turnos/$($TurnoIds[0])"

Show-Json ([pscustomobject]@{
    id        = $turnoPatch._id
    fechaHora = $turnoPatch.fechaHora
    estado    = $turnoPatch.estado
})

# ------------------------------------------------------------
# 6. DELETE lógico
#
# En cada ejecución se crea un turno especial nuevo para probar
# la baja lógica. Esto permite obtener evidencia fresca en cada
# corrida sin reactivar registros históricos ya cancelados.
# ------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host "6. Prueba DELETE lógico"
Write-Host "------------------------------------------------------------"

$pacienteId = $PacienteIds[4]
$medicoId = $MedicoIds[4]

# Generar una fecha/hora diferente en cada ejecución.
$timestampActual = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$diaOffset = ($timestampActual % 20) + 1
$horaNumero = ($timestampActual % 8) + 14

$fechaDelete = "2099-12-{0:D2}" -f $diaOffset
$horaDelete = "{0:D2}:00" -f $horaNumero
$horaHastaDelete = "{0:D2}:30" -f $horaNumero
$fechaHoraDelete = "${fechaDelete}T${horaDelete}:00"

Write-Host ""
Write-Host "Preparando turno especial para prueba DELETE..."
Write-Host "Fecha/hora de prueba: $fechaHoraDelete"

$medicoActual = Invoke-Api -Method GET -Path "/api/medicos/$medicoId"

$slotExiste = @(
    $medicoActual.disponibilidad |
    Where-Object {
        $_.dia -eq $fechaDelete -and
        $_.horaDesde -eq $horaDelete -and
        $_.horaHasta -eq $horaHastaDelete
    }
).Count -gt 0

if (-not $slotExiste) {
    $bodyDisponibilidad = @{
        '$push' = @{
            disponibilidad = @{
                dia       = $fechaDelete
                horaDesde = $horaDelete
                horaHasta = $horaHastaDelete
            }
        }
    }

    [void](Invoke-Api `
        -Method PATCH `
        -Path "/api/medicos/$medicoId" `
        -Body $bodyDisponibilidad)

    Write-Ok "Disponibilidad especial agregada al médico $($Matriculas[4])."
}

$bodyDeleteTurno = @{
    pacienteId = $pacienteId
    medicoId   = $medicoId
    fechaHora  = $fechaHoraDelete
    motivo     = "Turno especial para prueba DELETE lógico"
}

$turnoDelete = Invoke-Api `
    -Method POST `
    -Path "/api/turnos" `
    -Body $bodyDeleteTurno

$DeleteTurnoId = [string]$turnoDelete._id

if ([string]::IsNullOrWhiteSpace($DeleteTurnoId)) {
    Fail "No se pudo obtener el ID del turno especial para DELETE."
}

Write-Ok "Turno especial para DELETE creado."

Write-Host ""
Write-Host "Evidencia - Turno antes de la baja lógica:"

Show-Json ([pscustomobject]@{
    id        = $turnoDelete._id
    fechaHora = $turnoDelete.fechaHora
    estado    = $turnoDelete.estado
    motivo    = $turnoDelete.motivo
    activo    = $turnoDelete.activo
    fechaBaja = $turnoDelete.fechaBaja
    createdAt = $turnoDelete.createdAt
    updatedAt = $turnoDelete.updatedAt
})

Write-Host ""
Write-Host "Ejecutando DELETE lógico..."

$deleteResponse = Invoke-Api `
    -Method DELETE `
    -Path "/api/turnos/$DeleteTurnoId"

Write-Ok "DELETE lógico ejecutado sobre el turno $DeleteTurnoId."

Write-Host ""
Write-Host "Evidencia - Respuesta de la API al DELETE:"

Show-Json $deleteResponse

# La API puede devolver el turno directamente o dentro de "turno".
if ($null -ne $deleteResponse.turno) {
    $turnoBaja = $deleteResponse.turno
}
else {
    $turnoBaja = $deleteResponse
}

Write-Host ""
Write-Host "Evidencia - Turno después de la baja lógica:"

Show-Json ([pscustomobject]@{
    id        = $turnoBaja._id
    fechaHora = $turnoBaja.fechaHora
    estado    = $turnoBaja.estado
    motivo    = $turnoBaja.motivo
    activo    = $turnoBaja.activo
    fechaBaja = $turnoBaja.fechaBaja
    createdAt = $turnoBaja.createdAt
    updatedAt = $turnoBaja.updatedAt
})

if ($turnoBaja.estado -ne "cancelado") {
    Fail "El turno no quedó con estado cancelado."
}

if ($turnoBaja.activo -ne $false) {
    Fail "El turno no quedó con activo=false."
}

if ($null -eq $turnoBaja.fechaBaja -or [string]::IsNullOrWhiteSpace([string]$turnoBaja.fechaBaja)) {
    Fail "El turno no registró fechaBaja."
}

Write-Ok "La respuesta confirma estado=cancelado, activo=false y fechaBaja registrada."

$turnosFinales = @(Invoke-Api -Method GET -Path "/api/turnos")

$turnoActivoEncontrado = $turnosFinales |
    Where-Object { [string]$($_._id) -eq $DeleteTurnoId } |
    Select-Object -First 1

if ($null -ne $turnoActivoEncontrado) {
    Fail "El turno dado de baja todavía aparece en el listado de turnos activos."
}
else {
    Write-Ok "El turno dado de baja no aparece en el listado activo."
}

# ------------------------------------------------------------
# 7. Resumen
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host "PRUEBA CRUD FINALIZADA CORRECTAMENTE"
Write-Host "============================================================"
Write-Host "Pacientes TEST disponibles : $($PacienteIds.Count)"
Write-Host "Médicos TEST disponibles   : $($MedicoIds.Count)"
Write-Host "Turnos TEST principales    : $($TurnoIds.Count)"
Write-Host "GET                        : OK"
Write-Host "PATCH                      : OK"
Write-Host "DELETE lógico              : OK"
Write-Host "============================================================"
Write-Host ""

Write-Host "IDs de pacientes:"
$PacienteIds | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "IDs de médicos:"
$MedicoIds | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "IDs de turnos:"
$TurnoIds | ForEach-Object { Write-Host "  $_" }

Write-Host ""
