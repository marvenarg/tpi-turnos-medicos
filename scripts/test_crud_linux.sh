#!/bin/bash

set -euo pipefail

API_URL="${API_URL:-http://localhost:3002}"

# ============================================================
# Prueba automatizada CRUD - Sistema de Turnos Médicos
#
# Requiere:
#   - curl
#   - jq
#   - API ejecutándose en http://localhost:3002
#
# Características:
#   - Reutiliza pacientes y médicos TEST existentes.
#   - Evita duplicar los 5 turnos principales.
#   - No elimina datos ajenos a la prueba.
#   - Prueba POST, GET, PATCH y DELETE lógico.
#   - Genera una prueba DELETE nueva en cada ejecución.
# ============================================================

echo
echo "============================================================"
echo "Prueba automatizada CRUD - Sistema de Turnos Médicos"
echo "API: $API_URL"
echo "============================================================"
echo

# ------------------------------------------------------------
# Utilidades
# ------------------------------------------------------------

error() {
    echo
    echo "ERROR: $1" >&2
    exit 1
}

ok() {
    echo "[OK] $1"
}

info() {
    echo "[INFO] $1"
}

command -v curl >/dev/null 2>&1 || error "curl no está instalado."
command -v jq >/dev/null 2>&1 || error "jq no está instalado."

# ------------------------------------------------------------
# Comprobar API
# ------------------------------------------------------------

info "Comprobando que la API esté disponible..."

if ! curl -fsS "$API_URL/api/pacientes" >/dev/null; then
    error "La API no responde en $API_URL. Ejecute primero: npm run dev"
fi

ok "API disponible."

# ------------------------------------------------------------
# Datos de prueba
# ------------------------------------------------------------

DNIS=(
    "99000001"
    "99000002"
    "99000003"
    "99000004"
    "99000005"
)

PACIENTE_NOMBRES=(
    "Paciente Test Uno"
    "Paciente Test Dos"
    "Paciente Test Tres"
    "Paciente Test Cuatro"
    "Paciente Test Cinco"
)

PACIENTE_APELLIDOS=(
    "Automatizado"
    "Automatizado"
    "Automatizado"
    "Automatizado"
    "Automatizado"
)

MATRICULAS=(
    "TEST001"
    "TEST002"
    "TEST003"
    "TEST004"
    "TEST005"
)

MEDICO_NOMBRES=(
    "Medico Test Uno"
    "Medico Test Dos"
    "Medico Test Tres"
    "Medico Test Cuatro"
    "Medico Test Cinco"
)

MEDICO_APELLIDOS=(
    "Automatizado"
    "Automatizado"
    "Automatizado"
    "Automatizado"
    "Automatizado"
)

ESPECIALIDADES=(
    "Clinica"
    "Cardiologia"
    "Pediatria"
    "Dermatologia"
    "Traumatologia"
)

FECHAS=(
    "2099-11-10"
    "2099-11-11"
    "2099-11-12"
    "2099-11-13"
    "2099-11-14"
)

HORAS=(
    "09:00"
    "10:00"
    "11:00"
    "12:00"
    "13:00"
)

HORAS_HASTA=(
    "09:30"
    "10:30"
    "11:30"
    "12:30"
    "13:30"
)

PACIENTE_IDS=()
MEDICO_IDS=()
TURNO_IDS=()

# ------------------------------------------------------------
# 1. Crear o reutilizar 5 pacientes
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo "1. Pacientes"
echo "------------------------------------------------------------"

