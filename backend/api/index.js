// Vercel serverless entry point. Locally you still use `npm start`.
const mongoose = require('mongoose');
const { connect } = require('../src/db');
const { createApp } = require('../src/app');

let app;
let connecting;

async function ensureDb() {
  if (mongoose.connection.readyState === 1) return;
  if (!connecting) {
    connecting = connect().finally(() => {
      connecting = null;
    });
  }
  await connecting;
}

module.exports = async (req, res) => {
  try {
    if (!String(req.url).startsWith('/api/health')) await ensureDb();
    app = app || createApp();
    return app(req, res);
  } catch (err) {
    console.error('Startup error:', err);
    res.statusCode = 500;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ error: 'Database connection failed. Check MONGODB_URI and Atlas Network Access.' }));
  }
};