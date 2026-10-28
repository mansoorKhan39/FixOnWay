import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/auth_scaffold.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/enums/user_role.dart';
import '../../routes/app_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AuthController>().clearError();
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final AuthController auth = context.read<AuthController>();
    final NavigatorState navigator = Navigator.of(context);
    final bool ok = await auth.login(_identifier.text, _password.text);
    if (ok && auth.user != null) {
      navigator.pushNamedAndRemoveUntil(
        AppRouter.homeFor(auth.user!),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final bool canSignUp = widget.role != UserRole.admin;
    return AuthScaffold(
      title: '${widget.role.label} login',
      subtitle: 'Welcome back. Log in to continue.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (auth.errorMessage != null)
              ErrorBanner(message: auth.errorMessage!),
            AppTextField(
              controller: _identifier,
              label: 'Phone or email',
              icon: Icons.person_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (String? v) => Validators.required(v, 'Phone or email'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _password,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (String? v) => Validators.required(v, 'Password'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.forgot),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Log in',
              isLoading: auth.isLoading,
              onPressed: _submit,
            ),
            if (canSignUp)
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamed(AppRouter.signup, arguments: widget.role),
                  child: const Text('New here? Create an account'),
                ),
              ),
            if (kDebugMode) const _DemoHint(),
          ],
        ),
      ),
    );
  }
}

class _DemoHint extends StatelessWidget {
  const _DemoHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Demo accounts (debug only)\n'
        'Customer: ali.raza@example.pk / Pass@1234\n'
        'Mechanic: usman@example.pk / Pass@1234\n'
        'Admin: sara.khan@fixonway.pk / Admin@1234',
        style: TextStyle(fontSize: 12, height: 1.5),
      ),
    );
  }
}