for i in "${!DNIS[@]}"; do
    dni="${DNIS[$i]}"

    pacientes_json=$(curl -fsS "$API_URL/api/pacientes")
    paciente_id=$(echo "$pacientes_json" | jq -r --arg dni "$dni" \
        '.[] | select(.dni == $dni) | ._id' | head -n 1)

    if [ -n "$paciente_id" ] && [ "$paciente_id" != "null" ]; then
        info "Paciente DNI $dni ya existe. Se reutiliza."
    else
        payload=$(jq -n \
            --arg dni "$dni" \
            --arg nombre "${PACIENTE_NOMBRES[$i]}" \
            --arg apellido "${PACIENTE_APELLIDOS[$i]}" \
            --arg telefono "22355500$((i + 1))" \
            --arg email "paciente.test$((i + 1))@example.com" \
            '{
                dni: $dni,
                nombre: $nombre,
                apellido: $apellido,
                contacto: {
                    telefono: $telefono,
                    email: $email
                },
                obraSocial: {
                    nombre: "TEST_OS",
                    numeroAfiliado: ("TEST-" + $dni)
                }
            }')

        respuesta=$(curl -sS -w '\n%{http_code}' -X POST "$API_URL/api/pacientes" \
            -H "Content-Type: application/json" \
            -d "$payload")

        http_code=$(echo "$respuesta" | tail -n 1)
        body=$(echo "$respuesta" | sed '$d')

        if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
            echo "$body" | jq . 2>/dev/null || echo "$body"
            error "POST /api/pacientes devolvió HTTP $http_code para DNI $dni."
        fi

        paciente_id=$(echo "$body" | jq -r '._id')
        ok "Paciente DNI $dni creado."
    fi

    [ -n "$paciente_id" ] && [ "$paciente_id" != "null" ] \
        || error "No se pudo obtener el ID del paciente DNI $dni."

    PACIENTE_IDS+=("$paciente_id")
done


echo
echo "Evidencia - Pacientes TEST:"
curl -fsS "$API_URL/api/pacientes" | jq \
    --argjson dnis '["99000001","99000002","99000003","99000004","99000005"]' \
    '[.[] | select(.dni as $d | $dnis | index($d)) | {
        id: ._id,
        dni: .dni,
        nombre: (.nombre + " " + .apellido),
        telefono: .contacto.telefono
    }]'
echo

# ------------------------------------------------------------
# 2. Crear o reutilizar 5 médicos
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo "2. Médicos"
echo "------------------------------------------------------------"

for i in "${!MATRICULAS[@]}"; do
    matricula="${MATRICULAS[$i]}"

    medicos_json=$(curl -fsS "$API_URL/api/medicos")
    medico_id=$(echo "$medicos_json" | jq -r --arg matricula "$matricula" \
        '.[] | select(.matricula.numero == $matricula) | ._id' | head -n 1)

    if [ -n "$medico_id" ] && [ "$medico_id" != "null" ]; then
        info "Médico matrícula $matricula ya existe. Se reutiliza."
    else
        payload=$(jq -n \
            --arg nombre "${MEDICO_NOMBRES[$i]}" \
            --arg apellido "${MEDICO_APELLIDOS[$i]}" \
            --arg matricula "$matricula" \
            --arg especialidad "${ESPECIALIDADES[$i]}" \
            --arg telefono "22356600$((i + 1))" \
            --arg email "medico.test$((i + 1))@example.com" \
            '{
                nombre: $nombre,
                apellido: $apellido,
                matricula: {
                    numero: $matricula,
                    tipo: "provincial",
                    jurisdiccion: "Buenos Aires"
                },
                especialidad: $especialidad,
                obrasSocialesAceptadas: ["TEST_OS"],
                contacto: {
                    telefono: $telefono,
                    email: $email
                }
            }')

        respuesta=$(curl -sS -w '\n%{http_code}' -X POST "$API_URL/api/medicos" \
            -H "Content-Type: application/json" \
            -d "$payload")

        http_code=$(echo "$respuesta" | tail -n 1)
        body=$(echo "$respuesta" | sed '$d')

        if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
            echo "$body" | jq . 2>/dev/null || echo "$body"
            error "POST /api/medicos devolvió HTTP $http_code para matrícula $matricula."
        fi

        medico_id=$(echo "$body" | jq -r '._id')
        ok "Médico matrícula $matricula creado."
    fi

    [ -n "$medico_id" ] && [ "$medico_id" != "null" ] \
        || error "No se pudo obtener el ID del médico matrícula $matricula."

    MEDICO_IDS+=("$medico_id")
done


