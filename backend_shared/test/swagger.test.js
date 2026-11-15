import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { createAuth } from '../src/auth.js';
import { createResources } from '../src/resources.js';
import { createNotifications } from '../src/notifications.js';
import { createChat } from '../src/chat.js';
import { openapi } from '../src/openapi.js';

const config = { jwtSecret: 'test-only-jwt-secret-with-at-least-32-characters',
  otpSecret: 'test-only-otp-secret-with-at-least-32-characters' };
const pool = { query: async () => ({ rows: [] }) };
const mailer = { sendOtp: async () => { throw new Error('Docs must not send email'); } };
const now = () => new Date();
const create = () => createApp({ pool, config, mailer, now });

test('Swagger is public; API authentication remains enforced', async () => {
  const app = create();
  for (const path of ['/', '/v1', '/v1/', '/swagger', '/swagger-ui', '/v1/docs', '/docs']) {
    await request(app).get(path).expect(302).expect('Location', '/docs/');
  }
  await request(app).get('/docs/').expect(200).expect('Content-Type', /html/);
  const init = await request(app).get('/docs/init.js').expect(200).expect('Content-Type', /javascript/);
  assert.match(init.text, /persistAuthorization: false/);
  assert.match(init.text, /validatorUrl: null/);
  for (const name of ['swagger-ui.css', 'swagger-ui-bundle.js']) await request(app).get(`/docs/assets/${name}`).expect(200);
  for (const path of ['/openapi.json', '/docs/openapi.json']) {
    const { body } = await request(app).get(path).expect(200);
    assert.equal(body.openapi, '3.1.0');
    assert.equal(body.servers[0].url, '/v1');
    assert.deepEqual(body.security, [{ bearerAuth: [] }]);
    assert.deepEqual(body.paths['/health'].get.security, []);
    assert.deepEqual(body.paths['/auth/verify-otp'].post.security, []);
    assert.equal(body.paths['/me'].get.security, undefined);
  }
  await request(app).get('/v1/health').expect(200);
  await request(app).get('/v1/me').expect(401);
  await request(app).get('/v1/employees').expect(401);
  await request(app).post('/v1/auth/login').send({}).expect(422);
});

test('OpenAPI covers every implemented business route and every reference resolves', () => {
  const actual = new Set(['get /health', 'get /me']);
  const opts = { pool, config, mailer, now };
  for (const [prefix, router] of [
    ['/auth', createAuth(opts).router], ['', createResources(opts)],
    ['', createNotifications(opts).router], ['', createChat(opts).router],
  ]) for (const layer of router.stack) {
    if (!layer.route) continue;
    const path = (prefix + layer.route.path).replace(/:([a-zA-Z]+)/g, '{$1}');
    for (const method of Object.keys(layer.route.methods)) actual.add(`${method} ${path}`);
  }
  const documented = new Set(), ids = new Set();
  for (const [path, methods] of Object.entries(openapi.paths)) for (const [method, op] of Object.entries(methods)) {
    documented.add(`${method} ${path}`);
    assert.ok(!ids.has(op.operationId), op.operationId);
    ids.add(op.operationId);
    for (const name of path.matchAll(/\{([^}]+)\}/g)) {
      assert.ok(op.parameters?.some(p => p.in === 'path' && p.required && p.name === name[1]), path);
    }
  }
  assert.deepEqual([...documented].sort(), [...actual].sort());
  function walk(value) {
    if (!value || typeof value !== 'object') return;
    if (value.$ref) {
      assert.ok(value.$ref.startsWith('#/'));
      assert.ok(value.$ref.slice(2).split('/').reduce((node, key) => node?.[key], openapi), value.$ref);
    }
    for (const item of Object.values(value)) walk(item);
  }
  walk(openapi);
});

test('Swagger assets are installed locally; no external validator or token persistence', async () => {
  const { swaggerHtml } = await import('../src/swagger.js');
  assert.ok(!swaggerHtml.includes('https://'));
  const lock = JSON.parse(await readFile(new URL('../package-lock.json', import.meta.url)));
  assert.ok(lock.packages['node_modules/swagger-ui-dist'].integrity);
  const schemas = openapi.components.schemas;
  assert.ok(!schemas.ShiftPatch.properties.status);
  assert.equal(schemas.Punch.properties.accuracyMeters.maximum, 100);
  assert.equal(schemas.Branch.properties.radiusMeters.maximum, 5000);
  assert.equal(schemas.VerifyOtp.properties.code.pattern, '^\\d{6}$');
});
