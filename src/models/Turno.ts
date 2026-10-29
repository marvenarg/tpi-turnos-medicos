import mongoose, { Schema } from "mongoose";

const turnoSchema = new Schema(
  {
    pacienteId: {
      type: Schema.Types.ObjectId,
      ref: "Paciente",
      required: true
    },

    medicoId: {
      type: Schema.Types.ObjectId,
      ref: "Medico",
      required: true
    },

    fechaHora: {
      type: String, 
      required: true,
      trim: true,
      match: [/^\d{4}-\d{2}-\d{2}T([01]\d|2[0-3]):([0-5]\d):00$/, "Formato inválido. Use YYYY-MM-DDTHH:mm:00"]
    },

    motivo: {
      type: String
    },

    estado: {
      type: String,
      enum: [
        "pendiente",
        "confirmado",
        "atendido",
        "cancelado"
      ],
      default: "pendiente"
    },

    observaciones: {
      type: String
    },

    activo: {
      type: Boolean,
      default: true
    },

    fechaBaja: {
      type: Date,
      default: null
    }
  },
  {
    timestamps: true
  }
);

export const Turno = mongoose.model(
  "Turno",
  turnoSchema
);