const { HttpError } = require('../utils/httpError');

const notFound = (_req, res) => res.status(404).json({ error: 'Route not found.' });

// eslint-disable-next-line no-unused-vars
const errorHandler = (err, _req, res, _next) => {
  if (err instanceof HttpError) {
    return res.status(err.status).json({ error: err.message });
  }
  if (err && err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'The request body is not valid JSON.' });
  }
  if (err && err.type === 'entity.too.large') {
    return res.status(413).json({ error: 'The request is too large.' });
  }
  if (err && err.code === 11000) {
    return res.status(409).json({ error: 'This record already exists.' });
  }
  if (err && err.name === 'ValidationError') {
    return res.status(400).json({ error: err.message });
  }
  console.error(err);
  return res.status(500).json({ error: 'Something went wrong on the server.' });
};

module.exports = { notFound, errorHandler };