echo
echo "Evidencia - Médicos TEST:"
curl -fsS "$API_URL/api/medicos" | jq \
    --argjson mats '["TEST001","TEST002","TEST003","TEST004","TEST005"]' \
    '[.[] | select(.matricula.numero as $m | $mats | index($m)) | {
        id: ._id,
        matricula: .matricula.numero,
        nombre: (.nombre + " " + .apellido),
        especialidad: .especialidad
    }]'
echo

# ------------------------------------------------------------
# 3. Crear o reutilizar 5 turnos
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo "3. Turnos"
echo "------------------------------------------------------------"

for i in "${!FECHAS[@]}"; do
    paciente_id="${PACIENTE_IDS[$i]}"
    medico_id="${MEDICO_IDS[$i]}"
    fecha="${FECHAS[$i]}"
    hora="${HORAS[$i]}"
    hora_hasta="${HORAS_HASTA[$i]}"
    fecha_hora="${fecha}T${hora}:00"

    turnos_json=$(curl -fsS "$API_URL/api/turnos")

    turno_id=$(echo "$turnos_json" | jq -r \
        --arg pid "$paciente_id" \
        --arg mid "$medico_id" \
        --arg fh "$fecha_hora" \
        '
        .[] |
        select(
            ((if (.pacienteId | type) == "object" then .pacienteId._id else .pacienteId end) == $pid)
            and
            ((if (.medicoId | type) == "object" then .medicoId._id else .medicoId end) == $mid)
            and
            (.fechaHora == $fh)
        ) |
        ._id
        ' | head -n 1)

    if [ -n "$turno_id" ] && [ "$turno_id" != "null" ]; then
        info "Turno $fecha_hora ya existe. Se reutiliza."
        TURNO_IDS+=("$turno_id")
        continue
    fi

    # Si el turno no existe, aseguramos que el horario esté disponible.
    medico_json=$(curl -fsS "$API_URL/api/medicos/$medico_id")

    slot_existe=$(echo "$medico_json" | jq -r \
        --arg dia "$fecha" \
        --arg desde "$hora" \
        --arg hasta "$hora_hasta" \
        '[.disponibilidad[]? |
          select(.dia == $dia and .horaDesde == $desde and .horaHasta == $hasta)
        ] | length')

    if [ "$slot_existe" -eq 0 ]; then
        payload_disponibilidad=$(jq -n \
            --arg dia "$fecha" \
            --arg desde "$hora" \
            --arg hasta "$hora_hasta" \
            '{
                "$push": {
                    disponibilidad: {
                        dia: $dia,
                        horaDesde: $desde,
                        horaHasta: $hasta
                    }
                }
            }')

        curl -fsS -X PATCH "$API_URL/api/medicos/$medico_id" \
            -H "Content-Type: application/json" \
            -d "$payload_disponibilidad" >/dev/null

        ok "Disponibilidad $fecha $hora agregada al médico ${MATRICULAS[$i]}."
    fi

    payload_turno=$(jq -n \
        --arg pacienteId "$paciente_id" \
        --arg medicoId "$medico_id" \
        --arg fechaHora "$fecha_hora" \
        --arg motivo "Turno automatizado TEST $((i + 1))" \
        '{
            pacienteId: $pacienteId,
            medicoId: $medicoId,
            fechaHora: $fechaHora,
            motivo: $motivo
        }')

    respuesta=$(curl -sS -w '\n%{http_code}' -X POST "$API_URL/api/turnos" \
        -H "Content-Type: application/json" \
        -d "$payload_turno")

    http_code=$(echo "$respuesta" | tail -n 1)
    body=$(echo "$respuesta" | sed '$d')

    if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
        echo "$body" | jq . 2>/dev/null || echo "$body"
        error "POST /api/turnos devolvió HTTP $http_code para $fecha_hora."
    fi

    turno_id=$(echo "$body" | jq -r '._id')

    [ -n "$turno_id" ] && [ "$turno_id" != "null" ] \
        || error "No se pudo crear el turno $fecha_hora."

    TURNO_IDS+=("$turno_id")
    ok "Turno $fecha_hora creado."
done


echo
echo "Evidencia - Turnos TEST creados:"
curl -fsS "$API_URL/api/turnos" | jq \
    '[.[] | select(.motivo | startswith("Turno automatizado TEST")) | {
        id: ._id,
        fechaHora: .fechaHora,
        estado: .estado,
        paciente: (
            if (.pacienteId | type) == "object"
            then (.pacienteId.nombre + " " + .pacienteId.apellido)
            else .pacienteId
            end
        ),
        medico: (
            if (.medicoId | type) == "object"
            then (.medicoId.nombre + " " + .medicoId.apellido)
            else .medicoId
            end
        ),
        motivo: .motivo
    }]'
