const express = require('express');
const asyncHandler = require('./utils/asyncHandler');
const { HttpError } = require('./utils/httpError');
const { newId, assertSafe, out } = require('./utils/helpers');

const deny = () => false;
const allow = () => true;

/**
 * Builds the standard routes of one collection (list, get, create, replace,
 * delete) with the access rules of that collection.
 *
 * options:
 *   filters      query fields the app may filter by (values must be text)
 *   sort         Mongo sort for the list
 *   limit        maximum rows in one list
 *   scope(req, filter)  may add/force filter fields; throw HttpError to refuse
 *   canRead(req, doc)   may this user see this document?
 *   canCreate(req, body, id)
 *   canUpdate(req, doc, body)
 *   canDelete(req, doc)
 *   extra(router)       custom routes, added before /:id
 */
function resource(Model, options = {}) {
  const {
    filters = [],
    sort = {},
    limit = 500,
    scope = (_req, filter) => filter,
    canRead = allow,
    canCreate = allow,
    canUpdate = allow,
    canDelete = deny,
    canList = allow,
    extra,
  } = options;

  const router = express.Router();
  if (extra) extra(router);

  router.get(
    '/',
    asyncHandler(async (req, res) => {
      if (!(await canList(req))) throw new HttpError(403, 'You are not allowed to do this.');
      let filter = {};
      for (const key of filters) {
        const value = req.query[key];
        if (value === undefined) continue;
        if (typeof value !== 'string') throw new HttpError(400, `Invalid filter "${key}".`);
        filter[key] = value;
      }
      filter = (await scope(req, filter)) || filter;
      let max = limit;
      if (req.query.limit !== undefined) {
        const asked = Number.parseInt(req.query.limit, 10);
        if (Number.isFinite(asked) && asked > 0) max = Math.min(asked, limit);
      }
      const docs = await Model.find(filter).sort(sort).limit(max).lean();
      res.json(docs.map(out));
    }),
  );

  router.get(
    '/:id',
    asyncHandler(async (req, res) => {
      const doc = await Model.findById(req.params.id).lean();
      if (!doc) throw new HttpError(404, 'Not found.');
      if (!(await canRead(req, doc))) throw new HttpError(403, 'You are not allowed to see this.');
      res.json(out(doc));
    }),
  );

  const readBody = (req) => {
    const body = req.body;
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      throw new HttpError(400, 'The request body must be a JSON object.');
    }
    assertSafe(body);
    const { id, _id, __v, ...fields } = body;
    return fields;
  };

  router.post(
    '/',
    asyncHandler(async (req, res) => {
      const fields = readBody(req);
      const id = newId();
      if (!(await canCreate(req, fields, id))) {
        throw new HttpError(403, 'You are not allowed to do this.');
      }
      const created = await Model.collection.insertOne({ _id: id, ...fields });
      if (!created.acknowledged) throw new HttpError(500, 'Could not save.');
      res.status(201).json(out({ _id: id, ...fields }));
    }),
  );

  // Replace (or create under a chosen id, e.g. a review under its request id).
  router.put(
    '/:id',
    asyncHandler(async (req, res) => {
      const fields = readBody(req);
      const id = req.params.id;
      const existing = await Model.findById(id).lean();
      if (existing) {
        if (!(await canUpdate(req, existing, fields))) {
          throw new HttpError(403, 'You are not allowed to change this.');
        }
      } else if (!(await canCreate(req, fields, id))) {
        throw new HttpError(403, 'You are not allowed to do this.');
      }
      await Model.collection.replaceOne({ _id: id }, { _id: id, ...fields }, { upsert: true });
      res.json(out({ _id: id, ...fields }));
    }),
  );

  router.delete(
    '/:id',
    asyncHandler(async (req, res) => {
      const doc = await Model.findById(req.params.id).lean();
      if (!doc) return res.status(204).end();
      if (!(await canDelete(req, doc))) {
        throw new HttpError(403, 'You are not allowed to delete this.');
      }
      await Model.collection.deleteOne({ _id: req.params.id });
      return res.status(204).end();
    }),
  );

  return router;
}

module.exports = { resource };
