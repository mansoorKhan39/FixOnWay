const express = require('express');
const { StoredFile } = require('../models');
const { requireAuth, userFromToken, bearer } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');
const { HttpError } = require('../utils/httpError');
const { newId } = require('../utils/helpers');

const router = express.Router();

const MAX_BYTES = 5 * 1024 * 1024;

/** Looks at the first bytes of the file, so a renamed .exe is not accepted. */
function sniffImage(buf) {
  if (buf.length < 12) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return 'image/png';
  }
  if (buf.subarray(0, 4).toString('ascii') === 'GIF8') return 'image/gif';
  if (buf.subarray(0, 4).toString('ascii') === 'RIFF' && buf.subarray(8, 12).toString('ascii') === 'WEBP') {
    return 'image/webp';
  }
  return null;
}

const bytesOf = (data) => (Buffer.isBuffer(data) ? data : Buffer.from(data.buffer));

// Upload: the body is the raw picture, X-File-Name is its (url-encoded) name.
// ?kind=photo (problem photos, readable by anyone who has the link)
// ?kind=document (CNIC etc., only the owner and admins can read it)
router.post(
  '/',
  requireAuth,
  express.raw({ type: 'image/*', limit: '6mb' }),
  asyncHandler(async (req, res) => {
    const buf = req.body;
    if (!Buffer.isBuffer(buf) || buf.length === 0) throw new HttpError(400, 'Choose a picture to upload.');
    if (buf.length > MAX_BYTES) throw new HttpError(413, 'Each file must be 5 MB or smaller.');
    const mime = sniffImage(buf);
    if (!mime) throw new HttpError(400, 'Only JPG, PNG, WEBP or GIF pictures are allowed.');
    const kind = req.query.kind === 'document' ? 'document' : 'photo';
    let name = 'file';
    try {
      name = decodeURIComponent(String(req.headers['x-file-name'] || 'file')).slice(0, 100) || 'file';
    } catch (_) {
      name = 'file';
    }
    const id = newId();
    await StoredFile.collection.insertOne({
      _id: id,
      ownerId: String(req.user._id),
      kind,
      name,
      mime,
      size: buf.length,
      data: buf,
      createdAt: Date.now(),
    });
    res.status(201).json({ id, name, size: buf.length, kind });
  }),
);

// Download. Documents need a login: "Authorization: Bearer ..." or ?token=...
// (the token in the address lets an <img> tag show a document).
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const file = await StoredFile.findById(req.params.id).lean();
    if (!file) throw new HttpError(404, 'File not found.');
    if (file.kind !== 'photo') {
      const token = bearer(req) || (typeof req.query.token === 'string' ? req.query.token : null);
      const user = await userFromToken(token);
      if (user.role !== 'admin' && String(user._id) !== file.ownerId) {
        throw new HttpError(403, 'You are not allowed to see this file.');
      }
    }
    const data = bytesOf(file.data);
    res.set({
      'Content-Type': file.mime,
      'Content-Length': String(data.length),
      'Cache-Control': file.kind === 'photo' ? 'public, max-age=86400' : 'private, max-age=300',
    });
    res.send(data);
  }),
);

router.delete(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const file = await StoredFile.findById(req.params.id).lean();
    if (!file) return res.status(204).end();
    if (req.user.role !== 'admin' && String(req.user._id) !== file.ownerId) {
      throw new HttpError(403, 'You are not allowed to delete this file.');
    }
    await StoredFile.collection.deleteOne({ _id: req.params.id });
    return res.status(204).end();
  }),
);

module.exports = router;
