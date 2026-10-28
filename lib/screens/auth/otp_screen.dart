import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/auth_scaffold.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/enums/otp_purpose.dart';
import '../../routes/app_router.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.purpose});

  final OtpPurpose purpose;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _code = TextEditingController();
  Timer? _timer;
  int _secondsLeft = AppConstants.otpResendWait.inSeconds;

  @override
  void initState() {
    super.initState();
    context.read<AuthController>().clearError();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = AppConstants.otpResendWait.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (_secondsLeft <= 1) {
        t.cancel();
      }
      if (mounted) setState(() => _secondsLeft--);
    });
  }

  Future<void> _verify() async {
    if (!_form.currentState!.validate()) return;
    final AuthController auth = context.read<AuthController>();
    final NavigatorState navigator = Navigator.of(context);
    if (widget.purpose == OtpPurpose.registration) {
      final bool ok = await auth.completeRegistration(_code.text);
      if (ok && auth.user != null) {
        navigator.pushNamedAndRemoveUntil(
          AppRouter.homeFor(auth.user!),
          (Route<dynamic> route) => false,
        );
      }
    } else {
      final bool ok = await auth.confirmResetOtp(_code.text);
      if (ok) navigator.pushReplacementNamed(AppRouter.reset);
    }
  }

  Future<void> _resend() async {
    final AuthController auth = context.read<AuthController>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await auth.resendOtp();
    if (ok) {
      _startTimer();
      messenger.showSnackBar(
        const SnackBar(content: Text('A new code has been sent.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final bool canResend = _secondsLeft <= 0 && !auth.isLoading;
    return AuthScaffold(
      title: 'Verify your phone',
      subtitle: 'Enter the ${AppConstants.otpLength}-digit code sent to '
          '${auth.otpPhone ?? 'your phone'}.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (auth.errorMessage != null)
              ErrorBanner(message: auth.errorMessage!),
            AppTextField(
              controller: _code,
              label: 'Verification code',
              icon: Icons.sms_outlined,
              keyboardType: TextInputType.number,
              maxLength: AppConstants.otpLength,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _verify(),
              validator: Validators.otp,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Verify',
              isLoading: auth.isLoading,
              onPressed: _verify,
            ),
            Center(
              child: TextButton(
                onPressed: canResend ? _resend : null,
                child: Text(
                  _secondsLeft > 0
                      ? 'Resend code in ${_secondsLeft}s'
                      : 'Resend code',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
