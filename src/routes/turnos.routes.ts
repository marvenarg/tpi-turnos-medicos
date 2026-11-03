import mongoose from "mongoose";
import { Router } from "express";

import { Turno } from "../models/Turno.js";
import { Paciente } from "../models/Paciente.js";
import { Medico } from "../models/Medico.js";

const router = Router();

// Create con Transacciones (ACID) y control de concurrencia
router.post("/", async (req, res) => {
  // 1. Iniciar la sesión y la transacción
  const session = await mongoose.startSession();
  session.startTransaction();

  try { // se agrega horaHasta para luego generar el turno con el horario completo para potenciales cancelaciones.
    const { pacienteId, medicoId, fechaHora, horaHasta, motivo } = req.body;

    // Verificar existencia del paciente 
    const paciente = await Paciente.findOne({
      _id: pacienteId,
      activo: true
    }).session(session);

    if (!paciente) {
      throw new Error("Paciente inexistente o inactivo");
    }

    // Extrae el día y la hora de la disponibilidad del médico para mostrarlo por consola de forma simple
    // se agrega validación de fecha para ambos tipos de datos: String y Date
    const fechaStr = typeof fechaHora === "string" ? fechaHora : new Date(fechaHora).toISOString();
    const [dia, restoHora] = fechaStr.split("T"); // corta el formato de fecha y hora
    const horaDesde = restoHora.substring(0, 5); // formatea la hora  "00:00"

    //  Busca al médico y remueve la disponibilidad de ese turno ($pull)
    // Si findOneAndUpdate retorna null, significa que el médico no existe o ese horario ya fue ocupado
    const medicoActualizado = await Medico.findOneAndUpdate(
      {
        _id: medicoId,
        activo: true,
        "disponibilidad.dia": dia,
        "disponibilidad.horaDesde": horaDesde
      },
      {
        $pull: { disponibilidad: { dia: dia, horaDesde: horaDesde } }
      },
      { session, new: true }
    );

    if (!medicoActualizado) {
      throw new Error("Médico no encontrado o el horario solicitado ya fue ocupado.");
    }

    //  Crear el turno (pasando el array y la opción { session })
    const [turno] = await Turno.create(
      [
        {
          pacienteId,
          medicoId,
          fechaHora,
          horaHasta,
          motivo
        }
      ],
      { session }
    );

    // Confirma la transacción
    await session.commitTransaction();
    res.status(201).json(turno);

  } catch (error: any) {
    // Si falla, se revierte todo 
    await session.abortTransaction();
    res.status(400).json({
      error: error.message || "No se pudo crear el turno"
    });
  } finally {
    
    session.endSession();
  }
});

// Read con populate() - Linking
router.get("/", async (_req, res) => {
  try {
  const turnos = await Turno.find({
    activo: true
  })
    .populate(
      "pacienteId",
      "nombre apellido dni"
    )
    .populate(
      "medicoId",
      "nombre apellido especialidad matricula"
    );

    res.json(turnos);
  } catch (error) {
    res.status(500).json({ error: "No se pudieron obtener los turnos" });
  }
});

// Busqueda por ID
router.get("/:id", async (req, res) => {
  try {
    const turno = await Turno.findOne({
      _id: req.params.id,
      activo: true
    });

    if (!turno) {
      return res.status(404).json({
        error: "Turno no encontrado"
      });
    }

    res.json(turno);
  } catch {
    res.status(400).json({
      error: "ID inválido"
    });
  }
});

// Update
router.patch("/:id", async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const turno = await Turno.findOne({ _id: req.params.id, activo: true }).session(session);

    if (!turno) {
      throw new Error("Turno no encontrado");
    }

    // Si el turno se cancela desde otro estado (no baja lógica), igual se devuelve la disponibilidad al médico
    if (req.body.estado === "cancelado" && turno.estado !== "cancelado") {
      const fechaStr = typeof turno.fechaHora === "string" ? turno.fechaHora : new Date(turno.fechaHora).toISOString();
      const [dia, restoHora] = fechaStr.split("T");
      const horaDesde = restoHora.substring(0, 5);
      const horaHasta = turno.horaHasta; // Recupera el valor guardado para la baja o cancelación.

      await Medico.findOneAndUpdate(
        { _id: turno.medicoId },
        { $push: { disponibilidad: { dia, horaDesde, horaHasta } } },
        { session, returnDocument: 'after' }
      );
    }

    // Fusiona los datos del body y guarda para ejecutar runValidators
    Object.assign(turno, req.body);
    await turno.save({ session }); 

    await session.commitTransaction();
    res.json(turno);
  } catch (error: any) {
    await session.abortTransaction();
    res.status(400).json({ error: error.message || "No se pudo actualizar el turno" });
  } finally {
    session.endSession();
  }
});

// Delete Lógico del turno y restitución de la disponibilidad del turno a la lista del médico.
router.delete("/:id", async (req, res) => {
  const session = await mongoose.startSession(); // se utiliza en lugar de findOneAndUpdate()
  session.startTransaction();

  try {
    const turno = await Turno.findOne({ _id: req.params.id, activo: true }).session(session);

    if (!turno) {
      throw new Error("Turno no encontrado");
    }
    // Se agrega validación de fecha para ambos formatos : String y Date
    const fechaStr = typeof turno.fechaHora === "string" ? turno.fechaHora : new Date(turno.fechaHora).toISOString();
    const [dia, restoHora] = fechaStr.split("T");
    const horaDesde = restoHora.substring(0, 5);
    const horaHasta = turno.horaHasta; // Recupera el valor guardado para la baja o cancelación.

    // Devuelve el horario completo al arreglo del médico ($push)
    await Medico.findOneAndUpdate(
      { _id: turno.medicoId },
      { $push: { disponibilidad: { dia, horaDesde, horaHasta } } },
      { session, returnDocument: 'after' }
    );

    // Ejecuta la baja lógica
    turno.activo = false;
    turno.fechaBaja = new Date();
    turno.estado = "cancelado";
    await turno.save({ session });

    await session.commitTransaction();
    res.json({
      mensaje: "Turno dado de baja y disponibilidad devuelta al profesional",
      turno
    });
  } catch (error: any) {
    await session.abortTransaction();
    res.status(400).json({ error: error.message || "No se pudo cancelar el turno" });
  } finally {
    session.endSession();
  }
});

export default router;





