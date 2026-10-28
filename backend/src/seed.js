/**
 * Fills the database with demo accounts and sample data.
 * Run:  npm run seed      (add --keep to leave existing data alone)
 */
const bcrypt = require('bcryptjs');
const M = require('./models');
const { connect, disconnect } = require('./db');
const { newId } = require('./utils/helpers');

const DAY = 24 * 60 * 60 * 1000;

const ACCOUNTS = [
  { key: 'ali', role: 'customer', name: 'Ali Raza', phone: '+923001234567', email: 'ali.raza@example.pk', password: 'Pass@1234' },
  { key: 'usman', role: 'mechanic', name: 'Usman Ghani', phone: '+923217654321', email: 'usman@example.pk', password: 'Pass@1234', verificationStatus: 'verified' },
  { key: 'sara', role: 'admin', name: 'Sara Khan', phone: '+923331112233', email: 'sara.khan@fixonway.pk', password: 'Admin@1234' },
  { key: 'ahmed', role: 'mechanic', name: 'Ahmed Khan', phone: '+923001110002', email: 'ahmed@example.pk', password: 'Pass@1234', verificationStatus: 'verified' },
  { key: 'bilal', role: 'mechanic', name: 'Bilal Hussain', phone: '+923001110003', email: 'bilal@example.pk', password: 'Pass@1234', verificationStatus: 'verified' },
  { key: 'hamza', role: 'mechanic', name: 'Hamza Ali', phone: '+923001110004', email: 'hamza@example.pk', password: 'Pass@1234', verificationStatus: 'verified' },
  { key: 'kashif', role: 'mechanic', name: 'Kashif Mehmood', phone: '+923001110005', email: 'kashif@example.pk', password: 'Pass@1234', verificationStatus: 'verified' },
  { key: 'zahid', role: 'mechanic', name: 'Zahid Mehmood', phone: '+923451112299', email: 'zahid@example.pk', password: 'Pass@1234', verificationStatus: 'pending' },
  { key: 'hira', role: 'customer', name: 'Hira Sheikh', phone: '+923331239876', email: 'hira@example.pk', password: 'Pass@1234' },
  { key: 'blocked', role: 'customer', name: 'Blocked User', phone: '+923451234567', email: 'blocked@example.pk', password: 'Pass@1234', status: 'blocked' },
];

const PROFILES = {
  usman: { lat: 33.69, lng: 73.055, rating: 4.8, reviewCount: 132, jobsDone: 150, experienceYears: 8, bio: 'Roadside repairs, tyres and batteries. Fast and honest pricing.', services: ['flatTire', 'batteryJump', 'outOfFuel', 'engineTrouble'], vehicleTypes: ['car', 'van'], isOnline: true },
  ahmed: { lat: 33.71, lng: 73.06, rating: 4.5, reviewCount: 64, jobsDone: 80, experienceYears: 5, bio: 'Towing and engine diagnostics.', services: ['towing', 'engineTrouble', 'batteryJump'], vehicleTypes: ['car', 'van'], isOnline: true },
  bilal: { lat: 33.65, lng: 73.01, rating: 4.2, reviewCount: 31, jobsDone: 40, experienceYears: 3, bio: 'Bike and rickshaw specialist.', services: ['flatTire', 'outOfFuel', 'lockout'], vehicleTypes: ['bike', 'rickshaw'], isOnline: true },
  hamza: { lat: 33.76, lng: 73.12, rating: 4.0, reviewCount: 12, jobsDone: 15, experienceYears: 2, bio: 'General roadside help.', services: ['flatTire', 'batteryJump', 'other'], vehicleTypes: ['car'], isOnline: true },
  kashif: { lat: 33.67, lng: 73.06, rating: 4.6, reviewCount: 90, jobsDone: 110, experienceYears: 10, bio: 'Engine and towing specialist.', services: ['engineTrouble', 'towing'], vehicleTypes: ['car', 'van'], isOnline: false },
};

