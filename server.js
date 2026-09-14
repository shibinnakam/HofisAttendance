require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const connectDB = require('./config/db');

const userRoutes = require('./routes/userRoutes');
const attendanceRoutes = require('./routes/attendanceRoutes');

const app = express();
const PORT = process.env.PORT || 5000;

const { scheduleNightUpdate, checkStartupCatchup } = require('./services/nightUpdateService');

// Connect to MongoDB Atlas
connectDB().then((connected) => {
  if (connected) {
    checkStartupCatchup();
  }
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

// Static files for Dashboard UI
app.use(express.static(path.join(__dirname, 'public')));

// Database connection check middleware
const mongoose = require('mongoose');
const checkDbConnection = (req, res, next) => {
  if (req.path === '/stats') {
    return next();
  }
  if (mongoose.connection.readyState !== 1) {
    return res.status(503).json({
      success: false,
      message: 'MongoDB Atlas is not connected yet. Please configure your MONGODB_URI in the .env file with your MongoDB Atlas connection string.',
      connectionStatus: 'disconnected',
    });
  }
  next();
};

// API Routes
app.use('/api', userRoutes);
app.use('/api/attendance', checkDbConnection, attendanceRoutes);

// Health check endpoint
app.get('/api/health', (req, res) => {
  const mongoose = require('mongoose');
  res.json({
    status: 'online',
    timestamp: new Date().toISOString(),
    database: {
      status: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
      readyState: mongoose.connection.readyState,
    },
  });
});

// 404 Handler for undefined API routes
app.use('/api/*', (req, res) => {
  res.status(404).json({
    success: false,
    message: `Endpoint ${req.originalUrl} not found`,
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error',
  });
});

// Schedule automatic daily attendance update and reset at 11:59 PM every night
scheduleNightUpdate();

// Start Server
app.listen(PORT, () => {
  console.log(`\n======================================================`);
  console.log(`🚀 RFID Attendance Server running at http://localhost:${PORT}`);
  console.log(`📊 Web Dashboard available at:       http://localhost:${PORT}`);
  console.log(`📡 API Endpoints base:              http://localhost:${PORT}/api`);
  console.log(`======================================================\n`);
});
