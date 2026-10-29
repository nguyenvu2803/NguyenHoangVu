import { Router } from 'express';
import { z, id, parse } from './validation.js';
import { fail } from './security.js';

const cursor = z.string().regex(/^\d{1,19}$/).refine(value => BigInt(value) <= 9223372036854775807n);
const peerQuery = z.object({ peerId: id }).strict();
const historyQuery = peerQuery.extend({
  afterId: cursor.optional(), beforeId: cursor.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
}).refine(value => !(value.afterId && value.beforeId), { message: 'Choose one pagination direction.' });
const sendBody = z.object({ clientMessageId: id, recipientId: id,
  text: z.string().trim().min(1).max(2000), sourceLanguage: z.enum(['vi','en','zh']),
}).strict();
const pair = '((sender_id=$1 AND recipient_id=$2) OR (sender_id=$2 AND recipient_id=$1))';
const view = row => ({ id: String(row.id), clientMessageId: row.client_message_id,
  senderId: row.sender_id, recipientId: row.recipient_id, text: row.body,
  sourceLanguage: row.source_language, createdAt: row.created_at });
const unavailable = () => fail(404, 'CHAT_PEER_UNAVAILABLE', 'Người nhận chưa khả dụng trong phạm vi trò chuyện của bạn.');

export function createChat({ pool, now, pollMilliseconds = 1500 }) {
  const router = Router();
  const streams = new Set();
  async function peerFor(actor, peerId) {
    if (actor.id === peerId) unavailable();
    const { rows } = await pool.query("SELECT id,role,branch_id FROM users WHERE id=$1 AND status='active' AND email_verified=true AND deleted_at IS NULL", [peerId]);
    const peer = rows[0];
    if (!peer || (actor.role !== 'admin' && peer.role !== 'admin'
        && (!actor.branch_id || actor.branch_id !== peer.branch_id))) unavailable();
    return peer;
  }
  router.get('/chat/contacts', async (req, res) => {
    const fields = 'u.id,u.full_name,u.role,u.branch_id,b.name AS branch_name';
    const base = `SELECT ${fields} FROM users u LEFT JOIN branches b ON b.id=u.branch_id WHERE u.id<>$1 AND u.status='active' AND u.email_verified=true AND u.deleted_at IS NULL`;
    const { rows } = req.user.role === 'admin'
      ? await pool.query(`${base} ORDER BY u.full_name LIMIT 500`, [req.user.id])
      : await pool.query(`${base} AND (u.branch_id=$2 OR u.role='admin') ORDER BY u.full_name LIMIT 500`, [req.user.id, req.user.branch_id]);
    res.json({ data: rows.map(row => ({ id: row.id, fullName: row.full_name, role: row.role,
      branchId: row.branch_id, branchName: row.branch_name })) });
  });
  router.get('/chat/messages', async (req, res) => {
    const query = parse(historyQuery, req.query);
    await peerFor(req.user, query.peerId);
    const after = query.afterId !== undefined;
    const values = [req.user.id, query.peerId];
    let where = pair;
    if (after || query.beforeId !== undefined) {
      values.push(query.afterId ?? query.beforeId);
      where += ` AND id${after ? '>' : '<'}$3`;
    }
    values.push(query.limit + 1);
    const { rows } = await pool.query(`SELECT * FROM chat_messages WHERE ${where} ORDER BY id ${after ? 'ASC' : 'DESC'} LIMIT $${values.length}`, values);
    const hasMore = rows.length > query.limit;
    const messages = rows.slice(0, query.limit).map(view);
    if (!after) messages.reverse();
    res.json({ data: { messages, hasMore } });
  });
  router.post('/chat/messages', async (req, res) => {
    const input = parse(sendBody, req.body);
    await peerFor(req.user, input.recipientId);
    const existing = (await pool.query('SELECT * FROM chat_messages WHERE sender_id=$1 AND client_message_id=$2', [req.user.id, input.clientMessageId])).rows[0];
    // The client keeps this UUID after an ambiguous timeout, so a resend cannot duplicate a message.
    const inserted = existing ? { rows: [] } : await pool.query('INSERT INTO chat_messages(client_message_id,sender_id,recipient_id,body,source_language,created_at) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(sender_id,client_message_id) DO NOTHING RETURNING *',
      [input.clientMessageId, req.user.id, input.recipientId, input.text, input.sourceLanguage, now()]);
    const row = existing ?? inserted.rows[0] ?? (await pool.query('SELECT * FROM chat_messages WHERE sender_id=$1 AND client_message_id=$2', [req.user.id, input.clientMessageId])).rows[0];
    if (row.recipient_id !== input.recipientId || row.body !== input.text || row.source_language !== input.sourceLanguage) {
      fail(409, 'MESSAGE_ID_CONFLICT', 'Mã gửi đã dùng cho nội dung khác. Tạo tin nhắn mới trước khi gửi.');
    }
    res.status(inserted.rows.length ? 201 : 200).json({ data: view(row) });
  });
  router.get('/chat/stream', async (req, res) => {
    const { peerId } = parse(peerQuery, req.query);
    await peerFor(req.user, peerId);
    if (streams.size >= 200 || [...streams].filter(stream => stream.userId === req.user.id).length >= 5) {
      fail(429, 'CHAT_STREAM_LIMIT', 'Đang mở quá nhiều kết nối trò chuyện. Đóng màn hình khác rồi thử lại.');
    }
    res.set({ 'Content-Type': 'text/event-stream; charset=utf-8', 'Cache-Control': 'no-store',
      Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
    res.flushHeaders();
    let closed = false, timer, latest = null, heartbeatAt = now().getTime();
    const stream = { userId: req.user.id, close };
    streams.add(stream);
    function close() {
      if (closed) return;
      closed = true; clearTimeout(timer); streams.delete(stream); res.end();
    }
    function event(name, data) { res.write(`event: ${name}\ndata: ${JSON.stringify(data)}\n\n`); }
    res.on('close', close);
    res.write('retry: 2000\n\n');
    event('ready', { peerId });
    async function tick() {
      try {
        if (closed) return;
        if (now().getTime() >= req.tokenExpiresAt) { event('session_expired', {}); close(); return; }
        // Re-read identity and session while connected: revocation or branch changes must take effect.
        const active = (await pool.query("SELECT u.* FROM users u JOIN sessions s ON s.user_id=u.id WHERE u.id=$1 AND s.id=$2 AND s.revoked_at IS NULL AND u.deleted_at IS NULL AND u.status='active' AND u.email_verified=true", [req.user.id, req.sessionId])).rows[0];
        if (!active) { event('access_revoked', {}); close(); return; }
        await peerFor(active, peerId);
        // PostgreSQL is the event cursor, so reconnects and multiple API processes share one truth.
        const row = (await pool.query(`SELECT id FROM chat_messages WHERE ${pair} ORDER BY id DESC LIMIT 1`, [active.id, peerId])).rows[0];
        const next = row ? String(row.id) : '0';
        if (latest !== next) { latest = next; event('messages', { latestId: next }); }
        if (now().getTime() - heartbeatAt >= 15000) { res.write(': heartbeat\n\n'); heartbeatAt = now().getTime(); }
      } catch {
        if (!closed) { event('unavailable', {}); close(); }
      } finally {
        if (!closed) { timer = setTimeout(tick, pollMilliseconds); timer.unref?.(); }
      }
    }
    void tick();
  });
  return { router, stop() { for (const stream of [...streams]) stream.close(); } };
}
