import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/enums/otp_purpose.dart';
import '../models/enums/problem_type.dart';
import '../models/enums/user_role.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_profile_screen.dart';
import '../screens/admin/admin_request_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/customer/complaint_screen.dart';
import '../screens/customer/create_request_screen.dart';
import '../screens/customer/customer_home_screen.dart';
import '../screens/customer/mechanic_profile_screen.dart';
import '../screens/customer/payment_screen.dart';
import '../screens/customer/request_detail_screen.dart';
import '../screens/customer/review_screen.dart';
import '../screens/customer/vehicles_screen.dart';
import '../screens/mechanic/job_screen.dart';
import '../screens/mechanic/mechanic_dashboard_screen.dart';
import '../screens/mechanic/service_area_screen.dart';
import '../screens/mechanic/verification_form_screen.dart';
import '../screens/mechanic/verification_pending_screen.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String role = '/role';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String otp = '/otp';
  static const String forgot = '/forgot';
  static const String reset = '/reset';
  static const String customerHome = '/home/customer';
  static const String mechanicHome = '/home/mechanic';
  static const String mechanicPending = '/mechanic/pending';
  static const String adminHome = '/home/admin';
  static const String createRequest = '/customer/request/new';
  static const String requestDetail = '/customer/request';
  static const String vehicles = '/customer/vehicles';
  static const String mechanicProfile = '/customer/mechanic';
  static const String payment = '/customer/pay';
  static const String review = '/customer/review';
  static const String complaint = '/customer/complaint';
  static const String chat = '/chat';
  static const String mechanicJob = '/mechanic/job';
  static const String serviceArea = '/mechanic/area';
  static const String verificationForm = '/mechanic/verify';
  static const String adminRequest = '/admin/request';
  static const String adminProfile = '/admin/profile';

  /// The first screen after a successful login or sign-up.
  static String homeFor(AppUser user) {
    return switch (user.role) {
      UserRole.customer => customerHome,
      UserRole.mechanic =>
        user.isPendingVerification ? mechanicPending : mechanicHome,
      UserRole.admin => adminHome,
    };
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Object? args = settings.arguments;
    final Widget page;
    switch (settings.name) {
      case onboarding:
        page = const OnboardingScreen();
      case role:
        page = const RoleSelectionScreen();
      case login:
        page = LoginScreen(role: args is UserRole ? args : UserRole.customer);
      case signup:
        page = SignUpScreen(role: args is UserRole ? args : UserRole.customer);
      case otp:
        page = OtpScreen(
          purpose: args is OtpPurpose ? args : OtpPurpose.registration,
        );
      case forgot:
        page = const ForgotPasswordScreen();
      case reset:
        page = const ResetPasswordScreen();
      case createRequest:
        page = CreateRequestScreen(
          initialProblem: args is ProblemType ? args : null,
        );
      case requestDetail:
        page = RequestDetailScreen(requestId: args is String ? args : '');
      case vehicles:
        page = const VehiclesScreen();
      case mechanicProfile:
        page = MechanicProfileScreen(mechanicId: args is String ? args : '');
      case payment:
        page = PaymentScreen(requestId: args is String ? args : '');
      case review:
        page = ReviewScreen(requestId: args is String ? args : '');
      case complaint:
        page = ComplaintScreen(requestId: args is String ? args : '');
      case chat:
        page = ChatScreen(
          args: args is ChatArgs ? args : const ChatArgs('', 'Chat'),
        );
      case mechanicJob:
        page = MechanicJobScreen(requestId: args is String ? args : '');
      case serviceArea:
        page = const ServiceAreaScreen();
      case verificationForm:
        page = const VerificationFormScreen();
      case customerHome:
        page = const CustomerHomeScreen();
      case mechanicHome:
        page = const MechanicDashboardScreen();
      case mechanicPending:
        page = const VerificationPendingScreen();
      case adminHome:
        page = const AdminDashboardScreen();
      case adminRequest:
        page = AdminRequestScreen(requestId: args is String ? args : '');
      case adminProfile:
        page = const AdminProfileScreen();
      case splash:
      default:
        page = const SplashScreen();
    }
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => page,
      settings: settings,
    );
  }
}
