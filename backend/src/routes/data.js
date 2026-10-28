const express = require('express');
const M = require('../models');
const { resource } = require('../resource');
const { requireAuth } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');
const { HttpError } = require('../utils/httpError');

const uid = (req) => String(req.user._id);
const isAdmin = (req) => req.user.role === 'admin';
const isMechanic = (req) => req.user.role === 'mechanic';
const refuse = () => {
  throw new HttpError(403, 'You are not allowed to do this.');
};

/** Is the user the customer or the assigned mechanic of this request (or admin)? */
async function inJob(req, requestId) {
  if (isAdmin(req)) return true;
  const request = await M.Request.findById(requestId).lean();
  if (!request) return false;
  return request.customerId === uid(req) || request.mechanicId === uid(req);
}

/** Everyone but the owner may change only these fields of a mechanic profile. */
const OTHERS_MAY_CHANGE = ['rating', 'reviewCount', 'jobsDone'];
function onlyChanged(existing, body, keys) {
  const names = new Set([...Object.keys(existing), ...Object.keys(body)]);
  names.delete('_id');
  for (const name of names) {
    if (keys.includes(name)) continue;
    if (JSON.stringify(existing[name]) !== JSON.stringify(body[name])) return false;
  }
  return true;
}

const router = express.Router();
const use = (path, handler) => router.use(path, requireAuth, handler);

// ---- service requests ----------------------------------------------------
use(
  '/requests',
  resource(M.Request, {
    filters: ['customerId', 'status', 'mechanicId'],
    sort: { createdAt: -1 },
    limit: 1000,
    scope: (req, filter) => {
      // A customer only ever sees their own requests.
      if (req.user.role === 'customer') return { ...filter, customerId: uid(req) };
      return filter;
    },
    canRead: (req, doc) =>
      req.user.role !== 'customer' || doc.customerId === uid(req),
    canCreate: (req, body) => isAdmin(req) || (body.customerId === uid(req) && req.user.role === 'customer'),
    canUpdate: (req, doc) =>
      isAdmin(req) || isMechanic(req) || doc.customerId === uid(req),
  }),
);

// ---- estimates -----------------------------------------------------------
use(
  '/estimates',
  resource(M.Estimate, {
    filters: ['requestId', 'mechanicId'],
    sort: { amount: 1 },
    scope: (req, filter) => {
      if (!filter.requestId && !filter.mechanicId && !isAdmin(req)) refuse();
      return filter;
    },
    canCreate: (req, body) =>
      isAdmin(req) || (isMechanic(req) && body.mechanicId === uid(req)),
    canUpdate: () => true,
  }),
);

// ---- mechanic profiles ---------------------------------------------------
use(
  '/mechanics',
  resource(M.Mechanic, {
    sort: { rating: -1 },
    canCreate: (req, _body, id) => isAdmin(req) || id === uid(req),
    canUpdate: (req, doc, body) =>
      isAdmin(req) || doc._id === uid(req) || onlyChanged(doc, body, OTHERS_MAY_CHANGE),
  }),
);

// ---- notifications -------------------------------------------------------
use(
  '/notifications',
  resource(M.Notification, {
    filters: ['userId'],
    sort: { createdAt: -1 },
    scope: (req, filter) => {
      if (isAdmin(req)) return filter;
      if (filter.userId && filter.userId !== uid(req)) refuse();
      return { ...filter, userId: uid(req) };
    },
    canRead: (req, doc) => isAdmin(req) || doc.userId === uid(req),
    canCreate: () => true,
    canUpdate: (req, doc) => isAdmin(req) || doc.userId === uid(req),
    extra: (r) => {
      r.post(
        '/read-all',
        asyncHandler(async (req, res) => {
          const userId = req.body && req.body.userId;
          if (typeof userId !== 'string') throw new HttpError(400, 'userId is required.');
          if (userId !== uid(req) && !isAdmin(req)) refuse();
          await M.Notification.collection.updateMany({ userId, read: { $ne: true } }, { $set: { read: true } });
          res.json({ ok: true });
        }),
      );
    },
  }),
);

