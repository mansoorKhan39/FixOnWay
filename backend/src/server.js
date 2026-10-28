const config = require('./config');
const { connect } = require('./db');
const { createApp } = require('./app');

async function main() {
  await connect();
  console.log('MongoDB connected.');
  createApp().listen(config.port, () => {
    console.log(`FixOnWay API running on http://localhost:${config.port}`);
  });
}

main().catch((err) => {
  console.error('Could not start the server:', err.message);
  process.exit(1);
});
