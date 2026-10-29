import test, { beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import { readFile, readdir } from 'node:fs/promises';
import request from 'supertest';
import { newDb } from 'pg-mem';
import { createApp } from '../src/app.js';

let pool, app, mail, clock, serial, server;
const password = 'Only-a-chat-test-password';
const auth = user => ({ Authorization: `Bearer ${user.accessToken}` });
beforeEach(async () => {
  const db = newDb();
  db.public.registerFunction({ name: 'length', args: ['text'], returns: 'integer', implementation: value => value.length });
  const folder = new URL('../migrations/', import.meta.url);
  for (const file of (await readdir(folder)).filter(file => /^\d+_.*\.sql$/.test(file)).sort()) db.public.none(await readFile(new URL(file, folder), 'utf8'));
  const adapter = db.adapters.createPg(); pool = new adapter.Pool();
  mail = []; clock = Date.now(); serial = 0;
  app = createApp({ pool, now: () => new Date(clock), config: {
    jwtSecret: 'chat-test-jwt-secret-with-32-characters', otpSecret: 'chat-test-otp-secret-with-32-characters',
    chatPollMilliseconds: 20,
  }, mailer: { async sendOtp(message) { mail.push(message); } } });
});
afterEach(async () => {
  app.locals.chat.stop();
  if (server) { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); server = null; }
  await pool.end();
});
async function user({ role = 'employee', status = 'active', branchId = null } = {}) {
  const n = ++serial;
  const challenge = await request(app).post('/v1/auth/register').send({ username: `chatuser${n}`, fullName: `Chat User ${n}`, email: `chat${n}@example.test`, password });
  assert.equal(challenge.status, 202);
  const verified = await request(app).post('/v1/auth/verify-otp').send({ challengeId: challenge.body.data.challengeId, code: mail.at(-1).code });
  assert.equal(verified.status, 200);
  await pool.query('UPDATE users SET role=$1,status=$2,branch_id=$3 WHERE id=$4', [role, status, branchId, verified.body.data.user.id]);
  return { ...verified.body.data.user, ...verified.body.data, id: verified.body.data.user.id };
}
async function office(admin, name) {
  const result = await request(app).post('/v1/branches').set(auth(admin)).send({ name, address: 'Chat test address', latitude: 10, longitude: 106, radiusMeters: 100 });
  assert.equal(result.status, 201); return result.body.data;
}
async function team() {
  const admin = await user({ role: 'admin' });
  const branch = await office(admin, 'Chat Office');
  const sender = await user({ branchId: branch.id });
  const receiver = await user({ role: 'manager', branchId: branch.id });
  return { admin, sender, receiver, branch };
}
const message = (recipient, extra = {}) => ({ clientMessageId: randomUUID(), recipientId: recipient.id, text: 'Xin chào', sourceLanguage: 'vi', ...extra });
const send = (sender, payload) => request(app).post('/v1/chat/messages').set(auth(sender)).send(payload);
const history = (actor, peer, query = {}) => request(app).get('/v1/chat/messages').set(auth(actor)).query({ peerId: peer.id, ...query });

