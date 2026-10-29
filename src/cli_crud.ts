import inquirer from 'inquirer';

const BASE_URL = 'http://localhost:3002';

async function invocarApi(metodo: string, ruta: string, cuerpo: any = null): Promise<any> {
    const opciones: RequestInit = { method: metodo };
    
    if (cuerpo) {
        opciones.headers = { "Content-Type": "application/json" };
        opciones.body = JSON.stringify(cuerpo);
    }
    
    try {
        const respuesta = await fetch(`${BASE_URL}${ruta}`, opciones);
        const datos = await respuesta.json().catch(() => null);
        
        if (!respuesta.ok) {
            console.log(`\x1b[31mError HTTP ${respuesta.status}\x1b[0m`);
            if (datos && datos.error) console.log(`\x1b[33mMotivo: ${datos.error}\x1b[0m`);
            return null;
        }
        
        console.log('\x1b[32mOperación exitosa\x1b[0m');
        if (datos) console.log(datos);
        return datos;
    } catch (error: any) {
        console.log(`\x1b[31mFallo en la red: ${error.message}\x1b[0m`);
        return null;
    }
}

async function crearPaciente() {
    const paciente = await inquirer.prompt([
        { type: 'input', name: 'dni', message: 'DNI único:', validate: (i) => i.trim() !== '' ? true : 'Obligatorio' },
        { type: 'input', name: 'nombre', message: 'Nombre:', validate: (i) => i.trim() !== '' ? true : 'Obligatorio' },
        { type: 'input', name: 'apellido', message: 'Apellido:', validate: (i) => i.trim() !== '' ? true : 'Obligatorio' },
        { type: 'input', name: 'fechaNacimiento', message: 'Fecha nacimiento (AAAA-MM-DD) [opcional]:' }
    ]);

    const contacto = await inquirer.prompt([
        { type: 'input', name: 'telefono', message: 'Teléfono:' },
        { type: 'input', name: 'email', message: 'Email:' }
    ]);

    const obraSocial = await inquirer.prompt([
        { type: 'input', name: 'nombre', message: 'Nombre de Obra Social:' },
        { type: 'input', name: 'numeroAfiliado', message: 'Número de Afiliado:' }
    ]);

    const cuerpoPost: any = { 
        dni: paciente.dni, 
        nombre: paciente.nombre, 
        apellido: paciente.apellido, 
        contacto 
    };

    if (paciente.fechaNacimiento) cuerpoPost.fechaNacimiento = paciente.fechaNacimiento;
    if (obraSocial.nombre || obraSocial.numeroAfiliado) cuerpoPost.obraSocial = obraSocial;

    await invocarApi("POST", "/api/pacientes", cuerpoPost);
}

async function crearMedico() {
    const medico = await inquirer.prompt([
        { type: 'input', name: 'nombre', message: 'Nombre:', validate: (i) => i.trim() !== '' ? true : 'Obligatorio' },
        { type: 'input', name: 'apellido', message: 'Apellido:', validate: (i) => i.trim() !== '' ? true : 'Obligatorio' },
        { type: 'input', name: 'especialidad', message: 'Especialidad:', validate: (i) => i.trim() !== '' ? true : 'Obligatorio' },
        { type: 'input', name: 'obrasSociales', message: 'Obras sociales aceptadas (separadas por coma):' }
    ]);

    const matricula = await inquirer.prompt([
        { type: 'input', name: 'numero', message: 'Número de matrícula:', validate: (i) => i.trim() !== '' ? true : 'Obligatorio' },
        { type: 'select', name: 'tipo', message: 'Tipo de matrícula:', choices: ['nacional', 'provincial'], loop: false },
        { type: 'input', name: 'jurisdiccion', message: 'Jurisdicción:' }
    ]);

    const contacto = await inquirer.prompt([
        { type: 'input', name: 'telefono', message: 'Teléfono:' },
        { type: 'input', name: 'email', message: 'Email:' }
    ]);

    const cuerpoPost = {
        nombre: medico.nombre,
        apellido: medico.apellido,
        especialidad: medico.especialidad,
        matricula: {
            numero: matricula.numero,
            tipo: matricula.tipo,
            jurisdiccion: matricula.jurisdiccion || undefined
        },
        contacto,
        obrasSocialesAceptadas: medico.obrasSociales ? medico.obrasSociales.split(',').map((o: string) => o.trim()) : []
    };

    await invocarApi("POST", "/api/medicos", cuerpoPost);
}

