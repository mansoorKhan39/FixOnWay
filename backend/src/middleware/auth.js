const jwt = require('jsonwebtoken');
const config = require('../config');
const { User } = require('../models');
const { HttpError } = require('../utils/httpError');
const asyncHandler = require('../utils/asyncHandler');

const signToken = (user) =>
  jwt.sign({ uid: String(user._id) }, config.jwtSecret, { expiresIn: config.jwtExpiresIn });

/** Token text -> user from the database (a blocked account is refused at once). */
async function userFromToken(token) {
  if (!token) throw new HttpError(401, 'Please log in.');
  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret);
  } catch (_) {
    throw new HttpError(401, 'Your session has expired. Please log in again.');
  }
  const user = await User.findById(payload.uid).lean();
  if (!user) throw new HttpError(401, 'Your session has expired. Please log in again.');
  if (user.status === 'blocked') throw new HttpError(403, 'Your account is suspended.');
  return user;
}

const bearer = (req) => {
  const header = req.headers.authorization || '';
  return header.startsWith('Bearer ') ? header.slice(7) : null;
};

/** Reads "Authorization: Bearer <token>" and sets req.user. */
const requireAuth = asyncHandler(async (req, _res, next) => {
  req.user = await userFromToken(bearer(req));
  next();
});

const requireRole = (...roles) => (req, _res, next) => {
  if (!roles.includes(req.user.role)) {
    return next(new HttpError(403, 'You are not allowed to do this.'));
  }
  return next();
};

module.exports = { signToken, requireAuth, requireRole, userFromToken, bearer };
