// Full flow against a real MongoDB. Skipped unless MONGODB_TEST_URI is set,
// e.g.  MONGODB_TEST_URI=mongodb://127.0.0.1:27017/fixonway_test npm test
// WARNING: it empties that database first.
const test = require('node:test');
const assert = require('node:assert/strict');

const uri = process.env.MONGODB_TEST_URI;

test('API with a real database', { skip: !uri && 'set MONGODB_TEST_URI to run' }, async (t) => {
  const { connect, disconnect } = require('../src/db');
  const { createApp } = require('../src/app');
  const { seed } = require('../src/seed');

  await connect(uri);
  await seed();
  const server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  t.after(async () => {
    server.close();
    await disconnect();
  });

  const call = async (method, path, body, token) => {
    const res = await fetch(base + path, {
      method,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    return { status: res.status, json: text ? JSON.parse(text) : null };
  };
  const login = async (identifier, password) => {
    const r = await call('POST', '/api/auth/login', { identifier, password });
    assert.equal(r.status, 200, JSON.stringify(r.json));
    return r.json;
  };

  const ali = await login('ali.raza@example.pk', 'Pass@1234');
  const byPhone = await login('0300 1234567', 'Pass@1234');
  assert.equal(byPhone.user.id, ali.user.id);
  const usman = await login('usman@example.pk', 'Pass@1234');
  const sara = await login('sara.khan@fixonway.pk', 'Admin@1234');

  await t.test('wrong password and blocked account', async () => {
    assert.equal((await call('POST', '/api/auth/login', { identifier: 'ali.raza@example.pk', password: 'x' })).status, 401);
    assert.equal((await call('POST', '/api/auth/login', { identifier: 'blocked@example.pk', password: 'Pass@1234' })).status, 403);
  });

  await t.test('register, duplicates and session restore', async () => {
    const body = { role: 'customer', name: 'Test User', phone: '0345 9998887', email: 'test.user@example.pk', password: 'Abcdef@12' };
    const created = await call('POST', '/api/auth/register', body);
    assert.equal(created.status, 201);
    assert.equal(created.json.user.phone, '+923459998887');
    assert.equal((await call('POST', '/api/auth/register', body)).status, 409);
    const me = await call('GET', '/api/auth/me', undefined, created.json.token);
    assert.equal(me.json.user.email, 'test.user@example.pk');
    const exists = await call('POST', '/api/auth/exists', { phone: '03459998887', email: 'nobody@example.pk' });
    assert.deepEqual(exists.json, { phoneExists: true, emailExists: false });
  });

  await t.test('customer sees only their own requests and vehicles', async () => {
    const mine = await call('GET', `/api/requests?customerId=${ali.user.id}`, undefined, ali.token);
    assert.equal(mine.status, 200);
    assert.ok(mine.json.length >= 2);
    const hira = await login('hira@example.pk', 'Pass@1234');
    const hers = await call('GET', '/api/requests', undefined, hira.token);
    assert.equal(hers.json.length, 0);
    assert.equal((await call('GET', `/api/vehicles?ownerId=${ali.user.id}`, undefined, hira.token)).status, 403);
  });

  await t.test('request flow: create, estimate, update', async () => {
    const created = await call('POST', '/api/requests', {
      customerId: ali.user.id, customerName: 'Ali Raza', vehicleId: 'seed_v1', vehicleTitle: 'Suzuki Cultus',
      vehicleType: 'car', problem: 'flatTire', description: '', location: { lat: 33.68, lng: 73.04 }, address: 'F-10',
      photos: [], status: 'pending', createdAt: Date.now(), updatedAt: Date.now(), rejectedBy: [],
    }, ali.token);
    assert.equal(created.status, 201);
    const rid = created.json.id;
    const forged = await call('POST', '/api/requests', { customerId: 'someone-else' }, ali.token);
    assert.equal(forged.status, 403);

    const est = await call('POST', '/api/estimates', {
      requestId: rid, mechanicId: usman.user.id, mechanicName: 'Usman Ghani', amount: 1000, etaMinutes: 10,
      note: '', createdAt: Date.now(), expiresAt: Date.now() + 600000, status: 'offered',
    }, usman.token);
    assert.equal(est.status, 201);
    const list = await call('GET', `/api/estimates?requestId=${rid}`, undefined, ali.token);
    assert.equal(list.json.length, 1);
    const asCustomer = await call('POST', '/api/estimates', { requestId: rid, mechanicId: ali.user.id }, ali.token);
    assert.equal(asCustomer.status, 403);

    const upd = await call('PUT', `/api/requests/${rid}`, { ...created.json, status: 'estimated' }, usman.token);
    assert.equal(upd.status, 200);
    const got = await call('GET', `/api/requests/${rid}`, undefined, ali.token);
    assert.equal(got.json.status, 'estimated');
    assert.equal((await call('GET', '/api/requests/nope', undefined, ali.token)).status, 404);
  });

  await t.test('chat is limited to the people of the job', async () => {
    const hira = await login('hira@example.pk', 'Pass@1234');
    assert.equal((await call('GET', '/api/messages?requestId=seed_r1', undefined, hira.token)).status, 403);
    const sent = await call('POST', '/api/messages', {
      requestId: 'seed_r1', senderId: ali.user.id, senderName: 'Ali', text: 'hello', sentAt: Date.now(),
    }, ali.token);
    assert.equal(sent.status, 201);
    const spoof = await call('POST', '/api/messages', {
      requestId: 'seed_r1', senderId: usman.user.id, senderName: 'x', text: 'fake', sentAt: Date.now(),
    }, ali.token);
    assert.equal(spoof.status, 403);
    const list = await call('GET', '/api/messages?requestId=seed_r1', undefined, usman.token);
    assert.equal(list.json.length, 1);
  });

  await t.test('admin-only areas', async () => {
    assert.equal((await call('GET', '/api/users', undefined, ali.token)).status, 403);
    assert.equal((await call('GET', '/api/audit', undefined, ali.token)).status, 403);
    const users = await call('GET', '/api/users', undefined, sara.token);
    assert.equal(users.status, 200);
    assert.ok(users.json.length >= 10);
    assert.equal(users.json.find((u) => u.email === 'ali.raza@example.pk').passwordHash, undefined);
    const hira = users.json.find((u) => u.email === 'hira@example.pk');
    const blocked = await call('PATCH', `/api/users/${hira.id}/status`, { status: 'blocked' }, sara.token);
    assert.equal(blocked.json.user.status, 'blocked');
    const hiraToken = (await call('POST', '/api/auth/login', { identifier: 'hira@example.pk', password: 'Pass@1234' }));
    assert.equal(hiraToken.status, 403);
    await call('PATCH', `/api/users/${hira.id}/status`, { status: 'active' }, sara.token);
    const log = await call('POST', '/api/audit', { adminId: sara.user.id, adminName: 'Sara', action: 'test', targetId: 'x', createdAt: Date.now(), note: '' }, sara.token);
    assert.equal(log.status, 201);
    assert.ok((await call('GET', '/api/audit?limit=5', undefined, sara.token)).json.length >= 1);
  });

  await t.test('file upload: photo is public, document is private', async () => {
    const png = Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex');
    const send = (kind, token, bytes = png, type = 'image/png') =>
      fetch(`${base}/api/files?kind=${kind}`, {
        method: 'POST',
        headers: { 'Content-Type': type, 'X-File-Name': encodeURIComponent('cnic front.png'), Authorization: `Bearer ${token}` },
        body: bytes,
      });
    const doc = await (await send('document', usman.token)).json();
    assert.ok(doc.id);
    const photo = await (await send('photo', ali.token)).json();
    assert.equal((await fetch(`${base}/api/files/${photo.id}`)).status, 200);
    assert.equal((await fetch(`${base}/api/files/${doc.id}`)).status, 401);
    assert.equal((await fetch(`${base}/api/files/${doc.id}?token=${usman.token}`)).status, 200);
    assert.equal((await fetch(`${base}/api/files/${doc.id}?token=${sara.token}`)).status, 200);
    assert.equal((await fetch(`${base}/api/files/${doc.id}?token=${ali.token}`)).status, 403);
    assert.equal((await send('document', usman.token, Buffer.from('MZ-not-an-image-at-all'))).status, 400);
  });

  await t.test('mongo operators in a query are refused', async () => {
    const r = await call('GET', '/api/requests?customerId[$ne]=x', undefined, sara.token);
    assert.equal(r.status, 400);
    const b = await call('POST', '/api/vehicles', { ownerId: ali.user.id, $where: '1' }, ali.token);
    assert.equal(b.status, 400);
  });

  await t.test('login lock after 5 wrong passwords', async () => {
    for (let i = 0; i < 5; i += 1) {
      await call('POST', '/api/auth/login', { identifier: 'kashif@example.pk', password: 'wrong' });
    }
    const locked = await call('POST', '/api/auth/login', { identifier: 'kashif@example.pk', password: 'Pass@1234' });
    assert.equal(locked.status, 429);
  });
});
