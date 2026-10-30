import { Router } from "express";
import { Medico } from "../models/Medico.js";

const router = Router();

router.post("/", async (req, res) => {
  try {
    const medico = await Medico.create(req.body);
    res.status(201).json(medico);
  } catch {
    res.status(400).json({
      error: "No se pudo crear el médico"
    });
  }
});

router.get("/", async (_req, res) => {
  const medicos = await Medico.find({
    activo: true
  });

  res.json(medicos);
});

// Busqueda por ID
router.get("/:id", async (req, res) => {
  try {
    const medico = await Medico.findOne({
      _id: req.params.id,
      activo: true
    });

    if (!medico) {
      return res.status(404).json({
        error: "Médico no encontrado"
      });
    }

    res.json(medico);
  } catch {
    res.status(400).json({
      error: "ID inválido"
    });
  }
});

router.patch("/:id", async (req, res) => {
  try {
    const medico = await Medico.findOneAndUpdate(
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

    if (!medico) {
      return res.status(404).json({
        error: "Médico no encontrado"
      });
    }

    res.json(medico);

  } catch (error: any) {
    res.status(400).json({
      error: error.message
    });
  }
});

router.delete("/:id", async (req, res) => {
  const medico = await Medico.findOneAndUpdate(
    {
      _id: req.params.id,
      activo: true
    },
    {
      activo: false,
      fechaBaja: new Date()
    },
    {
      new: true
    }
  );

  if (!medico) {
    return res.status(404).json({
      error: "Médico no encontrado"
    });
  }

  res.json({
    mensaje: "Médico dado de baja"
  });
});

export default router;