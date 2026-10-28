import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/auth_scaffold.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/enums/user_role.dart';
import '../../routes/app_router.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AuthController>().clearError();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final AuthController auth = context.read<AuthController>();
    final bool ok = await auth.completePasswordReset(_password.text);
    if (!ok || !mounted) return;
    final NavigatorState navigator = Navigator.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Password reset'),
        content: Text(auth.resetMessage),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Log in'),
          ),
        ],
      ),
    );
    navigator.pushNamedAndRemoveUntil(
      AppRouter.login,
      (Route<dynamic> route) => false,
      arguments: UserRole.customer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    return AuthScaffold(
      title: 'Set a new password',
      subtitle: 'Choose a password with at least 8 characters.',
      showBack: false,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (auth.errorMessage != null)
              ErrorBanner(message: auth.errorMessage!),
            AppTextField(
              controller: _password,
              label: 'New password',
              icon: Icons.lock_outline,
              obscure: true,
              textInputAction: TextInputAction.next,
              validator: Validators.password,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _confirm,
              label: 'Confirm new password',
              icon: Icons.lock_outline,
              obscure: true,
              textInputAction: TextInputAction.done,
              validator: (String? v) =>
                  Validators.confirmPassword(v, _password.text),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Update password',
              isLoading: auth.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
