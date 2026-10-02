import express from 'express';
import helmet from 'helmet';
import client from 'prom-client';

export function buildApp() {
  const app = express();
  // Cabeceras de seguridad (CSP, nosniff, CORP, sin X-Powered-By); helmet no cubre Permissions-Policy
  app.use(helmet());
  app.use((_req, res, next) => {
    res.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
    next();
  });
  const register = new client.Registry();
  client.collectDefaultMetrics({ register });

  const httpRequests = new client.Counter({
    name: 'http_requests_total',
    help: 'Total de requests HTTP',
    labelNames: ['method', 'route', 'status'],
    registers: [register],
  });
  const httpDuration = new client.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duración de requests HTTP en segundos',
    labelNames: ['method', 'route', 'status'],
    buckets: [0.005, 0.01, 0.05, 0.1, 0.5, 1, 2],
    registers: [register],
  });

  app.use((req, res, next) => {
    const end = httpDuration.startTimer();
    res.on('finish', () => {
      const labels = { method: req.method, route: req.route?.path ?? req.path, status: res.statusCode };
      httpRequests.inc(labels);
      end(labels);
    });
    next();
  });

  app.get('/', (_req, res) => {
    res.json({ service: 'pipeline-devops-app', version: process.env.APP_VERSION ?? 'dev', hostname: process.env.HOSTNAME ?? 'local' });
  });

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));
  app.get('/ready', (_req, res) => res.json({ status: 'ready' }));

  // Endpoint que consume CPU, para provocar el HPA en las pruebas
  app.get('/work', (req, res) => {
    const n = Math.min(Number(req.query.n ?? 200000), 5_000_000);
    let acc = 0;
    for (let i = 0; i < n; i++) acc += Math.sqrt(i);
    res.json({ iterations: n, result: Math.round(acc) });
  });

  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  return app;
}
