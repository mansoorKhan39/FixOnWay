import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/mechanic_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/logout_button.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/enums/verification_status.dart';
import '../../routes/app_router.dart';

/// Shown to a mechanic until an admin verifies the account (UC-23, UC-34).
class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  State<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AuthController auth = context.read<AuthController>();
      if (auth.user != null) {
        context.read<MechanicController>().load(auth.user!);
      }
    });
  }

  Future<void> _approveMyself() async {
    final MechanicController c = context.read<MechanicController>();
    final AuthController auth = context.read<AuthController>();
    final NavigatorState navigator = Navigator.of(context);
    final bool ok = await c.approveMyself();
    if (!ok) return;
    auth.refreshUser();
    if (auth.user != null) {
      navigator.pushNamedAndRemoveUntil(
        AppRouter.homeFor(auth.user!),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final MechanicController c = context.watch<MechanicController>();
    final bool rejected =
        auth.user?.verificationStatus == VerificationStatus.rejected;
    final bool submitted = c.application != null;

    final IconData icon;
    final String title;
    final String text;
    if (submitted) {
      icon = Icons.hourglass_top;
      title = 'Under review';
      text = 'We received your details. An admin will verify your account soon.';
    } else if (rejected) {
      icon = Icons.error_outline;
      title = 'Verification rejected';
      text = 'Please check the reason in your notifications, fix your details '
          'and submit again.';
    } else {
      icon = Icons.assignment_ind_outlined;
      title = 'One more step';
      text = 'Send your CNIC, workshop and service details so we can verify '
          'your account.';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification'),
        actions: const <Widget>[LogoutButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 72, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Hello, ${auth.user?.firstName ?? ''}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                if (!submitted)
                  PrimaryButton(
                    label: 'Submit my details',
                    onPressed: () => Navigator.of(context)
                        .pushNamed(AppRouter.verificationForm),
                  ),
                if (submitted && kDebugMode)
                  TextButton(
                    onPressed: c.isLoading ? null : _approveMyself,
                    child: const Text('Demo: approve my account'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
