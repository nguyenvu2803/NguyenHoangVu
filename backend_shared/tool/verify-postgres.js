import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import pg from 'pg';
import request from 'supertest';
import sharp from 'sharp';
import { applyMigrations } from '../src/migrate.js';
import { bootstrapAdmin } from '../src/bootstrap-admin.js';
import { createApp } from '../src/app.js';

// Dedicated test DB only. Each run owns a fresh schema and deletes only that schema.
const address = new URL(process.env.TEST_DATABASE_URL ?? 'postgres://missing/invalid');
if (!/_(qa|test)$/.test(address.pathname.slice(1)) || process.env.NODE_ENV !== 'test') {
  throw new Error('Set NODE_ENV=test and TEST_DATABASE_URL to a dedicated database ending in _qa or _test.');
}
const schema = `qa_${randomBytes(10).toString('hex')}`;
const ssl = process.env.TEST_DATABASE_SSL === 'true' ? { rejectUnauthorized: true } : false;
const control = new pg.Pool({ connectionString: address.href, ssl });
const options = { connectionString: address.href, ssl, options: `-c search_path=${schema}`, max: 6 };
let pool, app, server;
let timestamp = Date.now();
let checked = 0;
const mail = [];
const secret = () => randomBytes(32).toString('base64url');
const password = secret();
const auth = actor => ({ Authorization: `Bearer ${actor.accessToken}` });
async function step(label, run) { await run(); console.log(`PASS ${++checked}: ${label}`); }
async function call(method, path, actor, body, expected = 200) {
  let req = request(app)[method](`/v1${path}`);
  if (actor) req = req.set(auth(actor));
  if (body !== undefined) req = req.send(body);
  const response = await req;
  assert.equal(response.status, expected, `${method} ${path}: ${response.body.error?.code ?? 'unexpected status'}`);
  return response.body.data;
}
async function register(username) {
  const challenge = await call('post', '/auth/register', null,
    { username, fullName: `QA ${username}`, email: `${username}@example.test`, password }, 202);
  return call('post', '/auth/verify-otp', null, { challengeId: challenge.challengeId, code: mail.at(-1).code });
}
try {
  await control.query(`CREATE SCHEMA ${schema}`);
  pool = new pg.Pool(options);
  await step('Six PostgreSQL migrations apply and rerun without changes', async () => {
    await applyMigrations(pool);
    await applyMigrations(pool);
    assert.equal(Number((await pool.query('SELECT COUNT(*) FROM schema_migrations')).rows[0].count), 6);
  });
  app = createApp({ pool, config: { jwtSecret: secret(), otpSecret: secret(), timeZone: 'Asia/Ho_Chi_Minh', chatPollMilliseconds: 50 },
    now: () => new Date(timestamp), mailer: { async sendOtp(value) { mail.push(value); } } });
  let admin, manager, employee, office, duty, attendance;
  await step('Bootstrap admin, password and OTP issue a real JWT', async () => {
    await bootstrapAdmin(pool, { fullName: 'QA Admin', username: 'qa_admin', email: 'qa_admin@example.test', password });
    const challenge = await call('post', '/auth/login', null, { username: 'qa_admin', password });
    admin = await call('post', '/auth/verify-otp', null, { challengeId: challenge.challengeId, code: mail.at(-1).code });
    assert.equal((await call('get', '/me', admin)).role, 'admin');
  });
  await step('Public Swagger loads; private routes reject missing tokens', async () => {
    await request(app).get('/v1').expect(302).expect('Location', '/docs/');
    await request(app).get('/docs/').expect(200);
    await call('get', '/me', null, undefined, 401);
  });
  await step('Branch CRUD persists in PostgreSQL', async () => {
    office = await call('post', '/branches', admin, { name: 'QA branch', address: 'QA test address',
      latitude: 10.7769, longitude: 106.7009, radiusMeters: 200 }, 201);
    const unused = await call('post', '/branches', admin, { name: 'QA unused', address: 'QA temporary address',
      latitude: 10, longitude: 106, radiusMeters: 100 }, 201);
    await call('patch', `/branches/${unused.id}`, admin, { name: 'QA changed' });
    assert.equal((await call('get', `/branches/${unused.id}`, admin)).name, 'QA changed');
    await call('delete', `/branches/${unused.id}`, admin);
  });
  await step('Registration, activation and three-role scope work', async () => {
    employee = await register('qa_employee');
    manager = await register('qa_manager');
    await call('patch', `/employees/${employee.user.id}`, admin, { status: 'active', branchId: office.id });
    await call('patch', `/employees/${manager.user.id}`, admin, { status: 'active', role: 'manager', branchId: office.id });
    assert.equal((await call('get', '/employees', employee)).length, 1);
    assert.equal((await call('get', '/me', manager)).role, 'manager');
    await call('post', '/branches', employee, { name: 'Forbidden' }, 403);
    await call('post', '/employees', manager, {}, 403);
    const user = await call('post', '/employees', admin, { fullName: 'QA Disposable', username: 'qa_unused', email: 'qa_unused@example.test', password }, 201);
    await call('patch', `/employees/${user.id}`, admin, { fullName: 'QA Changed' });
    await call('delete', `/employees/${user.id}`, admin);
  });
  const shift = () => ({ title: 'QA shift', employeeId: employee.user.id, branchId: office.id,
    startsAt: new Date(timestamp - 600000).toISOString(), endsAt: new Date(timestamp + 3600000).toISOString() });
  await step('Manager can CRUD shifts in own branch', async () => {
    const unused = await call('post', '/shifts', manager, shift(), 201);
    await call('patch', `/shifts/${unused.id}`, manager, { title: 'QA updated shift' });
    await call('delete', `/shifts/${unused.id}`, manager);
    duty = await call('post', '/shifts', manager, shift(), 201);
  });
  await step('GPS boundary rejects outside; row locking prevents concurrent duplicate punches', async () => {
    await call('post', '/attendance/check-in', employee, { shiftId: duty.id, latitude: 0, longitude: 0, accuracyMeters: 5 }, 422);
    const body = { shiftId: duty.id, latitude: 10.7769, longitude: 106.7009, accuracyMeters: 5 };
    const results = await Promise.all([request(app).post('/v1/attendance/check-in').set(auth(employee)).send(body),
      request(app).post('/v1/attendance/check-in').set(auth(employee)).send(body)]);
    assert.deepEqual(results.map(r => r.status).sort(), [201, 409]);
    attendance = results.find(r => r.status === 201).body.data;
    timestamp += 60000;
    await call('post', '/attendance/check-out', employee, body);
    await call('delete', `/shifts/${duty.id}`, manager, undefined, 409);
  });
  await step('Correction cannot self-approve; manager decision preserves recorded times', async () => {
    const correction = await call('post', '/corrections', employee, { shiftId: duty.id,
      requestedCheckIn: new Date(new Date(attendance.checkInAt).getTime() - 60000).toISOString(), reason: 'QA correction test' }, 201);
    await call('patch', `/corrections/${correction.id}`, employee, { status: 'approved' }, 403);
    await call('patch', `/corrections/${correction.id}`, manager, { status: 'approved', resolutionNote: 'QA reviewed' });
    const row = (await call('get', '/attendance', employee))[0];
    assert.equal(row.source, 'correction');
    assert.equal(row.recordedCheckInAt, attendance.recordedCheckInAt);
  });
  await step('Location sharing has scope and can be stopped', async () => {
    const location = await call('post', '/location-shares', employee, { latitude: 10.7769, longitude: 106.7009,
      accuracyMeters: 5, ttlMinutes: 15 }, 201);
    assert.equal((await call('get', '/location-shares', manager)).length, 1);
    await call('delete', `/location-shares/${location.id}`, employee);
    assert.equal((await call('get', '/location-shares', manager)).length, 0);
  });
  await step('UUID chat is idempotent and SSE reads PostgreSQL cursor', async () => {
    const body = { clientMessageId: randomUUID(), recipientId: manager.user.id, text: 'Please check my shift', sourceLanguage: 'en' };
    const message = await call('post', '/chat/messages', employee, body, 201);
    assert.equal((await call('post', '/chat/messages', employee, body)).id, message.id);
    assert.equal((await call('get', `/chat/messages?peerId=${employee.user.id}`, manager)).messages.length, 1);
    server = app.listen(0, '127.0.0.1');
    await new Promise(resolve => server.once('listening', resolve));
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), 10000);
    try {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/chat/stream?peerId=${manager.user.id}`,
        { headers: auth(employee), signal: abort.signal });
      assert.equal(response.status, 200);
      const reader = response.body.getReader();
      let text = '';
      while (!text.includes(`"latestId":"${message.id}"`)) {
        const chunk = await reader.read();
        assert.ok(!chunk.done);
        text += new TextDecoder().decode(chunk.value);
      }
      assert.ok(text.includes('event: ready'));
      await reader.cancel();
    } finally { clearTimeout(timer); abort.abort(); app.locals.chat.stop(); }
  });
  await step('Real face models enroll and unlock without sending OTP; deleting template revokes session', async () => {
    const fixture = await readFile(new URL('../src/face/fixtures/opencv-sface-demo.jpg', import.meta.url));
    const photo = async rect => (await sharp(fixture).extract(rect).jpeg({ quality: 95 }).toBuffer()).toString('base64');
    const enrollment = await call('post', '/face/enroll', employee, { enableQuickLogin: true,
      imageBase64: await photo({ left: 215, top: 30, width: 215, height: 265 }) }, 201);
    const count = mail.length;
    const session = await call('post', '/auth/face-unlock', null, { username: employee.user.username,
      deviceKey: enrollment.deviceKey, imageBase64: await photo({ left: 891, top: 143, width: 100, height: 120 }) });
    assert.equal(mail.length, count);
    await call('get', '/me', session);
    await call('delete', '/face/enroll', employee);
    await call('get', '/me', session, undefined, 401);
  });
  await step('Profile survives reconnect and monthly report queries PostgreSQL', async () => {
    await call('patch', '/me', employee, { fullName: 'QA Persisted Profile', bio: 'QA profile' });
    const check = new pg.Pool(options);
    try { assert.equal((await check.query('SELECT full_name FROM users WHERE id=$1', [employee.user.id])).rows[0].full_name, 'QA Persisted Profile'); }
    finally { await check.end(); }
    const month = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit' }).format(new Date(timestamp));
    await call('get', `/reports/monthly?month=${month}`, manager);
  });
  await step('Refresh token reuse revokes session', async () => {
    const next = await call('post', '/auth/refresh', null, { refreshToken: employee.refreshToken });
    await call('post', '/auth/refresh', null, { refreshToken: employee.refreshToken }, 401);
    await call('get', '/me', next, undefined, 401);
  });
  console.log(`PostgreSQL integration: ${checked} checks passed. Test mailbox, sample faces and GPS payloads; not production email/camera/GPS proof.`);
} finally {
  app?.locals.chat.stop();
  if (server) await new Promise(resolve => server.close(resolve));
  await pool?.end();
  await control.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
  await control.end();
}
