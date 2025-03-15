const mongoose = require("mongoose");

// Define Schema for Each Stage Event
const StageSchema = new mongoose.Schema({
  stageName: { type: String, required: true },  // E.g., Security Gate, Interactive Bay
  role: { type: String, required: true },       // Who performed the scan (Security, Technician, etc.)
  eventType: { type: String, required: true },  // Entry, Exit, etc.
  timestamp: { type: Date, default: Date.now },
  inKM: { type: Number, default: null },        // ✅ Only for Security Entry
  outKM: { type: Number, default: null },       // ✅ Only for Security Exit
  inDriver: { type: String, default: null },    // ✅ Only for Security Entry
  outDriver: { type: String, default: null },   // ✅ Only for Security Exit
});

// Define Vehicle Schema (Tracks Full Journey)
const VehicleSchema = new mongoose.Schema({
  vehicleNumber: { type: String, required: true },
  entryTime: { type: Date, required: true },
  exitTime: { type: Date, default: null },
  stages: [StageSchema],  // ✅ Stores all stage events in order
});

const Vehicle = mongoose.model("Vehicle", VehicleSchema);

module.exports = Vehicle;