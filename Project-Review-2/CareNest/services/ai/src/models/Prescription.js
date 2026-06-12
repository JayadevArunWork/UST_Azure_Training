const mongoose = require('mongoose');

const prescriptionSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  appointmentId: { type: String, required: true },
  patientId: { type: String, required: true },
  doctorId: { type: String, required: true },
  medications: [{
    name: String,
    dosage: String,
    frequency: String
  }],
  notes: { type: String }
}, { collection: 'prescriptions', strict: false });

module.exports = mongoose.model('Prescription', prescriptionSchema);
