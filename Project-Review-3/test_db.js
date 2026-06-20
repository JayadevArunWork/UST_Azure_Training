const mongoose = require('mongoose');

const uri = process.env.MONGO_URI.includes('?') 
  ? process.env.MONGO_URI + '&retryWrites=false' 
  : process.env.MONGO_URI + '?retryWrites=false';

mongoose.connect(uri)
  .then(async () => {
    console.log('Connected to MongoDB');
    try {
      const Appointment = require('./src/models/Appointment');
      console.log('Querying appointments...');
      
      const docs = await Promise.race([
        Appointment.find({}),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Query timed out!')), 10000))
      ]);
      
      console.log(`Found ${docs.length} appointments`);
    } catch (err) {
      console.error('Error during query:', err.message);
    }
    process.exit(0);
  })
  .catch(err => {
    console.error('Connection error:', err);
    process.exit(1);
  });
