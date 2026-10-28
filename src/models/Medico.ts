import mongoose, { Schema } from "mongoose";

const medicoSchema = new Schema(
  {
    nombre: {
      type: String,
      required: true,
      trim: true,
      match: [/^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$/, "El nombre debe contener solo letras y espacios"]
    },

    apellido: {
      type: String,
      required: true,
      trim: true,
      match: [/^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$/, "El apellido debe contener solo letras y espacios"]
    },

    matricula: {
      numero: {
        type: String,
        required: true,
        trim: true
      },

      tipo: {
        type: String,
        enum: ["nacional", "provincial"],
        required: true
      },

      jurisdiccion: {
        type: String
      }
    },

    especialidad: {
      type: String,
      required: true
    },

    disponibilidad: [
      {
        dia: { type: String, trim: true },
        horaDesde: { 
          type: String, 
          match: [/^([01]\d|2[0-3]):([0-5]\d)$/, "El formato debe ser HH:mm (ej. 09:30)"] 
        },
        horaHasta: { 
          type: String, 
          match: [/^([01]\d|2[0-3]):([0-5]\d)$/, "El formato debe ser HH:mm (ej. 13:00)"] 
        }
      }
    ],

    obrasSocialesAceptadas: [
      {
        type: String,
        trim: true
      }
    ],

    contacto: {
      telefono: {
        type: String,
        match: [/^[0-9\-+ ]+$/, "El teléfono solo admite números, guiones y el signo +"],
        trim: true
      },
      email: {
        type: String,
        match: [/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/, "Debe ser una dirección de email válida"],
        trim: true,
        lowercase: true
      }
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

export const Medico = mongoose.model(
  "Medico",
  medicoSchema
);