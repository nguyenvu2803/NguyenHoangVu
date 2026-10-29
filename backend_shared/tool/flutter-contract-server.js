// Isolated integration fixture. Never used by npm start or a deployed service.
import { randomUUID } from 'node:crypto';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { newDb } from 'pg-mem';
import sharp from 'sharp';
import { createApp } from '../src/app.js';
import { hashPassword } from '../src/security.js';

if (process.env.NODE_ENV !== 'test' || !process.env.NHV_TEST_DIRECTORY) {
  throw new Error('Only the isolated integration test runner may start this fixture.');
}
const directory = process.env.NHV_TEST_DIRECTORY;
const db = newDb();
db.public.registerFunction({ name: 'length', args: ['text'], returns: 'integer', implementation: value => value.length });
const migrations = new URL('../migrations/', import.meta.url);
for (const file of (await readdir(migrations)).filter(file => /^\d+_.*\.sql$/.test(file)).sort()) {
  db.public.none(await readFile(new URL(file, migrations), 'utf8'));
}
const adapter = db.adapters.createPg();
const pool = new adapter.Pool();
const mailbox = [];
const mailboxFile = join(directory, 'mailbox.json');
await writeFile(mailboxFile, '[]', { mode: 0o600 });
await pool.query('INSERT INTO users(id,full_name,username,email,password_hash,role,status,email_verified) VALUES($1,$2,$3,$4,$5,$6,$7,$8)',
  [randomUUID(), 'Contract Admin', 'contract_admin', 'admin@example.test', await hashPassword('Contract-test-password-29'), 'admin', 'active', true]);
const faceFile = join(directory, 'face.jpg');
await sharp(await readFile(new URL('../src/face/fixtures/opencv-sface-demo.jpg', import.meta.url)))
  .extract({ left: 215, top: 30, width: 215, height: 265 }).jpeg({ quality: 95 }).toFile(faceFile);
const app = createApp({ pool, config: {
  jwtSecret: 'isolated-contract-jwt-secret-32-characters',
  otpSecret: 'isolated-contract-otp-secret-32-characters',
  issuer: 'attendance-api', audience: 'attendance-app', timeZone: 'Asia/Ho_Chi_Minh',
}, mailer: { async sendOtp(message) {
  mailbox.push(message);
  await writeFile(mailboxFile, JSON.stringify(mailbox), { mode: 0o600 });
} } });
const server = app.listen(0, '127.0.0.1', () => {
  console.log(JSON.stringify({ endpoint: `http://127.0.0.1:${server.address().port}/v1`, mailboxFile, faceFile }));
});
process.on('SIGTERM', () => {
  app.locals.chat.stop();
  server.close(async () => { await pool.end(); process.exit(0); });
});
