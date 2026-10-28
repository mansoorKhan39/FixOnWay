const express = require('express');
const { User } = require('../models');
const { requireAuth, requireRole } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');
const { HttpError } = require('../utils/httpError');
const { publicUser } = require('../utils/helpers');

const router = express.Router();
router.use(requireAuth, requireRole('admin'));

// UC-36 every account
router.get(
  '/',
  asyncHandler(async (_req, res) => {
    const users = await User.find().sort({ createdAt: -1 }).lean();
    res.json(users.map(publicUser));
  }),
);

async function change(req, res, field, allowed) {
  const value = req.body.status;
  if (!allowed.includes(value)) throw new HttpError(400, 'Invalid value.');
  const user = await User.findByIdAndUpdate(
    req.params.id,
    { [field]: value },
    { new: true },
  ).lean();
  if (!user) throw new HttpError(404, 'Account not found.');
  res.json({ user: publicUser(user) });
}

// UC-35 block / unblock
router.patch(
  '/:id/status',
  asyncHandler((req, res) => change(req, res, 'status', ['active', 'blocked'])),
);

// UC-34 approve / reject a mechanic
router.patch(
  '/:id/verification',
  asyncHandler((req, res) =>
    change(req, res, 'verificationStatus', ['pending', 'verified', 'rejected'])),
);

module.exports = router;
