import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../models/app_user.dart';
import '../models/audit_log.dart';
import '../models/complaint.dart';
import '../models/enums/request_status.dart';
import '../models/enums/user_role.dart';
import '../models/mechanic_application.dart';
import '../models/service_request.dart';
import '../services/admin_service.dart';

/// State for the admin screens (Observer pattern via [ChangeNotifier]).
class AdminController extends ChangeNotifier {
  AdminController(this._service);

  final AdminService _service;

  AppUser? _admin;
  List<MechanicApplication> _applications = <MechanicApplication>[];
  List<AppUser> _users = <AppUser>[];
  List<ServiceRequest> _requests = <ServiceRequest>[];
  List<Complaint> _complaints = <Complaint>[];
  List<AuditLog> _activity = <AuditLog>[];
  Report? _report;
  bool _isLoading = false;
  String? _errorMessage;

  // Filters kept here so tabs keep their state.
  UserRole? _userRole;
  String _userQuery = '';
  RequestStatus? _requestStatus;
  int? _reportDays = 7;

  List<MechanicApplication> get applications => _applications;
  List<AppUser> get users => _users;
  List<ServiceRequest> get requests => _requests;
  List<Complaint> get complaints => _complaints;
  List<AuditLog> get activity => _activity;
  Report? get report => _report;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserRole? get userRole => _userRole;
  RequestStatus? get requestStatus => _requestStatus;
  int? get reportDays => _reportDays;

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    Future<void>.microtask(notifyListeners);
  }

  void clear() {
    _admin = null;
    _applications = <MechanicApplication>[];
    _users = <AppUser>[];
    _requests = <ServiceRequest>[];
    _complaints = <Complaint>[];
    _activity = <AuditLog>[];
    _report = null;
    _userRole = null;
    _userQuery = '';
    _requestStatus = null;
    _reportDays = 7;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadAll() async {
    _applications = await _service.applications();
    _users = await _service.users(role: _userRole, query: _userQuery);
    _requests = await _service.requests(status: _requestStatus);
    _complaints = await _service.complaints();
    _activity = await _service.recentActivity();
    _report = await _service.report(days: _reportDays);
  }

  Future<bool> load(AppUser admin) {
    _admin = admin;
    return _run(_reloadAll);
  }

  Future<void> refresh() async {
    if (_admin == null) return;
    try {
      await _reloadAll();
      notifyListeners();
    } catch (_) {
      // Keep the old data when a background refresh fails.
    }
  }

  // UC-39
  Future<bool> setReportDays(int? days) {
    _reportDays = days;
    return _run(() async {
      _report = await _service.report(days: days);
    });
  }

  // UC-36
  Future<bool> filterUsers({UserRole? role, String? query}) {
    _userRole = role;
    if (query != null) _userQuery = query;
    return _run(() async {
      _users = await _service.users(role: _userRole, query: _userQuery);
    });
  }

  // UC-37
  Future<bool> filterRequests(RequestStatus? status) {
    _requestStatus = status;
    return _run(() async {
      _requests = await _service.requests(status: status);
    });
  }

  Future<AdminRequestView?> requestView(String id) async {
    try {
      return await _service.requestView(id);
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  // UC-34
  Future<bool> approve(String userId) {
    return _run(() async {
      await _service.approveMechanic(_admin!, userId);
      await _reloadAll();
    });
  }

  Future<bool> reject(String userId, String reason) {
    return _run(() async {
      await _service.rejectMechanic(_admin!, userId, reason);
      await _reloadAll();
    });
  }

  // UC-35
  Future<bool> block(String userId, String reason) {
    return _run(() async {
      await _service.blockUser(_admin!, userId, reason);
      await _reloadAll();
    });
  }

  Future<bool> unblock(String userId) {
    return _run(() async {
      await _service.unblockUser(_admin!, userId);
      await _reloadAll();
    });
  }

  // UC-38
  Future<bool> resolveComplaint(
    String complaintId, {
    required bool upheld,
    required String resolution,
  }) {
    return _run(() async {
      await _service.resolveComplaint(
        admin: _admin!,
        complaintId: complaintId,
        upheld: upheld,
        resolution: resolution,
      );
      await _reloadAll();
    });
  }
}
