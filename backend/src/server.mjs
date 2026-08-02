import app from './app.mjs';
import { port } from './config.mjs';

const server = app.listen(port, '127.0.0.1', () => {
  console.log(`G06 backend listening on http://localhost:${port}`);
});

const shutdown = (signal) => {
  console.log(`${signal} received; closing HTTP server.`);
  server.close(() => process.exit(0));
};

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