echo

# ------------------------------------------------------------
# 4. GET por ID
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo "4. Pruebas GET"
echo "------------------------------------------------------------"

echo
echo "GET paciente por ID:"
paciente_get=$(curl -fsS "$API_URL/api/pacientes/${PACIENTE_IDS[0]}")
echo "$paciente_get" | jq '{
    id: ._id,
    dni: .dni,
    nombre: (.nombre + " " + .apellido),
    contacto: .contacto,
    activo: .activo
}'
ok "GET paciente por ID."

echo
echo "GET médico por ID:"
medico_get=$(curl -fsS "$API_URL/api/medicos/${MEDICO_IDS[0]}")
echo "$medico_get" | jq '{
    id: ._id,
    matricula: .matricula.numero,
    nombre: (.nombre + " " + .apellido),
    especialidad: .especialidad,
    activo: .activo
}'
ok "GET médico por ID."

echo
echo "GET turno por ID:"
turno_get=$(curl -fsS "$API_URL/api/turnos/${TURNO_IDS[0]}")
echo "$turno_get" | jq '{
    id: ._id,
    fechaHora: .fechaHora,
    estado: .estado,
    paciente: (
        if (.pacienteId | type) == "object"
        then (.pacienteId.nombre + " " + .pacienteId.apellido)
        else .pacienteId
        end
    ),
    medico: (
        if (.medicoId | type) == "object"
        then (.medicoId.nombre + " " + .medicoId.apellido)
        else .medicoId
        end
    ),
    motivo: .motivo,
    activo: .activo
}'
ok "GET turno por ID."

# ------------------------------------------------------------
# 5. PATCH
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo "5. Pruebas PATCH"
echo "------------------------------------------------------------"

payload_paciente=$(jq -n \
    '{"contacto.telefono": "2235999001"}')

curl -fsS -X PATCH "$API_URL/api/pacientes/${PACIENTE_IDS[0]}" \
    -H "Content-Type: application/json" \
    -d "$payload_paciente" >/dev/null

ok "PATCH paciente: teléfono actualizado con notación de punto."
curl -fsS "$API_URL/api/pacientes/${PACIENTE_IDS[0]}" | jq '{
    id: ._id,
    dni: .dni,
    telefono: .contacto.telefono
}'

payload_medico=$(jq -n \
    '{"contacto.telefono": "2235999101"}')

curl -fsS -X PATCH "$API_URL/api/medicos/${MEDICO_IDS[0]}" \
    -H "Content-Type: application/json" \
    -d "$payload_medico" >/dev/null

ok "PATCH médico: teléfono actualizado con notación de punto."
curl -fsS "$API_URL/api/medicos/${MEDICO_IDS[0]}" | jq '{
    id: ._id,
    matricula: .matricula.numero,
    telefono: .contacto.telefono
}'

payload_turno=$(jq -n \
    '{estado: "confirmado"}')

curl -fsS -X PATCH "$API_URL/api/turnos/${TURNO_IDS[0]}" \
    -H "Content-Type: application/json" \
    -d "$payload_turno" >/dev/null

ok "PATCH turno: estado actualizado a confirmado."
curl -fsS "$API_URL/api/turnos/${TURNO_IDS[0]}" | jq '{
    id: ._id,
    fechaHora: .fechaHora,
    estado: .estado
}'