async function crearTurno() {
    const respuestasIds = await inquirer.prompt([
        { type: 'input', name: 'pacienteId', message: 'ID del paciente:', validate: (i) => i.trim() !== '' ? true : 'Obligatorio' },
        { type: 'input', name: 'medicoId', message: 'ID del médico:', validate: (i) => i.trim() !== '' ? true : 'Obligatorio' }
    ]);

    const resMedico = await fetch(`${BASE_URL}/api/medicos/${respuestasIds.medicoId}`);
    if (!resMedico.ok) {
        console.log("\x1b[31mError: No se encontró al médico o se encuentra inactivo.\x1b[0m");
        return;
    }
    const medico = await resMedico.json();

    if (!medico.disponibilidad || medico.disponibilidad.length === 0) {
        console.log("\x1b[33mEl médico seleccionado no tiene horarios disponibles en su agenda.\x1b[0m");
        return;
    }

    const opcionesHorarios = medico.disponibilidad.map((slot: any) => ({
        name: `${slot.dia} | Desde: ${slot.horaDesde} - Hasta: ${slot.horaHasta}`,
        value: { dia: slot.dia, horaDesde: slot.horaDesde }
    }));

    const { horarioSeleccionado, motivo } = await inquirer.prompt([
        {
            type: 'select',
            name: 'horarioSeleccionado',
            message: 'Seleccione un horario disponible:',
            choices: opcionesHorarios,
            loop: false
        },
        { 
            type: 'input', 
            name: 'motivo', 
            message: 'Motivo:', 
            validate: (i) => i.trim() !== '' ? true : 'Obligatorio' 
        }
    ]);

    // Ensamblamos el formato YYYY-MM-DDTHH:mm:00 (String literal)
    const fechaHoraIso = `${horarioSeleccionado.dia}T${horarioSeleccionado.horaDesde}:00`;

    const nuevoTurno = {
        pacienteId: respuestasIds.pacienteId,
        medicoId: respuestasIds.medicoId,
        fechaHora: fechaHoraIso,
        motivo: motivo
    };

    await invocarApi("POST", "/api/turnos", nuevoTurno);
}

async function cargarDisponibilidadMedico() {
    console.log(`\n--- Cargar Horarios Disponibles ---`);
    const { id } = await inquirer.prompt([
        { type: 'input', name: 'id', message: 'ID del Médico a actualizar:', validate: (i) => i.trim() !== '' ? true : 'Obligatorio' }
    ]);

    let agregando = true;
    const nuevosHorarios = [];

    while (agregando) {
        const slot = await inquirer.prompt([
            { type: 'input', name: 'dia', message: 'Día (AAAA-MM-DD):', validate: (i) => /^\d{4}-\d{2}-\d{2}$/.test(i.trim()) ? true : 'Use formato AAAA-MM-DD' },
            { type: 'input', name: 'horaDesde', message: 'Hora inicio (HH:mm):', validate: (i) => /^([01]\d|2[0-3]):([0-5]\d)$/.test(i.trim()) ? true : 'Use formato HH:mm' },
            { type: 'input', name: 'horaHasta', message: 'Hora fin (HH:mm):', validate: (i) => /^([01]\d|2[0-3]):([0-5]\d)$/.test(i.trim()) ? true : 'Use formato HH:mm' }
        ]);

        nuevosHorarios.push(slot);

        const { continuar } = await inquirer.prompt([
            { type: 'confirm', name: 'continuar', message: '¿Desea cargar otro horario para este médico?', default: false }
        ]);
        agregando = continuar;
    }

    const cuerpoPatch = {
        $push: {
            disponibilidad: { $each: nuevosHorarios }
        }
    };

    await invocarApi("PATCH", `/api/medicos/${id}`, cuerpoPatch);
}

async function modificarRecurso(nombreRecurso: string, rutaBase: string) {
    console.log(`\n--- Modificar ${nombreRecurso} (PATCH) ---`);
    
    const { id } = await inquirer.prompt([
        { type: 'input', name: 'id', message: `ID del ${nombreRecurso} a modificar:`, validate: (i) => i.trim() !== '' ? true : 'Obligatorio' }
    ]);

    console.log(`\x1b[36m(Deje el campo vacío y presione Enter si no desea modificarlo)\x1b[0m`);

    const camposActualizados: any = {};

    if (nombreRecurso === 'PACIENTES' || nombreRecurso === 'MEDICOS') {
        const respuestas = await inquirer.prompt([
            { type: 'input', name: 'nombre', message: 'Nuevo nombre:' },
            { type: 'input', name: 'apellido', message: 'Nuevo apellido:' },
            { type: 'input', name: 'telefono', message: 'Nuevo teléfono:' }
        ]);

        if (respuestas.nombre) camposActualizados.nombre = respuestas.nombre;
        if (respuestas.apellido) camposActualizados.apellido = respuestas.apellido;
        if (respuestas.telefono) camposActualizados.contacto = { telefono: respuestas.telefono };
    } else if (nombreRecurso === 'TURNOS') {
        const { estado } = await inquirer.prompt([
            {
                type: 'select',
                name: 'estado',
                message: 'Nuevo estado del turno:',
                choices: [
                    { name: 'Mantener actual', value: '' },
                    { name: 'Confirmado', value: 'confirmado' },
                    { name: 'Atendido', value: 'atendido' },
                    { name: 'Cancelado', value: 'cancelado' }
                ],
                loop: false
            }
        ]);
        
        if (estado !== '') camposActualizados.estado = estado;
    }

    if (Object.keys(camposActualizados).length > 0) {
        await invocarApi("PATCH", `${rutaBase}/${id}`, camposActualizados);
    } else {
        console.log("\x1b[33mNo se detectaron cambios. Operación cancelada.\x1b[0m");
    }
}

