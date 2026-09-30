import { buildApp } from './app.js';

const port = Number(process.env.PORT ?? 3000);
const server = buildApp().listen(port, () => {
  console.log(JSON.stringify({ msg: 'server started', port, version: process.env.APP_VERSION ?? 'dev' }));
});

for (const sig of ['SIGTERM', 'SIGINT']) {
  process.on(sig, () => {
    console.log(JSON.stringify({ msg: 'shutting down', signal: sig }));
    server.close(() => process.exit(0));
  });
}
