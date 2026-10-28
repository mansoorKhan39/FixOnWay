import '../core/errors/app_exception.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/audit_log.dart';
import '../models/complaint.dart';
import '../models/enums/complaint_status.dart';
import '../models/enums/payment_method.dart';
import '../models/enums/problem_type.dart';
import '../models/enums/request_status.dart';
import '../models/enums/user_role.dart';
import '../models/enums/user_status.dart';
import '../models/estimate.dart';
import '../models/mechanic_application.dart';
import '../models/mechanic_profile.dart';
import '../models/review.dart';
import '../models/service_request.dart';
import '../repositories/application_repository.dart';
import '../repositories/audit_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/request_repository.dart';
import '../repositories/review_repository.dart';
import 'mechanic_service.dart';

/// One bar of the "requests in the last 7 days" chart.
class DayCount {
  const DayCount(this.day, this.count);

  final DateTime day;
  final int count;
}

/// A row of the "top mechanics" table.
class MechanicStat {
  const MechanicStat({
    required this.mechanicId,
    required this.name,
    required this.jobs,
    required this.earnings,
    required this.rating,
  });

  final String mechanicId;
  final String name;
  final int jobs;
  final int earnings;
  final double rating;
}

/// UC-39: numbers for the admin overview.
class Report {
  const Report({
    required this.customers,
    required this.mechanics,
    required this.onlineMechanics,
    required this.totalRequests,
    required this.finishedJobs,
    required this.lostRequests,
    required this.revenue,
    required this.averageRating,
    required this.openComplaints,
    required this.byStatus,
    required this.byProblem,
    required this.last7Days,
    required this.topMechanics,
  });

  final int customers;
  final int mechanics;
  final int onlineMechanics;
  final int totalRequests;

  /// Paid or closed after payment.
  final int finishedJobs;

  /// Cancelled or expired.
  final int lostRequests;

  /// Sum of the agreed price of paid jobs (PKR).
  final int revenue;
  final double averageRating;
  final int openComplaints;
  final Map<RequestStatus, int> byStatus;
  final Map<ProblemType, int> byProblem;
  final List<DayCount> last7Days;
  final List<MechanicStat> topMechanics;
}

/// Everything an admin sees about one request (UC-37).
class AdminRequestView {
  const AdminRequestView({
    required this.request,
    required this.estimates,
    required this.complaints,
    this.review,
  });

  final ServiceRequest request;
  final List<Estimate> estimates;
  final List<Complaint> complaints;
  final Review? review;
}

