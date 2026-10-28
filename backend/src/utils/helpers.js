const mongoose = require('mongoose');
const { HttpError } = require('./httpError');

const newId = () => new mongoose.Types.ObjectId().toString();

/** Turns 0300 1234567, +92 300 1234567 or 923001234567 into +923001234567. */
function normalizePhone(input) {
  const cleaned = String(input || '').replace(/[\s\-()]/g, '');
  const match = /^(?:\+92|92|0)(3\d{9})$/.exec(cleaned);
  return match ? `+92${match[1]}` : null;
}

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const isEmail = (value) => typeof value === 'string' && EMAIL.test(value.trim());

/** Mongo operators in user input ($ne, $gt ...) can change a query. Refuse them. */
function assertSafe(value, path = 'body') {
  if (Array.isArray(value)) {
    value.forEach((v, i) => assertSafe(v, `${path}[${i}]`));
  } else if (value && typeof value === 'object') {
    for (const [key, inner] of Object.entries(value)) {
      if (key.startsWith('$') || key.includes('.')) {
        throw new HttpError(400, `Field name "${key}" is not allowed.`);
      }
      assertSafe(inner, `${path}.${key}`);
    }
  }
}

/** Document from the database -> the JSON the app reads ({ id, ...fields }). */
function out(doc) {
  if (!doc) return doc;
  const { _id, __v, ...rest } = doc;
  return { id: String(_id), ...rest };
}

/** The user JSON the app reads (never includes the password hash). */
function publicUser(u) {
  const user = {
    id: String(u._id),
    role: u.role,
    name: u.name,
    phone: u.phone,
    email: u.email,
    status: u.status || 'active',
  };
  if (u.verificationStatus) user.verificationStatus = u.verificationStatus;
  return user;
}

module.exports = { newId, normalizePhone, isEmail, assertSafe, out, publicUser };
