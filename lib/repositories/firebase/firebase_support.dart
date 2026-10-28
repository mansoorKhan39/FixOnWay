import 'package:firebase_core/firebase_core.dart';

import '../../core/errors/app_exception.dart';

/// Collection names used in Firestore.
class Col {
  Col._();

  static const String users = 'users';
  static const String requests = 'requests';
  static const String estimates = 'estimates';
  static const String mechanics = 'mechanics';
  static const String notifications = 'notifications';
  static const String vehicles = 'vehicles';
  static const String messages = 'messages';
  static const String reviews = 'reviews';
  static const String complaints = 'complaints';
  static const String applications = 'applications';
  static const String auditLogs = 'auditLogs';
  static const String liveLocations = 'liveLocations';
}

/// Runs a Firestore call and turns Firebase errors into messages the
/// screens can show.
Future<T> guardFirebase<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on AppException {
    rethrow;
  } on FirebaseException catch (e) {
    throw AppException(_describe(e));
  }
}

String _describe(FirebaseException e) {
  switch (e.code) {
    case 'permission-denied':
      return 'The database refused this action. Check your Firestore rules '
          '(see firestore.rules in the project).';
    case 'unavailable':
    case 'network-request-failed':
      return 'Cannot reach the server. Check your internet connection.';
    case 'failed-precondition':
      return 'The database needs setup: ${e.message ?? e.code}';
    case 'not-found':
      return 'Firestore database not found. Create it in the Firebase '
          'console (Build > Firestore Database > Create database).';
    default:
      return 'Database error (${e.code}).';
  }
}