async function darDeBaja(nombreRecurso: string, rutaBase: string) {
    console.log(`\n--- Baja Lógica de ${nombreRecurso} (DELETE) ---`);
    
    const { id } = await inquirer.prompt([
        { type: 'input', name: 'id', message: `ID del ${nombreRecurso} a inactivar:`, validate: (i) => i.trim() !== '' ? true : 'Obligatorio' }
    ]);

    const { confirmar } = await inquirer.prompt([
        { type: 'confirm', name: 'confirmar', message: `¿Está seguro de inactivar el registro con ID ${id}?`, default: false }
    ]);

    if (confirmar) {
        await invocarApi("DELETE", `${rutaBase}/${id}`);
    } else {
        console.log("Operación cancelada.");
    }
}

async function menuRecurso(nombreRecurso: string, ruta: string) {
    let salir = false;
    
    while (!salir) {
        console.log(`\n--- Menú de ${nombreRecurso} ---`);
        
        const opciones = [
            { name: '1. Listar todos (GET)', value: 'LISTAR' },
            { name: '2. Consultar por ID (GET)', value: 'ID' },
            { name: '3. Crear nuevo (POST)', value: 'CREAR' },
            { name: '4. Modificar registro (PATCH)', value: 'MODIFICAR' }
        ];

        if (nombreRecurso === 'MEDICOS') {
            opciones.push({ name: '5. Cargar disponibilidad horaria (PATCH)', value: 'DISPONIBILIDAD' });
            opciones.push({ name: '6. Baja lógica (DELETE)', value: 'BAJA' });
            opciones.push(new inquirer.Separator() as any);
            opciones.push({ name: '7. Volver', value: 'VOLVER' });
        } else {
            opciones.push({ name: '5. Baja lógica (DELETE)', value: 'BAJA' });
            opciones.push(new inquirer.Separator() as any);
            opciones.push({ name: '6. Volver', value: 'VOLVER' });
        }

        const { accion } = await inquirer.prompt([
            {
                type: 'select',
                name: 'accion',
                message: 'Operación a realizar:',
                choices: opciones,
                loop: false // <-- Desactiva el carrusel en submenú
            }
        ]);

        switch (accion) {
            case 'LISTAR':
                await invocarApi("GET", ruta);
                break;
            case 'ID':
                const { id } = await inquirer.prompt([{ type: 'input', name: 'id', message: 'Ingrese ID:', validate: (i) => i.trim() !== '' ? true : 'Obligatorio' }]);
                await invocarApi("GET", `${ruta}/${id}`);
                break;
            case 'CREAR':
                if (nombreRecurso === 'PACIENTES') await crearPaciente();
                else if (nombreRecurso === 'MEDICOS') await crearMedico();
                else if (nombreRecurso === 'TURNOS') await crearTurno();
                break;
            case 'MODIFICAR':
                await modificarRecurso(nombreRecurso, ruta);
                break;
            case 'DISPONIBILIDAD':
                await cargarDisponibilidadMedico();
                break;
            case 'BAJA':
                await darDeBaja(nombreRecurso, ruta);
                break;
            case 'VOLVER':
                salir = true;
                break;
        }
    }
}

async function main() {
    try {
        const res = await fetch(`${BASE_URL}/api/pacientes`);
        if (!res.ok && res.status >= 500) throw new Error();
    } catch {
        console.log(`\x1b[31mNo hay conexión con la API en ${BASE_URL}.\x1b[0m`);
        console.log("\x1b[33mAsegúrese de que el servidor Express está ejecutándose.\x1b[0m");
        process.exit(1);
    }

    while (true) {
        console.clear();
        console.log("========================================");
        console.log("       SISTEMA DE TURNOS MEDICOS        ");
        console.log("========================================");

        const { opcionPrincipal } = await inquirer.prompt([
            {
                type: 'select',
                name: 'opcionPrincipal',
                message: 'Seleccione un módulo:',
                choices: [
                    { name: 'Gestionar Pacientes', value: 'PACIENTES' },
                    { name: 'Gestionar Médicos', value: 'MEDICOS' },
                    { name: 'Gestionar Turnos', value: 'TURNOS' },
                    new inquirer.Separator(),
                    { name: 'Salir', value: 'SALIR' }
                ],
                loop: false // <-- Desactiva el carrusel en menú principal
            }
        ]);

        if (opcionPrincipal === 'PACIENTES') {
            await menuRecurso("PACIENTES", "/api/pacientes");
        } else if (opcionPrincipal === 'MEDICOS') {
            await menuRecurso("MEDICOS", "/api/medicos");
        } else if (opcionPrincipal === 'TURNOS') {
            await menuRecurso("TURNOS", "/api/turnos");
        } else if (opcionPrincipal === 'SALIR') {
            console.log("Saliendo del sistema...");
            process.exit(0);
        }
    }
}

main();