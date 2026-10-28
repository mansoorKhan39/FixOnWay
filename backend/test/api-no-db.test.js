// Checks that need no database: routing, login protection, validation.
const test = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../src/app');

let server;
let base;

test.before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => server.close());

const call = async (method, path, body, token) => {
  const res = await fetch(base + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, json: text ? JSON.parse(text) : null };
};

test('health check', async () => {
  const r = await call('GET', '/api/health');
  assert.equal(r.status, 200);
  assert.equal(r.json.ok, true);
});

test('unknown route is a 404 with a message', async () => {
  const r = await call('GET', '/api/nothing-here');
  assert.equal(r.status, 404);
  assert.ok(r.json.error);
});

test('data routes need a login', async () => {
  for (const path of ['/api/requests', '/api/vehicles', '/api/mechanics', '/api/audit', '/api/users']) {
    const r = await call('GET', path);
    assert.equal(r.status, 401, path);
  }
});

test('a bad token is refused', async () => {
  const r = await call('GET', '/api/requests', undefined, 'not.a.token');
  assert.equal(r.status, 401);
});

test('register validates before touching the database', async () => {
  const good = { role: 'customer', name: 'Ali', phone: '0300 1234567', email: 'a@b.pk', password: 'Abcdef@1' };
  assert.equal((await call('POST', '/api/auth/register', { ...good, role: 'admin' })).status, 403);
  assert.equal((await call('POST', '/api/auth/register', { ...good, role: 'boss' })).status, 400);
  assert.equal((await call('POST', '/api/auth/register', { ...good, phone: '123' })).status, 400);
  assert.equal((await call('POST', '/api/auth/register', { ...good, email: 'nope' })).status, 400);
  const short = await call('POST', '/api/auth/register', { ...good, password: 'Abc@1' });
  assert.equal(short.status, 400);
  assert.match(short.json.error, /at least 8/);
});

test('login needs both fields', async () => {
  const r = await call('POST', '/api/auth/login', { identifier: '', password: '' });
  assert.equal(r.status, 400);
});

test('broken JSON is a clean 400', async () => {
  const res = await fetch(`${base}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{oops',
  });
  assert.equal(res.status, 400);
});
