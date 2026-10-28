import '../../models/app_notification.dart';
import '../../models/audit_log.dart';
import '../../models/chat_message.dart';
import '../../models/complaint.dart';
import '../../models/enums/complaint_category.dart';
import '../../models/enums/complaint_status.dart';
import '../../models/enums/estimate_status.dart';
import '../../models/enums/payment_method.dart';
import '../../models/enums/problem_type.dart';
import '../../models/enums/request_status.dart';
import '../../models/enums/vehicle_type.dart';
import '../../models/estimate.dart';
import '../../models/lat_lng.dart';
import '../../models/live_location.dart';
import '../../models/mechanic_application.dart';
import '../../models/mechanic_profile.dart';
import '../../models/photo_attachment.dart';
import '../../models/review.dart';
import '../../models/service_request.dart';

/// Converts models to and from the plain maps stored in Firestore.
///
/// This file has no Firebase imports, so it can be unit tested. Dates are
/// stored as milliseconds since the epoch.
class Codecs {
  Codecs._();

  static int ms(DateTime t) => t.millisecondsSinceEpoch;

  static DateTime time(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch((value as num).toInt());

  static DateTime? timeOrNull(Object? value) =>
      value == null ? null : time(value);

  static T pick<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final T v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  static T? pickOrNull<T extends Enum>(List<T> values, Object? name) {
    if (name == null) return null;
    for (final T v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static Set<ProblemType> problems(Object? list) => <ProblemType>{
        for (final Object? n in (list as List<Object?>? ?? <Object?>[]))
          if (pickOrNull(ProblemType.values, n) != null)
            pickOrNull(ProblemType.values, n)!,
      };

  static Set<VehicleType> vehicleTypes(Object? list) => <VehicleType>{
        for (final Object? n in (list as List<Object?>? ?? <Object?>[]))
          if (pickOrNull(VehicleType.values, n) != null)
            pickOrNull(VehicleType.values, n)!,
      };

  static LatLng latLng(Object? map) =>
      LatLng.fromMap(Map<String, dynamic>.from(map as Map<Object?, Object?>));

  static LatLng? latLngOrNull(Object? map) =>
      map == null ? null : latLng(map);

  static PhotoAttachment _photo(Map<Object?, Object?> p) => PhotoAttachment(
        name: p['name']! as String,
        sizeBytes: (p['sizeBytes']! as num).toInt(),
        url: p['url'] as String?,
      );

  // ---- service request ------------------------------------------------

  static Map<String, dynamic> requestToMap(ServiceRequest r) =>
      <String, dynamic>{
        'customerId': r.customerId,
        'customerName': r.customerName,
        'vehicleId': r.vehicleId,
        'vehicleTitle': r.vehicleTitle,
        'vehicleType': r.vehicleType.name,
        'problem': r.problem.name,
        'description': r.description,
        'location': r.location.toMap(),
        'address': r.address,
        'photos': <Map<String, dynamic>>[
          for (final PhotoAttachment p in r.photos)
            <String, dynamic>{
              'name': p.name,
              'sizeBytes': p.sizeBytes,
              if (p.url != null) 'url': p.url,
            },
        ],
        'status': r.status.name,
        'createdAt': ms(r.createdAt),
        'updatedAt': ms(r.updatedAt),
        'mechanicId': r.mechanicId,
        'mechanicName': r.mechanicName,
        'acceptedEstimateId': r.acceptedEstimateId,
        'agreedAmount': r.agreedAmount,
        'cancelReason': r.cancelReason,
        'etaMinutes': r.etaMinutes,
        'mechanicStart': r.mechanicStart?.toMap(),
        'startedAt': r.startedAt == null ? null : ms(r.startedAt!),
        'completedAt': r.completedAt == null ? null : ms(r.completedAt!),
        'paymentMethod': r.paymentMethod?.name,
        'paidAt': r.paidAt == null ? null : ms(r.paidAt!),
        'rejectedBy': r.rejectedBy.toList(),
      };

  static ServiceRequest requestFromMap(String id, Map<String, dynamic> m) {
    return ServiceRequest(
      id: id,
      customerId: m['customerId'] as String,
      customerName: m['customerName'] as String,
      vehicleId: m['vehicleId'] as String,
      vehicleTitle: m['vehicleTitle'] as String,
      vehicleType: pick(VehicleType.values, m['vehicleType'], VehicleType.car),
      problem: pick(ProblemType.values, m['problem'], ProblemType.other),
      description: (m['description'] as String?) ?? '',
      location: latLng(m['location']),
      address: (m['address'] as String?) ?? '',
      photos: <PhotoAttachment>[
        for (final Object? p in (m['photos'] as List<Object?>? ?? <Object?>[]))
          _photo(p as Map<Object?, Object?>),
      ],
      status: pick(RequestStatus.values, m['status'], RequestStatus.pending),
      createdAt: time(m['createdAt']),
      updatedAt: time(m['updatedAt']),
      mechanicId: m['mechanicId'] as String?,
      mechanicName: m['mechanicName'] as String?,
      acceptedEstimateId: m['acceptedEstimateId'] as String?,
      agreedAmount: (m['agreedAmount'] as num?)?.toInt(),
      cancelReason: m['cancelReason'] as String?,
      etaMinutes: (m['etaMinutes'] as num?)?.toInt(),
      mechanicStart: latLngOrNull(m['mechanicStart']),
      startedAt: timeOrNull(m['startedAt']),
      completedAt: timeOrNull(m['completedAt']),
      paymentMethod: pickOrNull(PaymentMethod.values, m['paymentMethod']),
      paidAt: timeOrNull(m['paidAt']),
      rejectedBy: <String>{
        for (final Object? s
            in (m['rejectedBy'] as List<Object?>? ?? <Object?>[]))
          s! as String,
      },
    );
  }

  // ---- estimate -------------------------------------------------------

  static Map<String, dynamic> estimateToMap(Estimate e) => <String, dynamic>{
        'requestId': e.requestId,
        'mechanicId': e.mechanicId,
        'mechanicName': e.mechanicName,
        'amount': e.amount,
        'etaMinutes': e.etaMinutes,
        'note': e.note,
        'createdAt': ms(e.createdAt),
        'expiresAt': ms(e.expiresAt),
        'status': e.status.name,
      };

  static Estimate estimateFromMap(String id, Map<String, dynamic> m) {
    return Estimate(
      id: id,
      requestId: m['requestId'] as String,
      mechanicId: m['mechanicId'] as String,
      mechanicName: m['mechanicName'] as String,
      amount: (m['amount'] as num).toInt(),
      etaMinutes: (m['etaMinutes'] as num).toInt(),
      note: (m['note'] as String?) ?? '',
      createdAt: time(m['createdAt']),
      expiresAt: time(m['expiresAt']),
      status: pick(EstimateStatus.values, m['status'], EstimateStatus.offered),
    );
  }

  // ---- mechanic profile -----------------------------------------------

  static Map<String, dynamic> mechanicToMap(MechanicProfile p) =>
      <String, dynamic>{
        'name': p.name,
        'phone': p.phone,
        'location': p.location.toMap(),
        'rating': p.rating,
        'reviewCount': p.reviewCount,
        'jobsDone': p.jobsDone,
        'experienceYears': p.experienceYears,
        'bio': p.bio,
        'services': p.services.map((ProblemType t) => t.name).toList(),
        'vehicleTypes': p.vehicleTypes.map((VehicleType t) => t.name).toList(),
        'isOnline': p.isOnline,
        'serviceRadiusKm': p.serviceRadiusKm,
        'workingHours': p.workingHours,
      };

  static MechanicProfile mechanicFromMap(String id, Map<String, dynamic> m) {
    return MechanicProfile(
      userId: id,
      name: m['name'] as String,
      phone: (m['phone'] as String?) ?? '',
      location: latLng(m['location']),
      rating: ((m['rating'] as num?) ?? 0).toDouble(),
      reviewCount: ((m['reviewCount'] as num?) ?? 0).toInt(),
      jobsDone: ((m['jobsDone'] as num?) ?? 0).toInt(),
      experienceYears: ((m['experienceYears'] as num?) ?? 0).toInt(),
      bio: (m['bio'] as String?) ?? '',
      services: problems(m['services']),
      vehicleTypes: vehicleTypes(m['vehicleTypes']),
      isOnline: (m['isOnline'] as bool?) ?? false,
      serviceRadiusKm: ((m['serviceRadiusKm'] as num?) ?? 10).toInt(),
      workingHours: (m['workingHours'] as String?) ?? '9:00 AM - 9:00 PM',
    );
  }

  // ---- notification ---------------------------------------------------

  static Map<String, dynamic> notificationToMap(AppNotification n) =>
      <String, dynamic>{
        'userId': n.userId,
        'title': n.title,
        'body': n.body,
        'createdAt': ms(n.createdAt),
        'read': n.read,
        'requestId': n.requestId,
      };

  static AppNotification notificationFromMap(
    String id,
    Map<String, dynamic> m,
  ) {
    return AppNotification(
      id: id,
      userId: m['userId'] as String,
      title: m['title'] as String,
      body: (m['body'] as String?) ?? '',
      createdAt: time(m['createdAt']),
      read: (m['read'] as bool?) ?? false,
      requestId: m['requestId'] as String?,
    );
  }

  // ---- chat -----------------------------------------------------------

  static Map<String, dynamic> messageToMap(ChatMessage c) => <String, dynamic>{
        'requestId': c.requestId,
        'senderId': c.senderId,
        'senderName': c.senderName,
        'text': c.text,
        'sentAt': ms(c.sentAt),
      };

  static ChatMessage messageFromMap(String id, Map<String, dynamic> m) {
    return ChatMessage(
      id: id,
      requestId: m['requestId'] as String,
      senderId: m['senderId'] as String,
      senderName: (m['senderName'] as String?) ?? '',
      text: (m['text'] as String?) ?? '',
      sentAt: time(m['sentAt']),
    );
  }

  // ---- review ---------------------------------------------------------

  static Map<String, dynamic> reviewToMap(Review r) => <String, dynamic>{
        'requestId': r.requestId,
        'customerId': r.customerId,
        'customerName': r.customerName,
        'mechanicId': r.mechanicId,
        'rating': r.rating,
        'comment': r.comment,
        'createdAt': ms(r.createdAt),
      };

  static Review reviewFromMap(Map<String, dynamic> m) {
    return Review(
      requestId: m['requestId'] as String,
      customerId: m['customerId'] as String,
      customerName: (m['customerName'] as String?) ?? '',
      mechanicId: m['mechanicId'] as String,
      rating: (m['rating'] as num).toInt(),
      comment: (m['comment'] as String?) ?? '',
      createdAt: time(m['createdAt']),
    );
  }

  // ---- complaint ------------------------------------------------------

  static Map<String, dynamic> complaintToMap(Complaint c) => <String, dynamic>{
        'requestId': c.requestId,
        'customerId': c.customerId,
        'customerName': c.customerName,
        'mechanicId': c.mechanicId,
        'mechanicName': c.mechanicName,
        'category': c.category.name,
        'description': c.description,
        'createdAt': ms(c.createdAt),
        'status': c.status.name,
        'resolution': c.resolution,
      };

  static Complaint complaintFromMap(String id, Map<String, dynamic> m) {
    return Complaint(
      id: id,
      requestId: m['requestId'] as String,
      customerId: m['customerId'] as String,
      customerName: (m['customerName'] as String?) ?? '',
      mechanicId: m['mechanicId'] as String?,
      mechanicName: m['mechanicName'] as String?,
      category:
          pick(ComplaintCategory.values, m['category'], ComplaintCategory.other),
      description: (m['description'] as String?) ?? '',
      createdAt: time(m['createdAt']),
      status: pick(ComplaintStatus.values, m['status'], ComplaintStatus.open),
      resolution: (m['resolution'] as String?) ?? '',
    );
  }

  // ---- mechanic application -------------------------------------------

  static Map<String, dynamic> applicationToMap(MechanicApplication a) =>
      <String, dynamic>{
        'name': a.name,
        'phone': a.phone,
        'cnic': a.cnic,
        'experienceYears': a.experienceYears,
        'workshopAddress': a.workshopAddress,
        'services': a.services.map((ProblemType t) => t.name).toList(),
        'vehicleTypes': a.vehicleTypes.map((VehicleType t) => t.name).toList(),
        'documents': a.documents,
        'submittedAt': ms(a.submittedAt),
      };

  static MechanicApplication applicationFromMap(
    String userId,
    Map<String, dynamic> m,
  ) {
    return MechanicApplication(
      userId: userId,
      name: m['name'] as String,
      phone: (m['phone'] as String?) ?? '',
      cnic: (m['cnic'] as String?) ?? '',
      experienceYears: ((m['experienceYears'] as num?) ?? 0).toInt(),
      workshopAddress: (m['workshopAddress'] as String?) ?? '',
      services: problems(m['services']),
      vehicleTypes: vehicleTypes(m['vehicleTypes']),
      documents: <String>[
        for (final Object? d in (m['documents'] as List<Object?>? ?? <Object?>[]))
          d! as String,
      ],
      submittedAt: time(m['submittedAt']),
    );
  }

  // ---- live location --------------------------------------------------

  static Map<String, dynamic> liveLocationToMap(LiveLocation l) =>
      <String, dynamic>{
        'lat': l.position.lat,
        'lng': l.position.lng,
        'updatedAt': ms(l.updatedAt),
      };

  static LiveLocation liveLocationFromMap(Map<String, dynamic> m) {
    return LiveLocation(
      position: LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()),
      updatedAt: time(m['updatedAt']),
    );
  }

  // ---- audit log ------------------------------------------------------

  static Map<String, dynamic> auditToMap(AuditLog a) => <String, dynamic>{
        'adminId': a.adminId,
        'adminName': a.adminName,
        'action': a.action,
        'targetId': a.targetId,
        'createdAt': ms(a.createdAt),
        'note': a.note,
      };

  static AuditLog auditFromMap(String id, Map<String, dynamic> m) {
    return AuditLog(
      id: id,
      adminId: m['adminId'] as String,
      adminName: (m['adminName'] as String?) ?? '',
      action: m['action'] as String,
      targetId: (m['targetId'] as String?) ?? '',
      createdAt: time(m['createdAt']),
      note: (m['note'] as String?) ?? '',
    );
  }
}
