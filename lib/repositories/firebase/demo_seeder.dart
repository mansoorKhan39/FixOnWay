import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/errors/app_exception.dart';
import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/enums/payment_method.dart';
import '../../models/enums/problem_type.dart';
import '../../models/enums/request_status.dart';
import '../../models/enums/user_role.dart';
import '../../models/enums/user_status.dart';
import '../../models/enums/vehicle_type.dart';
import '../../models/enums/verification_status.dart';
import '../../models/lat_lng.dart';
import '../../models/mechanic_application.dart';
import '../../models/mechanic_profile.dart';
import '../../models/photo_attachment.dart';
import '../../models/review.dart';
import '../../models/service_request.dart';
import '../../models/vehicle.dart';
import 'codecs.dart';
import 'firebase_support.dart';

class _Demo {
  const _Demo({
    required this.key,
    required this.role,
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
    this.verification,
    this.status = UserStatus.active,
  });

  final String key;
  final UserRole role;
  final String name;
  final String phone;
  final String email;
  final String password;
  final VerificationStatus? verification;
  final UserStatus status;
}

/// One-time helper (debug builds only): creates the demo accounts and some
/// sample data in Firebase, so the app is not empty on the first run.
///
/// Safe to run again: accounts are reused and sample documents have fixed
/// ids, so nothing is duplicated.
class DemoSeeder {
  DemoSeeder({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const List<_Demo> _accounts = <_Demo>[
    _Demo(
      key: 'ali',
      role: UserRole.customer,
      name: 'Ali Raza',
      phone: '+923001234567',
      email: 'ali.raza@example.pk',
      password: 'Pass@1234',
    ),
    _Demo(
      key: 'usman',
      role: UserRole.mechanic,
      name: 'Usman Ghani',
      phone: '+923217654321',
      email: 'usman@example.pk',
      password: 'Pass@1234',
      verification: VerificationStatus.verified,
    ),
    _Demo(
      key: 'sara',
      role: UserRole.admin,
      name: 'Sara Khan',
      phone: '+923331112233',
      email: 'sara.khan@fixonway.pk',
      password: 'Admin@1234',
    ),
    _Demo(
      key: 'ahmed',
      role: UserRole.mechanic,
      name: 'Ahmed Khan',
      phone: '+923001110002',
      email: 'ahmed@example.pk',
      password: 'Pass@1234',
      verification: VerificationStatus.verified,
    ),
    _Demo(
      key: 'bilal',
      role: UserRole.mechanic,
      name: 'Bilal Hussain',
      phone: '+923001110003',
      email: 'bilal@example.pk',
      password: 'Pass@1234',
      verification: VerificationStatus.verified,
    ),
    _Demo(
      key: 'hamza',
      role: UserRole.mechanic,
      name: 'Hamza Ali',
      phone: '+923001110004',
      email: 'hamza@example.pk',
      password: 'Pass@1234',
      verification: VerificationStatus.verified,
    ),
    _Demo(
      key: 'kashif',
      role: UserRole.mechanic,
      name: 'Kashif Mehmood',
      phone: '+923001110005',
      email: 'kashif@example.pk',
      password: 'Pass@1234',
      verification: VerificationStatus.verified,
    ),
    _Demo(
      key: 'zahid',
      role: UserRole.mechanic,
      name: 'Zahid Mehmood',
      phone: '+923451112299',
      email: 'zahid@example.pk',
      password: 'Pass@1234',
      verification: VerificationStatus.pending,
    ),
    _Demo(
      key: 'hira',
      role: UserRole.customer,
      name: 'Hira Sheikh',
      phone: '+923331239876',
      email: 'hira@example.pk',
      password: 'Pass@1234',
    ),
    _Demo(
      key: 'blocked',
      role: UserRole.customer,
      name: 'Blocked User',
      phone: '+923451234567',
      email: 'blocked@example.pk',
      password: 'Pass@1234',
      status: UserStatus.blocked,
    ),
  ];

  Future<String> _ensureAccount(_Demo d) async {
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: d.email,
        password: d.password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        cred = await _auth.signInWithEmailAndPassword(
          email: d.email,
          password: d.password,
        );
      } else if (e.code == 'operation-not-allowed') {
        throw const AppException(
          'Email/Password sign-in is switched off. In the Firebase console '
          'open Authentication > Sign-in method > Add new provider > '
          'Email/Password, enable it and try again.',
        );
      } else {
        throw AppException('Could not create ${d.email} (${e.code}).');
      }
    }
    final String uid = cred.user!.uid;
    final AppUser user = AppUser(
      id: uid,
      role: d.role,
      name: d.name,
      phone: d.phone,
      email: d.email,
      status: d.status,
      verificationStatus: d.verification,
    );
    await _db.collection(Col.users).doc(uid).set(<String, dynamic>{
      ...user.toMap(),
      'authEmail': d.email,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _auth.signOut();
    return uid;
  }

  /// Creates everything and returns a short summary.
  Future<String> run() {
    return guardFirebase(() async {
      final Map<String, String> uid = <String, String>{};
      for (final _Demo d in _accounts) {
        uid[d.key] = await _ensureAccount(d);
      }
      final DateTime now = DateTime.now();

      // Sign in so the sample data is written by a logged-in user (needed
      // when the Firestore rules ask for login). Signed out again at the end.
      await _auth.signInWithEmailAndPassword(
        email: 'sara.khan@fixonway.pk',
        password: 'Admin@1234',
      );

      // Mechanic profiles (only verified mechanics have one).
      final Map<String, MechanicProfile> profiles = <String, MechanicProfile>{
        'usman': MechanicProfile(
          userId: uid['usman']!,
          name: 'Usman Ghani',
          phone: '+923217654321',
          location: const LatLng(33.6900, 73.0550),
          rating: 4.8,
          reviewCount: 132,
          jobsDone: 150,
          experienceYears: 8,
          bio: 'Roadside repairs, tyres and batteries. Fast and honest pricing.',
          services: const <ProblemType>{
            ProblemType.flatTire,
            ProblemType.batteryJump,
            ProblemType.outOfFuel,
            ProblemType.engineTrouble,
          },
          vehicleTypes: const <VehicleType>{VehicleType.car, VehicleType.van},
          isOnline: true,
        ),
        'ahmed': MechanicProfile(
          userId: uid['ahmed']!,
          name: 'Ahmed Khan',
          phone: '+923001110002',
          location: const LatLng(33.7100, 73.0600),
          rating: 4.5,
          reviewCount: 64,
          jobsDone: 80,
          experienceYears: 5,
          bio: 'Towing and engine diagnostics.',
          services: const <ProblemType>{
            ProblemType.towing,
            ProblemType.engineTrouble,
            ProblemType.batteryJump,
          },
          vehicleTypes: const <VehicleType>{VehicleType.car, VehicleType.van},
          isOnline: true,
        ),
        'bilal': MechanicProfile(
          userId: uid['bilal']!,
          name: 'Bilal Hussain',
          phone: '+923001110003',
          location: const LatLng(33.6500, 73.0100),
          rating: 4.2,
          reviewCount: 31,
          jobsDone: 40,
          experienceYears: 3,
          bio: 'Bike and rickshaw specialist.',
          services: const <ProblemType>{
            ProblemType.flatTire,
            ProblemType.outOfFuel,
            ProblemType.lockout,
          },
          vehicleTypes: const <VehicleType>{
            VehicleType.bike,
            VehicleType.rickshaw,
          },
          isOnline: true,
        ),
        'hamza': MechanicProfile(
          userId: uid['hamza']!,
          name: 'Hamza Ali',
          phone: '+923001110004',
          location: const LatLng(33.7600, 73.1200),
          rating: 4.0,
          reviewCount: 12,
          jobsDone: 15,
          experienceYears: 2,
          bio: 'General roadside help.',
          services: const <ProblemType>{
            ProblemType.flatTire,
            ProblemType.batteryJump,
            ProblemType.other,
          },
          vehicleTypes: const <VehicleType>{VehicleType.car},
          isOnline: true,
        ),
        'kashif': MechanicProfile(
          userId: uid['kashif']!,
          name: 'Kashif Mehmood',
          phone: '+923001110005',
          location: const LatLng(33.6700, 73.0600),
          rating: 4.6,
          reviewCount: 90,
          jobsDone: 110,
          experienceYears: 10,
          bio: 'Engine and towing specialist.',
          services: const <ProblemType>{
            ProblemType.engineTrouble,
            ProblemType.towing,
          },
          vehicleTypes: const <VehicleType>{VehicleType.car, VehicleType.van},
        ),
      };
      for (final MapEntry<String, MechanicProfile> e in profiles.entries) {
        await _db
            .collection(Col.mechanics)
            .doc(uid[e.key])
            .set(Codecs.mechanicToMap(e.value));
      }

      // A pending mechanic with a verification form.
      await _db.collection(Col.applications).doc(uid['zahid']).set(
            Codecs.applicationToMap(
              MechanicApplication(
                userId: uid['zahid']!,
                name: 'Zahid Mehmood',
                phone: '+923451112299',
                cnic: '3520112345671',
                experienceYears: 6,
                workshopAddress: 'Shop 12, G-9 Markaz, Islamabad',
                services: const <ProblemType>{
                  ProblemType.flatTire,
                  ProblemType.batteryJump,
                  ProblemType.towing,
                },
                vehicleTypes: const <VehicleType>{
                  VehicleType.car,
                  VehicleType.van,
                },
                documents: const <String>[
                  'CNIC front',
                  'CNIC back',
                  'Workshop photo',
                ],
                submittedAt: now,
              ),
            ),
          );

      // A vehicle for Ali.
      const Vehicle cultus = Vehicle(
        id: 'seed_v1',
        ownerId: '',
        type: VehicleType.car,
        make: 'Suzuki',
        model: 'Cultus',
        plate: 'ICT-1234',
      );
      await _db.collection(Col.vehicles).doc('seed_v1').set(
        <String, dynamic>{...cultus.toMap(), 'ownerId': uid['ali']},
      );

      // Two finished jobs with reviews, so history and reports have data.
      Future<void> job(
        String id,
        ProblemType problem,
        int amount,
        int daysAgo,
        int rating,
        String comment,
      ) async {
        final DateTime done = now.subtract(Duration(days: daysAgo));
        await _db.collection(Col.requests).doc(id).set(
              Codecs.requestToMap(
                ServiceRequest(
                  id: id,
                  customerId: uid['ali']!,
                  customerName: 'Ali Raza',
                  vehicleId: 'seed_v1',
                  vehicleTitle: 'Suzuki Cultus (ICT-1234)',
                  vehicleType: VehicleType.car,
                  problem: problem,
                  description: '',
                  location: LatLng.islamabad,
                  address: 'F-10 Markaz, Islamabad',
                  photos: const <PhotoAttachment>[],
                  status: RequestStatus.closed,
                  createdAt: done,
                  updatedAt: done,
                  mechanicId: uid['usman'],
                  mechanicName: 'Usman Ghani',
                  agreedAmount: amount,
                  etaMinutes: 12,
                  completedAt: done,
                  paymentMethod: PaymentMethod.cash,
                  paidAt: done,
                ),
              ),
            );
        await _db.collection(Col.reviews).doc(id).set(
              Codecs.reviewToMap(
                Review(
                  requestId: id,
                  customerId: uid['ali']!,
                  customerName: 'Ali Raza',
                  mechanicId: uid['usman']!,
                  rating: rating,
                  comment: comment,
                  createdAt: done,
                ),
              ),
            );
      }

      await job('seed_r1', ProblemType.flatTire, 1200, 3, 5, 'Quick and polite.');
      await job('seed_r2', ProblemType.batteryJump, 1500, 6, 4, 'Good service.');

      await _db.collection(Col.notifications).doc('seed_n1').set(
            Codecs.notificationToMap(
              AppNotification(
                id: 'seed_n1',
                userId: uid['ali']!,
                title: 'Welcome to FixOnWay',
                body: 'Add your vehicle and request help any time.',
                createdAt: now,
              ),
            ),
          );

      await _auth.signOut();

      return 'Demo data is ready: ${_accounts.length} accounts, 5 mechanics, '
          '1 vehicle, 2 finished jobs.';
    });
  }
}
