const express = require('express');
const bcrypt = require('bcryptjs');
const rateLimit = require('express-rate-limit');
const config = require('../config');
const { User } = require('../models');
const { signToken, requireAuth } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');
const { HttpError } = require('../utils/httpError');
const { normalizePhone, isEmail, publicUser } = require('../utils/helpers');

const router = express.Router();

const text = (v) => (typeof v === 'string' ? v : '');

const resetLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many attempts. Please wait a few minutes.' },
});

function checkPassword(password) {
  if (text(password).length < config.minPasswordLength) {
    throw new HttpError(
      400,
      `Password must be at least ${config.minPasswordLength} characters.`,
    );
  }
}

const hash = (password) => bcrypt.hash(password, 10);

// UC-01 helper: is this phone / email already used?
router.post(
  '/exists',
  asyncHandler(async (req, res) => {
    const phone = normalizePhone(req.body.phone);
    const email = text(req.body.email).trim().toLowerCase();
    const [phoneUser, emailUser] = await Promise.all([
      phone ? User.exists({ phone }) : null,
      email ? User.exists({ email }) : null,
    ]);
    res.json({ phoneExists: Boolean(phoneUser), emailExists: Boolean(emailUser) });
  }),
);

// UC-01 Register
router.post(
  '/register',
  asyncHandler(async (req, res) => {
    const { role } = req.body;
    if (role === 'admin') {
      throw new HttpError(403, 'Admin accounts cannot be created in the app.');
    }
    if (role !== 'customer' && role !== 'mechanic') throw new HttpError(400, 'Choose a role.');
    const name = text(req.body.name).trim();
    const phone = normalizePhone(req.body.phone);
    const email = text(req.body.email).trim().toLowerCase();
    if (name.length < 2) throw new HttpError(400, 'Enter your name.');
    if (!phone) throw new HttpError(400, 'Enter a valid mobile number, e.g. 0300 1234567');
    if (!isEmail(email)) throw new HttpError(400, 'Enter a valid email address');
    checkPassword(req.body.password);

    const [phoneUsed, emailUsed] = await Promise.all([
      User.exists({ phone }),
      User.exists({ email }),
    ]);
    if (phoneUsed) throw new HttpError(409, 'An account with this phone number already exists.');
    if (emailUsed) throw new HttpError(409, 'An account with this email already exists.');

    const user = await User.create({
      role,
      name,
      phone,
      email,
      passwordHash: await hash(req.body.password),
      verificationStatus: role === 'mechanic' ? 'pending' : undefined,
    });
    res.status(201).json({ token: signToken(user), user: publicUser(user.toObject()) });
  }),
);

// UC-02 Login (phone or email)
router.post(
  '/login',
  asyncHandler(async (req, res) => {
    const identifier = text(req.body.identifier).trim();
    const password = text(req.body.password);
    if (!identifier || !password) {
      throw new HttpError(400, 'Enter your phone or email and your password.');
    }
    const user = identifier.includes('@')
      ? await User.findOne({ email: identifier.toLowerCase() })
      : await User.findOne({ phone: normalizePhone(identifier) || '-' });
    if (!user) throw new HttpError(401, 'Invalid email or password.');

    const now = Date.now();
    if (user.lockedUntil && user.lockedUntil.getTime() > now) {
      const minutes = Math.ceil((user.lockedUntil.getTime() - now) / 60000);
      throw new HttpError(429, `Too many failed attempts. Try again in ${minutes} minute(s).`);
    }
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      user.failedLogins = (user.failedLogins || 0) + 1;
      if (user.failedLogins >= config.maxLoginAttempts) {
        user.failedLogins = 0;
        user.lockedUntil = new Date(now + config.lockMinutes * 60000);
      }
      await user.save();
      throw new HttpError(401, 'Invalid email or password.');
    }
    if (user.status === 'blocked') throw new HttpError(403, 'Your account is suspended.');
    user.failedLogins = 0;
    user.lockedUntil = undefined;
    await user.save();
    res.json({ token: signToken(user), user: publicUser(user.toObject()) });
  }),
);

// Restore the session after the app restarts
router.get(
  '/me',
  requireAuth,
  (req, res) => res.json({ user: publicUser(req.user) }),
);

// UC-04 Reset password. Demo shortcut: the phone number alone is accepted
// (the real OTP step was removed). Do not use this as-is in production.
router.post(
  '/reset-password',
  resetLimiter,
  asyncHandler(async (req, res) => {
    const phone = normalizePhone(req.body.phone);
    checkPassword(req.body.newPassword);
    const user = phone ? await User.findOne({ phone }) : null;
    if (!user) throw new HttpError(404, 'No account found for this number.');
    user.passwordHash = await hash(req.body.newPassword);
    user.failedLogins = 0;
    user.lockedUntil = undefined;
    await user.save();
    res.json({ message: 'Your password was changed. Log in with the new password.' });
  }),
);

// UC-42 Change my password
router.post(
  '/change-password',
  requireAuth,
  asyncHandler(async (req, res) => {
    const current = text(req.body.currentPassword);
    const next = text(req.body.newPassword);
    checkPassword(next);
    if (next === current) {
      throw new HttpError(400, 'New password must be different from the old one.');
    }
    const user = await User.findById(req.user._id);
    if (!(await bcrypt.compare(current, user.passwordHash))) {
      throw new HttpError(400, 'Your current password is incorrect.');
    }
    user.passwordHash = await hash(next);
    await user.save();
    res.json({ ok: true });
  }),
);

// UC-05 / UC-42 Edit my name and email
router.put(
  '/profile',
  requireAuth,
  asyncHandler(async (req, res) => {
    const name = text(req.body.name).trim();
    const email = text(req.body.email).trim().toLowerCase();
    if (name.length < 2) throw new HttpError(400, 'Enter your name.');
    if (!isEmail(email)) throw new HttpError(400, 'Enter a valid email address');
    const used = await User.exists({ email, _id: { $ne: req.user._id } });
    if (used) throw new HttpError(409, 'This email is used by another account.');
    const user = await User.findByIdAndUpdate(
      req.user._id,
      { name, email },
      { new: true },
    ).lean();
    res.json({ user: publicUser(user) });
  }),
);

module.exports = router;
