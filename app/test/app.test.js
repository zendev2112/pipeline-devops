import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/app.js';

async function withServer(fn) {
  const server = buildApp().listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  try { await fn(base); } finally { server.close(); }
}

test('GET / devuelve info del servicio', () => withServer(async (base) => {
  const res = await fetch(`${base}/`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.service, 'pipeline-devops-app');
}));

test('GET /health devuelve ok', () => withServer(async (base) => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: 'ok' });
}));

test('GET /metrics expone métricas Prometheus', () => withServer(async (base) => {
  await fetch(`${base}/health`);
  const res = await fetch(`${base}/metrics`);
  assert.equal(res.status, 200);
  const text = await res.text();
  assert.match(text, /http_requests_total/);
  assert.match(text, /process_cpu_seconds_total/);
}));

test('GET /work limita las iteraciones', () => withServer(async (base) => {
  const res = await fetch(`${base}/work?n=99999999`);
  const body = await res.json();
  assert.equal(body.iterations, 5_000_000);
}));

test('las respuestas llevan cabeceras de seguridad', () => withServer(async (base) => {
  const res = await fetch(`${base}/`);
  assert.equal(res.headers.get('x-powered-by'), null);
  assert.equal(res.headers.get('x-content-type-options'), 'nosniff');
  assert.match(res.headers.get('content-security-policy'), /default-src 'self'/);
  assert.ok(res.headers.get('permissions-policy'));
}));
