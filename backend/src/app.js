const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const config = require('./config');
const { notFound, errorHandler } = require('./middleware/error');

function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(cors({ origin: config.corsOrigin === '*' ? true : config.corsOrigin.split(',') }));
  app.use(express.json({ limit: '200kb' }));

  app.get('/api/health', (_req, res) => res.json({ ok: true, name: 'FixOnWay API' }));
  app.use('/api/auth', require('./routes/auth'));
  app.use('/api/users', require('./routes/users'));
  app.use('/api/files', require('./routes/files'));
  app.use('/api', require('./routes/data'));

  app.use(notFound);
  app.use(errorHandler);
  return app;
}

module.exports = { createApp };
