import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/models/app_notification.dart';
import 'package:fixonway/models/audit_log.dart';
import 'package:fixonway/models/chat_message.dart';
import 'package:fixonway/models/complaint.dart';
import 'package:fixonway/models/enums/complaint_category.dart';
import 'package:fixonway/models/enums/complaint_status.dart';
import 'package:fixonway/models/enums/estimate_status.dart';
import 'package:fixonway/models/enums/payment_method.dart';
import 'package:fixonway/models/enums/problem_type.dart';
import 'package:fixonway/models/enums/request_status.dart';
import 'package:fixonway/models/enums/vehicle_type.dart';
import 'package:fixonway/models/estimate.dart';
import 'package:fixonway/models/lat_lng.dart';
import 'package:fixonway/models/mechanic_application.dart';
import 'package:fixonway/models/mechanic_profile.dart';
import 'package:fixonway/models/photo_attachment.dart';
import 'package:fixonway/models/review.dart';
import 'package:fixonway/models/service_request.dart';
import 'package:fixonway/repositories/api/codecs.dart';

void main() {
  final DateTime t = DateTime(2026, 3, 4, 5, 6, 7);

  test('service request survives a round trip', () {
    final ServiceRequest r = ServiceRequest(
      id: 'ignored',
      customerId: 'c1',
      customerName: 'Ali',
      vehicleId: 'v1',
      vehicleTitle: 'Suzuki Cultus',
      vehicleType: VehicleType.car,
      problem: ProblemType.towing,
      description: 'Stuck near F-10',
      location: const LatLng(33.7, 73.05),
      address: 'F-10 Markaz',
      photos: const <PhotoAttachment>[
        PhotoAttachment(name: 'a.jpg', sizeBytes: 1234),
      ],
      status: RequestStatus.onTheWay,
      createdAt: t,
      updatedAt: t.add(const Duration(minutes: 1)),
      mechanicId: 'm1',
      mechanicName: 'Usman',
      acceptedEstimateId: 'e1',
      agreedAmount: 1500,
      etaMinutes: 12,
      mechanicStart: const LatLng(33.69, 73.06),
      startedAt: t,
      paymentMethod: PaymentMethod.jazzcash,
      rejectedBy: const <String>{'m2', 'm3'},
    );
    final ServiceRequest back =
        Codecs.requestFromMap('r9', Codecs.requestToMap(r));
    expect(back.id, 'r9');
    expect(back.customerId, 'c1');
    expect(back.problem, ProblemType.towing);
    expect(back.status, RequestStatus.onTheWay);
    expect(back.location, const LatLng(33.7, 73.05));
    expect(back.mechanicStart, const LatLng(33.69, 73.06));
    expect(back.photos.single.name, 'a.jpg');
    expect(back.photos.single.sizeBytes, 1234);
    expect(back.createdAt, t);
    expect(back.startedAt, t);
    expect(back.completedAt, isNull);
    expect(back.paidAt, isNull);
    expect(back.agreedAmount, 1500);
    expect(back.paymentMethod, PaymentMethod.jazzcash);
    expect(back.rejectedBy, <String>{'m2', 'm3'});
  });

  test('estimate round trip keeps status and expiry', () {
    final Estimate e = Estimate(
      id: 'x',
      requestId: 'r1',
      mechanicId: 'm1',
      mechanicName: 'Usman',
      amount: 900,
      etaMinutes: 15,
      note: 'Bring a jack',
      createdAt: t,
      expiresAt: t.add(const Duration(minutes: 10)),
      status: EstimateStatus.accepted,
    );
    final Estimate back = Codecs.estimateFromMap('e5', Codecs.estimateToMap(e));
    expect(back.id, 'e5');
    expect(back.amount, 900);
    expect(back.note, 'Bring a jack');
    expect(back.expiresAt, t.add(const Duration(minutes: 10)));
    expect(back.status, EstimateStatus.accepted);
  });

  test('mechanic profile round trip keeps sets and numbers', () {
    const MechanicProfile p = MechanicProfile(
      userId: 'm1',
      name: 'Usman',
      phone: '+923217654321',
      location: LatLng(33.69, 73.055),
      rating: 4.5,
      reviewCount: 10,
      jobsDone: 12,
      experienceYears: 8,
      bio: 'Tyres',
      services: <ProblemType>{ProblemType.flatTire, ProblemType.towing},
      vehicleTypes: <VehicleType>{VehicleType.car},
      isOnline: true,
      serviceRadiusKm: 7,
      workingHours: '8:00 AM - 6:00 PM',
    );
    final MechanicProfile back =
        Codecs.mechanicFromMap('m1', Codecs.mechanicToMap(p));
    expect(back.userId, 'm1');
    expect(back.rating, 4.5);
    expect(back.services, p.services);
    expect(back.vehicleTypes, p.vehicleTypes);
    expect(back.isOnline, isTrue);
    expect(back.serviceRadiusKm, 7);
    expect(back.workingHours, '8:00 AM - 6:00 PM');
  });

  test('numbers that come back as double still decode', () {
    final Map<String, dynamic> map = Codecs.estimateToMap(
      Estimate(
        id: '',
        requestId: 'r',
        mechanicId: 'm',
        mechanicName: 'n',
        amount: 500,
        etaMinutes: 10,
        createdAt: t,
        expiresAt: t,
      ),
    );
    map['amount'] = 500.0;
    expect(Codecs.estimateFromMap('e', map).amount, 500);
  });

  test('unknown enum names fall back instead of crashing', () {
    final Map<String, dynamic> map = Codecs.complaintToMap(
      Complaint(
        id: '',
        requestId: 'r1',
        customerId: 'c1',
        customerName: 'Ali',
        category: ComplaintCategory.noShow,
        description: 'Never arrived at all',
        createdAt: t,
      ),
    );
    map['category'] = 'somethingNew';
    map['status'] = 'weird';
    final Complaint back = Codecs.complaintFromMap('k1', map);
    expect(back.category, ComplaintCategory.other);
    expect(back.status, ComplaintStatus.open);
  });

  test('other models round trip', () {
    final AppNotification n = Codecs.notificationFromMap(
      'n1',
      Codecs.notificationToMap(
        AppNotification(
          id: '',
          userId: 'u1',
          title: 'Hi',
          body: 'Body',
          createdAt: t,
          requestId: 'r1',
        ),
      ),
    );
    expect(n.read, isFalse);
    expect(n.requestId, 'r1');

    final ChatMessage c = Codecs.messageFromMap(
      'c1',
      Codecs.messageToMap(
        ChatMessage(
          id: '',
          requestId: 'r1',
          senderId: 'u1',
          senderName: 'Ali',
          text: 'On my way',
          sentAt: t,
        ),
      ),
    );
    expect(c.text, 'On my way');
    expect(c.sentAt, t);

    final Review r = Codecs.reviewFromMap(
      Codecs.reviewToMap(
        Review(
          requestId: 'r1',
          customerId: 'u1',
          customerName: 'Ali',
          mechanicId: 'm1',
          rating: 5,
          comment: 'Great',
          createdAt: t,
        ),
      ),
    );
    expect(r.rating, 5);

    final MechanicApplication a = Codecs.applicationFromMap(
      'u5',
      Codecs.applicationToMap(
        MechanicApplication(
          userId: 'u5',
          name: 'Zahid',
          phone: '+923451112299',
          cnic: '3520112345671',
          experienceYears: 6,
          workshopAddress: 'Shop 12',
          services: const <ProblemType>{ProblemType.towing},
          vehicleTypes: const <VehicleType>{VehicleType.van},
          documents: const <String>['CNIC front', 'CNIC back'],
          submittedAt: t,
        ),
      ),
    );
    expect(a.userId, 'u5');
    expect(a.documents.length, 2);
    expect(a.services, <ProblemType>{ProblemType.towing});

    final AuditLog log = Codecs.auditFromMap(
      'a1',
      Codecs.auditToMap(
        AuditLog(
          id: '',
          adminId: 'u3',
          adminName: 'Sara',
          action: 'Blocked user',
          targetId: 'u6',
          createdAt: t,
          note: 'Spam',
        ),
      ),
    );
    expect(log.action, 'Blocked user');
    expect(log.note, 'Spam');
  });

  test('photo address survives a round trip', () {
    final ServiceRequest r = ServiceRequest(
      id: 'x',
      customerId: 'c1',
      customerName: 'Ali',
      vehicleId: 'v1',
      vehicleTitle: 'Suzuki Cultus',
      vehicleType: VehicleType.car,
      problem: ProblemType.flatTire,
      description: '',
      location: const LatLng(33.7, 73.05),
      address: 'F-10',
      photos: const <PhotoAttachment>[
        PhotoAttachment(name: 'a.jpg', sizeBytes: 10, url: 'https://x/a.jpg'),
        PhotoAttachment(name: 'b.jpg', sizeBytes: 20),
      ],
      status: RequestStatus.pending,
      createdAt: t,
      updatedAt: t,
    );
    final ServiceRequest back =
        Codecs.requestFromMap('x', Codecs.requestToMap(r));
    expect(back.photos[0].url, 'https://x/a.jpg');
    expect(back.photos[1].url, isNull);
  });
}
