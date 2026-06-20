const mongoose = require('mongoose');

const uri = "mongodb://jd-carenest-new-cosmos:alKyh2qav7cGLTW4ENCzMn6DIpp5MLAi1HP8ruOSGj0ZDDoWevAreNh9LClWxn9tDuWyh5U2wZG3ACDbDfW0rQ==@jd-carenest-new-cosmos.mongo.cosmos.azure.com:10255/carenest?ssl=true&retryWrites=false";

async function test() {
  try {
    console.log("Connecting...");
    await mongoose.connect(uri);
    console.log("Connected!");

    const AppointmentSchema = new mongoose.Schema({ patientId: String }, { strict: false });
    const Appointment = mongoose.model('Appointment', AppointmentSchema);

    console.log("Finding...");
    const docs = await Appointment.find({});
    console.log("Found:", docs.length);
  } catch (err) {
    console.error("Error:", err);
  } finally {
    mongoose.disconnect();
  }
}

test();
