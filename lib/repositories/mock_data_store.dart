import '../models/app_notification.dart';
import '../models/audit_log.dart';
import '../models/chat_message.dart';
import '../models/complaint.dart';
import '../models/mechanic_application.dart';
import '../models/review.dart';
import '../models/enums/problem_type.dart';
import '../models/enums/vehicle_type.dart';
import '../models/enums/payment_method.dart';
import '../models/enums/request_status.dart';
import '../models/estimate.dart';
import '../models/lat_lng.dart';
import '../models/live_location.dart';
import '../models/mechanic_profile.dart';
import '../models/photo_attachment.dart';
import '../models/service_request.dart';
import '../models/vehicle.dart';

/// The in-memory "database" shared by all mock repositories, so a customer
/// and a mechanic logging in one after the other see the same data.
class MockDataStore {
  MockDataStore({
    DateTime Function()? now,
    this.simulatedDelay = const Duration(milliseconds: 250),
  }) : now = now ?? DateTime.now {
    _seed();
  }

  final DateTime Function() now;
  final Duration simulatedDelay;

  final Map<String, Vehicle> vehicles = <String, Vehicle>{};
  final Map<String, ServiceRequest> requests = <String, ServiceRequest>{};
  final Map<String, Estimate> estimates = <String, Estimate>{};
  final Map<String, MechanicProfile> mechanics = <String, MechanicProfile>{};
  final Map<String, AppNotification> notifications =
      <String, AppNotification>{};

  final Map<String, ChatMessage> messages = <String, ChatMessage>{};
  final Map<String, Review> reviews = <String, Review>{};
  final Map<String, Complaint> complaints = <String, Complaint>{};
  final Map<String, MechanicApplication> applications =
      <String, MechanicApplication>{};

  final Map<String, AuditLog> auditLogs = <String, AuditLog>{};

  final Map<String, LiveLocation> liveLocations = <String, LiveLocation>{};

  int _nextId = 1;

  String newId(String prefix) => '$prefix${_nextId++}';

  Future<void> simulate() => Future<void>.delayed(simulatedDelay);

  void _seed() {
    final DateTime t = now();
    vehicles['v0'] = const Vehicle(
      id: 'v0',
      ownerId: 'u1',
      type: VehicleType.car,
      make: 'Suzuki',
      model: 'Cultus',
      plate: 'ICT-1234',
    );

    mechanics['u2'] = const MechanicProfile(
      userId: 'u2',
      name: 'Usman Ghani',
      phone: '+923217654321',
      location: LatLng(33.6900, 73.0550),
      rating: 4.8,
      reviewCount: 132,
      jobsDone: 150,
      experienceYears: 8,
      bio: 'Roadside repairs, tyres and batteries. Fast and honest pricing.',
      services: <ProblemType>{
        ProblemType.flatTire,
        ProblemType.batteryJump,
        ProblemType.outOfFuel,
        ProblemType.engineTrouble,
      },
      vehicleTypes: <VehicleType>{VehicleType.car, VehicleType.van},
      isOnline: true,
    );
    mechanics['m2'] = const MechanicProfile(
      userId: 'm2',
      name: 'Ahmed Khan',
      phone: '+923001110002',
      location: LatLng(33.7100, 73.0600),
      rating: 4.5,
      reviewCount: 64,
      jobsDone: 80,
      experienceYears: 5,
      bio: 'Towing and engine diagnostics.',
      services: <ProblemType>{
        ProblemType.towing,
        ProblemType.engineTrouble,
        ProblemType.batteryJump,
      },
      vehicleTypes: <VehicleType>{VehicleType.car, VehicleType.van},
      isOnline: true,
    );
    mechanics['m3'] = const MechanicProfile(
      userId: 'm3',
      name: 'Bilal Hussain',
      phone: '+923001110003',
      location: LatLng(33.6500, 73.0100),
      rating: 4.2,
      reviewCount: 31,
      jobsDone: 40,
      experienceYears: 3,
      bio: 'Bike and rickshaw specialist.',
      services: <ProblemType>{
        ProblemType.flatTire,
        ProblemType.outOfFuel,
        ProblemType.lockout,
      },
      vehicleTypes: <VehicleType>{VehicleType.bike, VehicleType.rickshaw},
      isOnline: true,
    );
    mechanics['m4'] = const MechanicProfile(
      userId: 'm4',
      name: 'Hamza Ali',
      phone: '+923001110004',
      location: LatLng(33.7600, 73.1200),
      rating: 4.0,
      reviewCount: 12,
      jobsDone: 15,
      experienceYears: 2,
      bio: 'General roadside help.',
      services: <ProblemType>{
        ProblemType.flatTire,
        ProblemType.batteryJump,
        ProblemType.other,
      },
      vehicleTypes: <VehicleType>{VehicleType.car},
      isOnline: true,
    );
    mechanics['m5'] = const MechanicProfile(
      userId: 'm5',
      name: 'Kashif Mehmood',
      phone: '+923001110005',
      location: LatLng(33.6700, 73.0600),
      rating: 4.6,
      reviewCount: 90,
      jobsDone: 110,
      experienceYears: 10,
      bio: 'Offline right now.',
      services: <ProblemType>{ProblemType.engineTrouble, ProblemType.towing},
      vehicleTypes: <VehicleType>{VehicleType.car, VehicleType.van},
    );

    // Two finished jobs so the history, earnings and reviews are not empty.
    void seedJob(String id, ProblemType problem, int amount, int daysAgo,
        int rating, String comment) {
      final DateTime done = t.subtract(Duration(days: daysAgo));
      requests[id] = ServiceRequest(
        id: id,
        customerId: 'u1',
        customerName: 'Ali Raza',
        vehicleId: 'v0',
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
        mechanicId: 'u2',
        mechanicName: 'Usman Ghani',
        agreedAmount: amount,
        etaMinutes: 12,
        completedAt: done,
        paymentMethod: PaymentMethod.cash,
        paidAt: done,
      );
      reviews[id] = Review(
        requestId: id,
        customerId: 'u1',
        customerName: 'Ali Raza',
        mechanicId: 'u2',
        rating: rating,
        comment: comment,
        createdAt: done,
      );
    }

    seedJob('r_seed1', ProblemType.flatTire, 1200, 3, 5, 'Quick and polite.');
    seedJob('r_seed2', ProblemType.batteryJump, 1500, 6, 4, 'Good service.');

    applications['u5'] = MechanicApplication(
      userId: 'u5',
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
      vehicleTypes: const <VehicleType>{VehicleType.car, VehicleType.van},
      documents: const <String>['CNIC front', 'CNIC back', 'Workshop photo'],
      submittedAt: t,
    );

    notifications['n0'] = AppNotification(
      id: 'n0',
      userId: 'u1',
      title: 'Welcome to FixOnWay',
      body: 'Add your vehicle and request help any time.',
      createdAt: t,
    );
  }
}