// ---- saved vehicles ------------------------------------------------------
use(
  '/vehicles',
  resource(M.Vehicle, {
    filters: ['ownerId'],
    scope: (req, filter) => {
      if (isAdmin(req)) return filter;
      if (filter.ownerId && filter.ownerId !== uid(req)) refuse();
      return { ...filter, ownerId: uid(req) };
    },
    canRead: (req, doc) => isAdmin(req) || doc.ownerId === uid(req),
    canCreate: (req, body) => isAdmin(req) || body.ownerId === uid(req),
    canUpdate: (req, doc, body) =>
      isAdmin(req) || (doc.ownerId === uid(req) && body.ownerId === uid(req)),
    canDelete: (req, doc) => isAdmin(req) || doc.ownerId === uid(req),
  }),
);

// ---- chat ------------------------------------------------------------------
use(
  '/messages',
  resource(M.Message, {
    filters: ['requestId'],
    sort: { sentAt: 1 },
    limit: 1000,
    canList: async (req) =>
      typeof req.query.requestId === 'string' && (await inJob(req, req.query.requestId)),
    scope: (req, filter) => {
      if (!filter.requestId) refuse();
      return filter;
    },
    canRead: (req, doc) => inJob(req, doc.requestId),
    canCreate: async (req, body) =>
      (isAdmin(req) || body.senderId === uid(req)) && (await inJob(req, body.requestId)),
    canUpdate: () => false,
  }),
);

// ---- reviews (id = request id, written once) -------------------------------
use(
  '/reviews',
  resource(M.Review, {
    filters: ['mechanicId', 'requestId'],
    sort: { createdAt: -1 },
    scope: (req, filter) => {
      if (!filter.mechanicId && !filter.requestId) refuse();
      return filter;
    },
    canCreate: (req, body) => isAdmin(req) || body.customerId === uid(req),
    canUpdate: () => false,
  }),
);

// ---- complaints ------------------------------------------------------------
use(
  '/complaints',
  resource(M.Complaint, {
    filters: ['requestId'],
    sort: { createdAt: -1 },
    scope: (req, filter) => {
      if (!isAdmin(req) && !filter.requestId) refuse();
      return filter;
    },
    canRead: (req, doc) => isAdmin(req) || doc.customerId === uid(req) || doc.mechanicId === uid(req),
    canCreate: (req, body) => isAdmin(req) || body.customerId === uid(req),
    canUpdate: (req) => isAdmin(req),
  }),
);

// ---- mechanic verification forms (id = user id) ----------------------------
use(
  '/applications',
  resource(M.Application, {
    sort: { submittedAt: -1 },
    canList: (req) => isAdmin(req),
    canRead: (req, doc) => isAdmin(req) || doc._id === uid(req),
    canCreate: (req, _body, id) => isAdmin(req) || id === uid(req),
    canUpdate: (req, doc) => isAdmin(req) || doc._id === uid(req),
    canDelete: (req) => isAdmin(req),
  }),
);

// ---- admin activity log ----------------------------------------------------
use(
  '/audit',
  resource(M.AuditLog, {
    sort: { createdAt: -1 },
    limit: 200,
    canList: (req) => isAdmin(req),
    canRead: (req) => isAdmin(req),
    canCreate: (req) => isAdmin(req),
    canUpdate: () => false,
  }),
);

// ---- live GPS of the mechanic (id = request id) ----------------------------
use(
  '/live',
  resource(M.LiveLocation, {
    canList: () => false,
    canRead: (req, doc) => inJob(req, doc._id),
    canCreate: async (req, _body, id) => {
      if (isAdmin(req)) return true;
      const request = await M.Request.findById(id).lean();
      return Boolean(request) && request.mechanicId === uid(req);
    },
    canUpdate: async (req, doc) => {
      if (isAdmin(req)) return true;
      const request = await M.Request.findById(doc._id).lean();
      return Boolean(request) && request.mechanicId === uid(req);
    },
  }),
);

module.exports = router;
