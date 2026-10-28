import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/customer_controller.dart';
import '../../controllers/mechanic_controller.dart';
import '../../routes/app_router.dart';

/// UC-07: ends the session and returns to the login screen.
Future<void> performLogout(BuildContext context) async {
  final AuthController auth = context.read<AuthController>();
  final CustomerController customer = context.read<CustomerController>();
  final MechanicController mechanic = context.read<MechanicController>();
  final ChatController chat = context.read<ChatController>();
  final AdminController admin = context.read<AdminController>();
  final NavigatorState navigator = Navigator.of(context);
  await auth.logout();
  customer.clear();
  mechanic.clear();
  chat.reset();
  admin.clear();
  navigator.pushNamedAndRemoveUntil(
    AppRouter.login,
    (Route<dynamic> route) => false,
  );
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Logout',
      icon: const Icon(Icons.logout),
      onPressed: () => performLogout(context),
    );
  }
}