# ------------------------------------------------------------
# 6. DELETE lógico
#
# En cada ejecución se crea un turno especial nuevo para probar
# la baja lógica. Esto permite obtener evidencia fresca en cada
# corrida sin reactivar registros históricos ya cancelados.
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo "6. Prueba DELETE lógico"
echo "------------------------------------------------------------"

paciente_id="${PACIENTE_IDS[4]}"
medico_id="${MEDICO_IDS[4]}"

# Generar una fecha/hora de prueba distinta en cada ejecución.
# Se usa una fecha lejana válida para evitar conflictos con los
# turnos principales y se varían segundos/minutos a partir del
# momento actual.
timestamp_actual=$(date +%s)
dia_offset=$((timestamp_actual % 20 + 1))
hora_delete=$(printf "%02d:00" $((timestamp_actual % 8 + 14)))
hora_hasta_delete=$(printf "%02d:30" $((timestamp_actual % 8 + 14)))
fecha_delete=$(printf "2099-12-%02d" "$dia_offset")
fecha_hora_delete="${fecha_delete}T${hora_delete}:00"

echo
echo "Preparando turno especial para prueba DELETE..."
echo "Fecha/hora de prueba: $fecha_hora_delete"

medico_json=$(curl -fsS "$API_URL/api/medicos/$medico_id")

slot_existe=$(echo "$medico_json" | jq -r \
    --arg dia "$fecha_delete" \
    --arg desde "$hora_delete" \
    --arg hasta "$hora_hasta_delete" \
    '[.disponibilidad[]? |
      select(.dia == $dia and .horaDesde == $desde and .horaHasta == $hasta)
    ] | length')

if [ "$slot_existe" -eq 0 ]; then
    payload_disponibilidad=$(jq -n \
        --arg dia "$fecha_delete" \
        --arg desde "$hora_delete" \
        --arg hasta "$hora_hasta_delete" \
        '{
            "$push": {
                disponibilidad: {
                    dia: $dia,
                    horaDesde: $desde,
                    horaHasta: $hasta
                }
            }
        }')

    curl -fsS -X PATCH "$API_URL/api/medicos/$medico_id" \
        -H "Content-Type: application/json" \
        -d "$payload_disponibilidad" >/dev/null

    ok "Disponibilidad especial agregada al médico ${MATRICULAS[4]}."
fi

payload_delete_turno=$(jq -n \
    --arg pacienteId "$paciente_id" \
    --arg medicoId "$medico_id" \
    --arg fechaHora "$fecha_hora_delete" \
    '{
        pacienteId: $pacienteId,
        medicoId: $medicoId,
        fechaHora: $fechaHora,
        motivo: "Turno especial para prueba DELETE lógico"
    }')

respuesta=$(curl -sS -w '\n%{http_code}' -X POST "$API_URL/api/turnos" \
    -H "Content-Type: application/json" \
    -d "$payload_delete_turno")

http_code=$(echo "$respuesta" | tail -n 1)
body=$(echo "$respuesta" | sed '$d')

if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    echo "$body" | jq . 2>/dev/null || echo "$body"
    error "POST /api/turnos devolvió HTTP $http_code durante la prueba DELETE."
fi

DELETE_TURNO_ID=$(echo "$body" | jq -r '._id')

[ -n "$DELETE_TURNO_ID" ] && [ "$DELETE_TURNO_ID" != "null" ] \
    || error "No se pudo obtener el ID del turno especial para DELETE."

ok "Turno especial para DELETE creado."

echo
echo "Evidencia - Turno antes de la baja lógica:"
echo "$body" | jq '{
    id: ._id,
    fechaHora: .fechaHora,
    estado: .estado,
    motivo: .motivo,
    activo: .activo,
    fechaBaja: .fechaBaja,
    createdAt: .createdAt,
    updatedAt: .updatedAt
}'

echo
echo "Ejecutando DELETE lógico..."

delete_response=$(curl -sS -w '\n%{http_code}' -X DELETE \
    "$API_URL/api/turnos/$DELETE_TURNO_ID")

delete_http_code=$(echo "$delete_response" | tail -n 1)
delete_body=$(echo "$delete_response" | sed '$d')

