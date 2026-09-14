const mongoose = require('mongoose');
const dns = require('dns');

// Configure reliable DNS servers to prevent querySrv ECONNREFUSED on local ISPs
try {
  dns.setServers(['8.8.8.8', '1.1.1.1', '8.8.4.4']);
} catch (e) {
  // Ignore if in environments where setServers is restricted
}

const connectDB = async () => {
  const uri = process.env.MONGODB_URI;

  if (!uri || uri.includes('<username>') || uri.includes('<password>')) {
    console.warn('\n=============================================================');
    console.warn('⚠️  MONGODB ATLAS CONFIGURATION NOTICE:');
    console.warn('Please update the MONGODB_URI in your .env file with your real');
    console.warn('MongoDB Atlas credentials and cluster link.');
    console.warn('Format: mongodb+srv://<username>:<password>@cluster0.xxx.mongodb.net/rfid_attendance');
    console.warn('=============================================================\n');
    return false;
  }

  try {
    const conn = await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 8000,
    });
    console.log(`✅ MongoDB Atlas Connected: ${conn.connection.host}`);
    return true;
  } catch (error) {
    console.error(`❌ MongoDB Atlas Connection Error: ${error.message}`);
    console.error('Tips:');
    console.error(' 1. Check your database username and password in .env');
    console.error(' 2. Ensure your IP address is whitelisted in MongoDB Atlas (Network Access -> Add IP Address -> Allow Access From Anywhere 0.0.0.0/0)');
    console.error(' 3. Verify your cluster URL is correct.');
    return false;
  }
};

module.exports = connectDB;