async function seed({ keep = false } = {}) {
  if (!keep) {
    await Promise.all(Object.values(M).map((model) => model.deleteMany({})));
  }
  const now = Date.now();
  const id = {};

  for (const a of ACCOUNTS) {
    const user = await M.User.findOneAndUpdate(
      { email: a.email },
      {
        $set: {
          role: a.role,
          name: a.name,
          phone: a.phone,
          email: a.email,
          passwordHash: await bcrypt.hash(a.password, 10),
          status: a.status || 'active',
          ...(a.verificationStatus ? { verificationStatus: a.verificationStatus } : {}),
          failedLogins: 0,
        },
        $setOnInsert: { _id: newId(), createdAt: now },
      },
      { upsert: true, new: true },
    ).lean();
    id[a.key] = String(user._id);
  }

  const put = (Model, _id, doc) =>
    Model.collection.replaceOne({ _id }, { _id, ...doc }, { upsert: true });

  for (const [key, p] of Object.entries(PROFILES)) {
    const account = ACCOUNTS.find((a) => a.key === key);
    await put(M.Mechanic, id[key], {
      name: account.name,
      phone: account.phone,
      location: { lat: p.lat, lng: p.lng },
      rating: p.rating,
      reviewCount: p.reviewCount,
      jobsDone: p.jobsDone,
      experienceYears: p.experienceYears,
      bio: p.bio,
      services: p.services,
      vehicleTypes: p.vehicleTypes,
      isOnline: p.isOnline,
      serviceRadiusKm: 10,
      workingHours: '9:00 AM - 9:00 PM',
    });
  }

  await put(M.Application, id.zahid, {
    name: 'Zahid Mehmood',
    phone: '+923451112299',
    cnic: '3520112345671',
    experienceYears: 6,
    workshopAddress: 'Shop 12, G-9 Markaz, Islamabad',
    services: ['flatTire', 'batteryJump', 'towing'],
    vehicleTypes: ['car', 'van'],
    documents: ['CNIC front', 'CNIC back', 'Workshop photo'],
    submittedAt: now,
  });

  await put(M.Vehicle, 'seed_v1', {
    ownerId: id.ali,
    type: 'car',
    make: 'Suzuki',
    model: 'Cultus',
    plate: 'ICT-1234',
  });

  const job = async (rid, problem, amount, daysAgo, rating, comment) => {
    const done = now - daysAgo * DAY;
    await put(M.Request, rid, {
      customerId: id.ali,
      customerName: 'Ali Raza',
      vehicleId: 'seed_v1',
      vehicleTitle: 'Suzuki Cultus (ICT-1234)',
      vehicleType: 'car',
      problem,
      description: '',
      location: { lat: 33.6844, lng: 73.0479 },
      address: 'F-10 Markaz, Islamabad',
      photos: [],
      status: 'closed',
      createdAt: done,
      updatedAt: done,
      mechanicId: id.usman,
      mechanicName: 'Usman Ghani',
      acceptedEstimateId: null,
      agreedAmount: amount,
      cancelReason: null,
      etaMinutes: 12,
      mechanicStart: null,
      startedAt: null,
      completedAt: done,
      paymentMethod: 'cash',
      paidAt: done,
      rejectedBy: [],
    });
    await put(M.Review, rid, {
      requestId: rid,
      customerId: id.ali,
      customerName: 'Ali Raza',
      mechanicId: id.usman,
      rating,
      comment,
      createdAt: done,
    });
  };
  await job('seed_r1', 'flatTire', 1200, 3, 5, 'Quick and polite.');
  await job('seed_r2', 'batteryJump', 1500, 6, 4, 'Good service.');

  await put(M.Notification, 'seed_n1', {
    userId: id.ali,
    title: 'Welcome to FixOnWay',
    body: 'Add your vehicle and request help any time.',
    createdAt: now,
    read: false,
    requestId: null,
  });

  return { accounts: ACCOUNTS.length, mechanics: Object.keys(PROFILES).length };
}

module.exports = { seed, ACCOUNTS };

if (require.main === module) {
  (async () => {
    try {
      await connect();
      const summary = await seed({ keep: process.argv.includes('--keep') });
      console.log(
        `Demo data is ready: ${summary.accounts} accounts, ${summary.mechanics} mechanics, 1 vehicle, 2 finished jobs.`,
      );
      console.log('Customer: ali.raza@example.pk / Pass@1234');
      console.log('Mechanic: usman@example.pk / Pass@1234');
      console.log('Admin:    sara.khan@fixonway.pk / Admin@1234');
    } catch (err) {
      console.error('Seeding failed:', err.message);
      process.exitCode = 1;
    } finally {
      await disconnect();
    }
  })();
}