if [[ "$delete_http_code" -lt 200 || "$delete_http_code" -ge 300 ]]; then
    echo "$delete_body" | jq . 2>/dev/null || echo "$delete_body"
    error "DELETE /api/turnos/$DELETE_TURNO_ID devolvió HTTP $delete_http_code."
fi

ok "DELETE lógico ejecutado sobre el turno $DELETE_TURNO_ID."

echo
echo "Evidencia - Respuesta de la API al DELETE:"
echo "$delete_body" | jq .

# La respuesta del DELETE puede ser el turno directamente o venir
# dentro de una propiedad "turno". Se normaliza para mostrar evidencia.
DELETE_EVIDENCIA=$(echo "$delete_body" | jq -c '{
    id: (if has("_id") then ._id elif (.turno? | type) == "object" then .turno._id else null end),
    fechaHora: (if has("fechaHora") then .fechaHora elif (.turno? | type) == "object" then .turno.fechaHora else null end),
    estado: (if has("estado") then .estado elif (.turno? | type) == "object" then .turno.estado else null end),
    motivo: (if has("motivo") then .motivo elif (.turno? | type) == "object" then .turno.motivo else null end),
    activo: (if has("activo") then .activo elif (.turno? | type) == "object" then .turno.activo else null end),
    fechaBaja: (if has("fechaBaja") then .fechaBaja elif (.turno? | type) == "object" then .turno.fechaBaja else null end),
    createdAt: (if has("createdAt") then .createdAt elif (.turno? | type) == "object" then .turno.createdAt else null end),
    updatedAt: (if has("updatedAt") then .updatedAt elif (.turno? | type) == "object" then .turno.updatedAt else null end)
}')

echo
echo "Evidencia - Turno después de la baja lógica:"
echo "$DELETE_EVIDENCIA" | jq .

# Verificar que la respuesta indique efectivamente la baja lógica.
delete_estado=$(echo "$DELETE_EVIDENCIA" | jq -r '.estado')
delete_activo=$(echo "$DELETE_EVIDENCIA" | jq -r '.activo')
delete_fecha_baja=$(echo "$DELETE_EVIDENCIA" | jq -r '.fechaBaja')

if [ "$delete_estado" != "cancelado" ]; then
    error "El turno no quedó con estado cancelado."
fi

if [ "$delete_activo" != "false" ]; then
    error "El turno no quedó con activo=false."
fi

if [ -z "$delete_fecha_baja" ] || [ "$delete_fecha_baja" = "null" ]; then
    error "El turno no registró fechaBaja."
fi

ok "La respuesta confirma estado=cancelado, activo=false y fechaBaja registrada."

# Verificar que el turno dado de baja no aparezca en el listado activo.
turnos_finales=$(curl -fsS "$API_URL/api/turnos")

if echo "$turnos_finales" | jq -e --arg id "$DELETE_TURNO_ID" \
    '.[] | select(._id == $id)' >/dev/null; then
    error "El turno dado de baja todavía aparece en el listado de turnos activos."
else
    ok "El turno dado de baja no aparece en el listado activo."
fi

# ------------------------------------------------------------
# 7. Resumen
# ------------------------------------------------------------

echo
echo "============================================================"
echo "PRUEBA CRUD FINALIZADA CORRECTAMENTE"
echo "============================================================"
echo "Pacientes TEST disponibles : ${#PACIENTE_IDS[@]}"
echo "Médicos TEST disponibles   : ${#MEDICO_IDS[@]}"
echo "Turnos TEST principales    : ${#TURNO_IDS[@]}"
echo "GET                        : OK"
echo "PATCH                      : OK"
echo "DELETE lógico              : OK"
echo "============================================================"
echo
echo "IDs de pacientes:"
printf '  %s\n' "${PACIENTE_IDS[@]}"
echo
echo "IDs de médicos:"
printf '  %s\n' "${MEDICO_IDS[@]}"
echo
echo "IDs de turnos:"
printf '  %s\n' "${TURNO_IDS[@]}"
echo
