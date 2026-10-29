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

  try {
    const { pacienteId, medicoId, fechaHora, motivo } = req.body;

    // Verificar existencia del paciente 
    const paciente = await Paciente.findOne({
      _id: pacienteId,
      activo: true
    }).session(session);

    if (!paciente) {
      throw new Error("Paciente inexistente o inactivo");
    }

    // Extrae el día y la hora de la disponibilidad del médico para mostrarlo por consola de forma simple
    const [dia, restoHora] = fechaHora.split("T"); // corta el formato de fecha y hora
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
        error: "Paciente no encontrado"
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
  const turno = await Turno.findOneAndUpdate(
    {
      _id: req.params.id,
      activo: true
    },
    req.body,
    {
      new: true,
      runValidators: true
    }
  );

  if (!turno) {
    return res.status(404).json({
      error: "Turno no encontrado"
    });
  }

  res.json(turno);
});

// Delete Lógico
router.delete("/:id", async (req, res) => {
  const turno = await Turno.findOneAndUpdate(
    {
      _id: req.params.id,
      activo: true
    },
    {
      activo: false,
      fechaBaja: new Date(),
      estado: "cancelado"
    },
    {
      new: true
    }
  );

  if (!turno) {
    return res.status(404).json({
      error: "Turno no encontrado"
    });
  }

  res.json({
    mensaje: "Turno dado de baja",
    turno
  });
});

export default router;





