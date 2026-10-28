const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizePhone, isEmail, assertSafe, out, publicUser } = require('../src/utils/helpers');

test('normalizePhone accepts the usual Pakistani formats', () => {
  assert.equal(normalizePhone('0300 1234567'), '+923001234567');
  assert.equal(normalizePhone('+92 300 1234567'), '+923001234567');
  assert.equal(normalizePhone('923001234567'), '+923001234567');
  assert.equal(normalizePhone('0300-1234567'), '+923001234567');
});

test('normalizePhone refuses bad numbers', () => {
  assert.equal(normalizePhone('12345'), null);
  assert.equal(normalizePhone('0200 1234567'), null);
  assert.equal(normalizePhone(''), null);
  assert.equal(normalizePhone(undefined), null);
});

test('isEmail', () => {
  assert.ok(isEmail('ali.raza@example.pk'));
  assert.ok(!isEmail('ali.raza'));
  assert.ok(!isEmail(''));
  assert.ok(!isEmail(42));
});

test('assertSafe refuses Mongo operators and dotted keys', () => {
  assert.doesNotThrow(() => assertSafe({ a: 1, b: { c: [1, 2, { d: 'x' }] } }));
  assert.throws(() => assertSafe({ $set: { a: 1 } }), /not allowed/);
  assert.throws(() => assertSafe({ a: { $ne: null } }), /not allowed/);
  assert.throws(() => assertSafe({ list: [{ 'a.b': 1 }] }), /not allowed/);
});

test('out renames _id to id and drops __v', () => {
  assert.deepEqual(out({ _id: 'x1', name: 'A', __v: 0 }), { id: 'x1', name: 'A' });
});

test('publicUser never exposes the password hash', () => {
  const user = publicUser({
    _id: 'u1', role: 'customer', name: 'Ali', phone: '+923001234567',
    email: 'a@b.pk', passwordHash: 'secret', failedLogins: 2,
  });
  assert.equal(user.passwordHash, undefined);
  assert.equal(user.failedLogins, undefined);
  assert.equal(user.status, 'active');
  assert.equal(user.verificationStatus, undefined);
});