/// Admin tasks: UC-34 to UC-39.
class AdminService {
  AdminService(
    this._auth,
    this._requests,
    this._reviews,
    this._applications,
    this._audit,
    this._mechanics, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AuthRepository _auth;
  final RequestRepository _requests;
  final ReviewRepository _reviews;
  final ApplicationRepository _applications;
  final AuditRepository _audit;
  final MechanicService _mechanics;
  final DateTime Function() _now;

  Future<void> _log(AppUser admin, String action, String target, String note) {
    return _audit.add(
      AuditLog(
        id: '',
        adminId: admin.id,
        adminName: admin.name,
        action: action,
        targetId: target,
        createdAt: _now(),
        note: note,
      ),
    );
  }

  void _mustBeAdmin(AppUser admin) {
    if (admin.role != UserRole.admin) {
      throw const AppException('Only admins can do this.');
    }
  }

  Future<List<AuditLog>> recentActivity({int limit = 20}) =>
      _audit.recent(limit: limit);

  // ---- UC-34 mechanic verification ------------------------------------

  Future<List<MechanicApplication>> applications() async {
    final List<MechanicApplication> list = await _applications.all();
    list.sort(
      (MechanicApplication a, MechanicApplication b) =>
          a.submittedAt.compareTo(b.submittedAt),
    );
    return list;
  }

  Future<void> approveMechanic(AppUser admin, String userId) async {
    _mustBeAdmin(admin);
    await _mechanics.approve(userId);
    await _log(admin, 'Approved mechanic', userId, '');
  }

  Future<void> rejectMechanic(AppUser admin, String userId, String reason) async {
    _mustBeAdmin(admin);
    await _mechanics.reject(userId, reason);
    await _log(admin, 'Rejected mechanic', userId, reason.trim());
  }

  // ---- UC-35 / UC-36 users --------------------------------------------

  /// Customers and mechanics, optionally filtered. [query] matches name,
  /// phone or email.
  Future<List<AppUser>> users({UserRole? role, String query = ''}) async {
    final String q = query.trim().toLowerCase();
    final List<AppUser> all = await _auth.allUsers();
    final List<AppUser> list = all.where((AppUser u) {
      if (u.role == UserRole.admin) return false;
      if (role != null && u.role != role) return false;
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) ||
          u.phone.contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();
    list.sort((AppUser a, AppUser b) => a.name.compareTo(b.name));
    return list;
  }

  Future<AppUser> blockUser(AppUser admin, String userId, String reason) async {
    _mustBeAdmin(admin);
    if (userId == admin.id) {
      throw const AppException('You cannot block your own account.');
    }
    if (reason.trim().length < 3) {
      throw const AppException('Please give a reason for blocking.');
    }
    final AppUser? target = await _find(userId);
    if (target == null) throw const AppException('Account not found.');
    if (target.role == UserRole.admin) {
      throw const AppException('Admin accounts cannot be blocked.');
    }
    if (target.isBlocked) {
      throw const AppException('This account is already blocked.');
    }

    final AppUser updated = await _auth.setUserStatus(
      userId: userId,
      status: UserStatus.blocked,
    );
    if (target.role == UserRole.mechanic) {
      final MechanicProfile? profile = await _requests.mechanic(userId);
      if (profile != null && profile.isOnline) {
        await _requests.saveMechanic(profile.copyWith(isOnline: false));
      }
    } else {
      final List<ServiceRequest> mine = await _requests.byCustomer(userId);
      for (final ServiceRequest r in mine) {
        if (r.status.canMoveTo(RequestStatus.cancelled)) {
          await _requests.update(
            r.copyWith(
              status: RequestStatus.cancelled,
              updatedAt: _now(),
              cancelReason: 'Account suspended',
            ),
          );
        }
      }
    }
    await _log(admin, 'Blocked user', userId, reason.trim());
    return updated;
  }

  Future<AppUser> unblockUser(AppUser admin, String userId) async {
    _mustBeAdmin(admin);
    final AppUser? target = await _find(userId);
    if (target == null) throw const AppException('Account not found.');
    if (!target.isBlocked) {
      throw const AppException('This account is not blocked.');
    }
    final AppUser updated = await _auth.setUserStatus(
      userId: userId,
      status: UserStatus.active,
    );
    await _log(admin, 'Unblocked user', userId, '');
    return updated;
  }

  Future<AppUser?> _find(String userId) async {
    final List<AppUser> all = await _auth.allUsers();
    for (final AppUser u in all) {
      if (u.id == userId) return u;
    }
    return null;
  }

  // ---- UC-37 monitor requests -----------------------------------------

  Future<List<ServiceRequest>> requests({RequestStatus? status}) async {
    final List<ServiceRequest> all = await _requests.all();
    if (status == null) return all;
    return all.where((ServiceRequest r) => r.status == status).toList();
  }

  Future<AdminRequestView> requestView(String requestId) async {
    final ServiceRequest? r = await _requests.byId(requestId);
    if (r == null) throw const AppException('Request not found.');
    return AdminRequestView(
      request: r,
      estimates: await _requests.estimatesFor(requestId),
      complaints: await _reviews.complaintsOfRequest(requestId),
      review: await _reviews.reviewFor(requestId),
    );
  }

  // ---- UC-38 complaints -----------------------------------------------

  Future<List<Complaint>> complaints({ComplaintStatus? status}) async {
    final List<Complaint> all = await _reviews.allComplaints();
    if (status == null) return all;
    return all.where((Complaint c) => c.status == status).toList();
  }

  /// [upheld] true: the customer was right (request closed, no payment to the
  /// mechanic). false: the complaint is dismissed (the job counts as paid).
  Future<Complaint> resolveComplaint({
    required AppUser admin,
    required String complaintId,
    required bool upheld,
    required String resolution,
  }) async {
    _mustBeAdmin(admin);
    if (resolution.trim().length < 5) {
      throw const AppException('Please write a short decision note.');
    }
    final List<Complaint> all = await _reviews.allComplaints();
    Complaint? complaint;
    for (final Complaint c in all) {
      if (c.id == complaintId) complaint = c;
    }
    if (complaint == null) throw const AppException('Complaint not found.');
    if (complaint.status != ComplaintStatus.open) {
      throw const AppException('This complaint is already handled.');
    }

    final DateTime now = _now();
    final Complaint updated = complaint.resolve(
      upheld ? ComplaintStatus.resolved : ComplaintStatus.rejected,
      resolution.trim(),
    );
    await _reviews.updateComplaint(updated);

    final ServiceRequest? r = await _requests.byId(complaint.requestId);
    if (r != null && r.status == RequestStatus.disputed) {
      if (upheld) {
        await _requests.update(
          r.copyWith(status: RequestStatus.closed, updatedAt: now),
        );
      } else {
        await _requests.update(
          r.copyWith(
            status: RequestStatus.paid,
            updatedAt: now,
            paidAt: now,
            paymentMethod: r.paymentMethod ?? PaymentMethod.cash,
          ),
        );
        if (r.mechanicId != null) {
          final MechanicProfile? m = await _requests.mechanic(r.mechanicId!);
          if (m != null) {
            await _requests.saveMechanic(m.copyWith(jobsDone: m.jobsDone + 1));
          }
        }
      }
    }

    final String verdict = upheld ? 'upheld' : 'dismissed';
    await _requests.addNotification(
      AppNotification(
        id: '',
        userId: complaint.customerId,
        title: 'Complaint $verdict',
        body: resolution.trim(),
        createdAt: now,
        requestId: complaint.requestId,
      ),
    );
    if (complaint.mechanicId != null) {
      await _requests.addNotification(
        AppNotification(
          id: '',
          userId: complaint.mechanicId!,
          title: 'A complaint about you was $verdict',
          body: resolution.trim(),
          createdAt: now,
          requestId: complaint.requestId,
        ),
      );
    }
    await _log(admin, 'Complaint $verdict', complaintId, resolution.trim());
    return updated;
  }

  // ---- UC-39 reports --------------------------------------------------

  /// [days] limits the request numbers to the last N days; null means all time.
  Future<Report> report({int? days}) async {
    final DateTime now = _now();
    final DateTime? since = days == null ? null : now.subtract(Duration(days: days));

    final List<AppUser> users = await _auth.allUsers();
    final List<MechanicProfile> profiles = await _requests.mechanics();
    final List<ServiceRequest> everything = await _requests.all();
    final List<ServiceRequest> inRange = everything
        .where((ServiceRequest r) => since == null || !r.createdAt.isBefore(since))
        .toList();
    final List<Complaint> complaints = await _reviews.allComplaints();

    final Map<RequestStatus, int> byStatus = <RequestStatus, int>{};
    final Map<ProblemType, int> byProblem = <ProblemType, int>{};
    int finished = 0;
    int lost = 0;
    int revenue = 0;
    final Map<String, int> jobsBy = <String, int>{};
    final Map<String, int> moneyBy = <String, int>{};

    for (final ServiceRequest r in inRange) {
      byStatus[r.status] = (byStatus[r.status] ?? 0) + 1;
      byProblem[r.problem] = (byProblem[r.problem] ?? 0) + 1;
      if (r.status == RequestStatus.cancelled ||
          r.status == RequestStatus.expired) {
        lost++;
      }
      final bool paid = r.paidAt != null &&
          (r.status == RequestStatus.paid || r.status == RequestStatus.closed);
      if (paid) {
        finished++;
        revenue += r.agreedAmount ?? 0;
        if (r.mechanicId != null) {
          jobsBy[r.mechanicId!] = (jobsBy[r.mechanicId!] ?? 0) + 1;
          moneyBy[r.mechanicId!] =
              (moneyBy[r.mechanicId!] ?? 0) + (r.agreedAmount ?? 0);
        }
      }
    }

    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<DayCount> week = <DayCount>[];
    for (int i = 6; i >= 0; i--) {
      final DateTime day = today.subtract(Duration(days: i));
      final DateTime next = day.add(const Duration(days: 1));
      final int count = everything
          .where(
            (ServiceRequest r) =>
                !r.createdAt.isBefore(day) && r.createdAt.isBefore(next),
          )
          .length;
      week.add(DayCount(day, count));
    }

    final List<MechanicStat> top = <MechanicStat>[];
    for (final MapEntry<String, int> e in jobsBy.entries) {
      MechanicProfile? p;
      for (final MechanicProfile m in profiles) {
        if (m.userId == e.key) p = m;
      }
      top.add(
        MechanicStat(
          mechanicId: e.key,
          name: p?.name ?? e.key,
          jobs: e.value,
          earnings: moneyBy[e.key] ?? 0,
          rating: p?.rating ?? 0,
        ),
      );
    }
    top.sort((MechanicStat a, MechanicStat b) => b.earnings.compareTo(a.earnings));

    final List<MechanicProfile> rated =
        profiles.where((MechanicProfile m) => m.reviewCount > 0).toList();
    final double average = rated.isEmpty
        ? 0
        : rated.fold<double>(0, (double sum, MechanicProfile m) => sum + m.rating) /
            rated.length;

    return Report(
      customers: users.where((AppUser u) => u.role == UserRole.customer).length,
      mechanics: users.where((AppUser u) => u.role == UserRole.mechanic).length,
      onlineMechanics: profiles.where((MechanicProfile m) => m.isOnline).length,
      totalRequests: inRange.length,
      finishedJobs: finished,
      lostRequests: lost,
      revenue: revenue,
      averageRating: average,
      openComplaints:
          complaints.where((Complaint c) => c.status == ComplaintStatus.open).length,
      byStatus: byStatus,
      byProblem: byProblem,
      last7Days: week,
      topMechanics: top.take(5).toList(),
    );
  }
}
