import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/auth_scaffold.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/enums/user_role.dart';
import '../../models/registration_draft.dart';
import '../../routes/app_router.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _accepted = false;
  String? _termsError;

  @override
  void initState() {
    super.initState();
    context.read<AuthController>().clearError();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bool valid = _form.currentState!.validate();
    setState(() {
      _termsError = _accepted ? null : 'Please accept the terms to continue';
    });
    if (!valid || !_accepted) return;

    final AuthController auth = context.read<AuthController>();
    final NavigatorState navigator = Navigator.of(context);
    final bool ok = await auth.register(
      RegistrationDraft(
        role: widget.role,
        name: _name.text.trim(),
        phone: _phone.text,
        email: _email.text,
        password: _password.text,
      ),
    );
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
    return AuthScaffold(
      title: 'Create ${widget.role.label.toLowerCase()} account',
      subtitle: 'Fill in your details to get started.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (auth.errorMessage != null)
              ErrorBanner(message: auth.errorMessage!),
            AppTextField(
              controller: _name,
              label: 'Full name',
              icon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: Validators.name,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _phone,
              label: 'Phone number',
              hint: '0300 1234567',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: Validators.phone,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _email,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _password,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: true,
              textInputAction: TextInputAction.next,
              validator: Validators.password,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _confirm,
              label: 'Confirm password',
              icon: Icons.lock_outline,
              obscure: true,
              textInputAction: TextInputAction.done,
              validator: (String? v) =>
                  Validators.confirmPassword(v, _password.text),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _accepted,
              onChanged: (bool? v) => setState(() => _accepted = v ?? false),
              title: const Text('I accept the Terms and Privacy Policy'),
            ),
            if (_termsError != null)
              Text(
                _termsError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Create account',
              isLoading: auth.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
