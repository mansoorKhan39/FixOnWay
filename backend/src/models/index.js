const mongoose = require('mongoose');
const { newId } = require('../utils/helpers');

// Ids are plain strings (the app stores them as text).
const idField = () => ({ type: String, default: newId });

// ---- users (own schema: passwords and login protection live here) ----
const userSchema = new mongoose.Schema(
  {
    _id: idField(),
    role: { type: String, enum: ['customer', 'mechanic', 'admin'], required: true },
    name: { type: String, required: true, trim: true },
    phone: { type: String, required: true, unique: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    status: { type: String, enum: ['active', 'blocked'], default: 'active' },
    verificationStatus: { type: String, enum: ['pending', 'verified', 'rejected'] },
    failedLogins: { type: Number, default: 0 },
    lockedUntil: { type: Date },
    createdAt: { type: Number, default: () => Date.now() },
  },
  { versionKey: false },
);
const User = mongoose.model('User', userSchema);

// ---- every other collection keeps the app's own JSON shape ----
function docModel(name, collection, indexes = []) {
  const schema = new mongoose.Schema({ _id: idField() }, { strict: false, versionKey: false });
  indexes.forEach((spec) => schema.index(spec));
  return mongoose.model(name, schema, collection);
}

const Request = docModel('Request', 'requests', [{ customerId: 1 }, { status: 1 }, { createdAt: -1 }]);
const Estimate = docModel('Estimate', 'estimates', [{ requestId: 1 }]);
const Mechanic = docModel('Mechanic', 'mechanics');
const Notification = docModel('Notification', 'notifications', [{ userId: 1 }]);
const Vehicle = docModel('Vehicle', 'vehicles', [{ ownerId: 1 }]);
const Message = docModel('Message', 'messages', [{ requestId: 1, sentAt: 1 }]);
const Review = docModel('Review', 'reviews', [{ mechanicId: 1 }]);
const Complaint = docModel('Complaint', 'complaints', [{ requestId: 1 }]);
const Application = docModel('Application', 'applications');
const AuditLog = docModel('AuditLog', 'auditLogs', [{ createdAt: -1 }]);
const LiveLocation = docModel('LiveLocation', 'liveLocations');

module.exports = {
  User, Request, Estimate, Mechanic, Notification, Vehicle, Message,
  Review, Complaint, Application, AuditLog, LiveLocation,
};