test('contacts expose eligible names, not emails, and respect branch/admin scope', async () => {
  const { admin, sender, receiver } = await team();
  const otherBranch = await office(admin, 'Other Office');
  const outsider = await user({ branchId: otherBranch.id });
  const pending = await user({ status: 'pending', branchId: otherBranch.id });
  const contacts = await request(app).get('/v1/chat/contacts').set(auth(sender));
  assert.equal(contacts.status, 200);
  assert.deepEqual(new Set(contacts.body.data.map(row => row.id)), new Set([admin.id, receiver.id]));
  assert.ok(contacts.body.data.every(row => !('email' in row)));
  assert.equal((await request(app).get('/v1/chat/contacts').set(auth(pending))).status, 403);
  const all = await request(app).get('/v1/chat/contacts').set(auth(admin));
  assert.ok(all.body.data.some(row => row.id === outsider.id));
  assert.ok(!all.body.data.some(row => row.id === pending.id));
});
test('two participants read both directions; another admin cannot read their private conversation', async () => {
  const { admin, sender, receiver } = await team();
  assert.equal((await send(sender, message(receiver))).status, 201);
  assert.equal((await send(receiver, message(sender, { text: 'Hello', sourceLanguage: 'en' }))).status, 201);
  const rows = (await history(sender, receiver)).body.data.messages;
  assert.deepEqual(rows.map(row => row.text), ['Xin chào', 'Hello']);
  assert.ok(rows.every(row => typeof row.id === 'string'));
  assert.deepEqual((await history(receiver, sender)).body.data.messages, rows);
  assert.deepEqual((await history(admin, sender)).body.data.messages, []);
});
test('cross-branch, self, pending and forged sender requests cannot create messages', async () => {
  const { admin, sender, receiver } = await team();
  const branch = await office(admin, 'Other Branch');
  const outsider = await user({ branchId: branch.id });
  const pending = await user({ status: 'pending', branchId: branch.id });
  for (const peer of [outsider, sender, pending]) assert.equal((await send(sender, message(peer))).status, 404);
  assert.equal((await send(sender, message(receiver, { senderId: admin.id }))).status, 422);
  assert.equal((await send(sender, message(receiver, { text: ' '.repeat(4) }))).status, 422);
  assert.equal((await send(sender, message(receiver, { text: 'x'.repeat(2001) }))).status, 422);
  assert.equal((await send(sender, message(receiver, { sourceLanguage: 'unknown' }))).status, 422);
});
test('idempotent resend preserves one message and rejects UUID reuse for changed content', async () => {
  const { sender, receiver } = await team();
  const payload = message(receiver);
  const first = await send(sender, payload), again = await send(sender, payload);
  assert.equal(first.status, 201); assert.equal(again.status, 200);
  assert.deepEqual(first.body, again.body);
  const conflict = await send(sender, { ...payload, text: 'Different message' });
  assert.equal(conflict.status, 409); assert.equal(conflict.body.error.code, 'MESSAGE_ID_CONFLICT');
  assert.equal((await history(sender, receiver)).body.data.messages.length, 1);
});
test('history pages newest, older and reconnect cursors without missing or duplicating messages', async () => {
  const { sender, receiver } = await team();
  for (let i = 0; i < 5; i++) await send(sender, message(receiver, { text: `Message ${i}` }));
  const recent = (await history(sender, receiver, { limit: 2 })).body.data;
  assert.deepEqual(recent.messages.map(row => row.text), ['Message 3', 'Message 4']); assert.equal(recent.hasMore, true);
  const older = (await history(sender, receiver, { limit: 2, beforeId: recent.messages[0].id })).body.data;
  assert.deepEqual(older.messages.map(row => row.text), ['Message 1', 'Message 2']);
  const after = (await history(sender, receiver, { afterId: older.messages[1].id, limit: 2 })).body.data;
  assert.deepEqual(after.messages, recent.messages);
  assert.equal((await history(sender, receiver, { beforeId: '1', afterId: '2' })).status, 422);
  assert.equal((await history(sender, receiver, { afterId: '9223372036854775808' })).status, 422);
});

async function stream(actor, peer) {
  server = app.listen(0, '127.0.0.1'); await once(server, 'listening');
  const controller = new AbortController();
  const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/chat/stream?peerId=${peer.id}`, { headers: auth(actor), signal: controller.signal });
  assert.equal(response.status, 200); assert.match(response.headers.get('content-type'), /text\/event-stream/);
  const reader = response.body.getReader(), decoder = new TextDecoder();
  let buffer = '';
  return { close: () => controller.abort(), async next(name, predicate = () => true) {
    const timeout = AbortSignal.timeout(4000);
    while (!timeout.aborted) {
      const boundary = buffer.indexOf('\n\n');
      if (boundary >= 0) {
        const event = buffer.slice(0, boundary); buffer = buffer.slice(boundary + 2);
        const type = /^event: (.+)$/m.exec(event)?.[1], json = /^data: (.+)$/m.exec(event)?.[1];
        if (type === name && json) { const data = JSON.parse(json); if (predicate(data)) return data; }
        continue;
      }
      const result = await Promise.race([reader.read(), new Promise((_, reject) => timeout.addEventListener('abort', () => reject(new Error('SSE event timed out')), { once: true }))]);
      if (result.done) throw new Error('SSE closed before expected event');
      buffer += decoder.decode(result.value, { stream: true });
    }
    throw new Error('SSE timed out');
  } };
}
test('authenticated SSE notifies the receiver after an actual second-client send', async () => {
  const { sender, receiver } = await team();
  const events = await stream(receiver, sender);
  try {
    await events.next('ready'); await events.next('messages', row => row.latestId === '0');
    const sent = await send(sender, message(receiver)); assert.equal(sent.status, 201);
    const event = await events.next('messages', row => row.latestId === sent.body.data.id);
    assert.deepEqual(Object.keys(event), ['latestId']);
    assert.equal((await history(receiver, sender)).body.data.messages[0].text, 'Xin chào');
  } finally { events.close(); }
});
test('an open SSE stream closes after logout revokes its session', async () => {
  const { sender, receiver } = await team();
  const events = await stream(receiver, sender);
  try {
    await events.next('ready');
    await request(app).post('/v1/auth/logout').send({ refreshToken: receiver.refreshToken });
    await events.next('access_revoked');
  } finally { events.close(); }
});
test('an open SSE stream closes at access-token expiry rather than keeping stale authorization', async () => {
  const { sender, receiver } = await team(); const events = await stream(receiver, sender);
  try { await events.next('ready'); clock += 16 * 60000; await events.next('session_expired'); }
  finally { events.close(); }
});
test('branch changes remove an open stream without sending another message notification', async () => {
  const { admin, sender, receiver } = await team(); const events = await stream(receiver, sender);
  try {
    await events.next('ready'); await events.next('messages');
    const branch = await office(admin, 'Moved Office');
    await pool.query('UPDATE users SET branch_id=$1 WHERE id=$2', [branch.id, receiver.id]);
    await events.next('unavailable');
  } finally { events.close(); }
});
