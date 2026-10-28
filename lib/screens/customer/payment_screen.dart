import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/section_card.dart';
import '../../models/enums/payment_method.dart';
import '../../models/service_request.dart';

/// UC-18: pay for the service.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _account = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    context.read<CustomerController>().clearError();
  }

  @override
  void dispose() {
    _account.dispose();
    super.dispose();
  }

  IconData _icon(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.jazzcash => Icons.account_balance_wallet_outlined,
        PaymentMethod.easypaisa => Icons.phone_android,
      };

  Future<void> _pay() async {
    if (_method.isWallet && !_form.currentState!.validate()) return;
    final CustomerController c = context.read<CustomerController>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await c.pay(
      widget.requestId,
      _method,
      account: _method.isWallet ? _account.text : null,
    );
    if (!ok) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _method.isWallet
              ? 'Payment successful.'
              : 'Please hand the cash to your mechanic. They will confirm it.',
        ),
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final CustomerController c = context.watch<CustomerController>();
    final ServiceRequest? r = c.requestById(widget.requestId);
    return Scaffold(
      appBar: AppBar(title: const Text('Pay for service')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                if (c.errorMessage != null)
                  ErrorBanner(message: c.errorMessage!),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Amount to pay',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      Text(
                        formatMoney(r?.agreedAmount ?? 0),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      if (r != null)
                        Text(
                          '${r.problem.label} - ${r.mechanicName ?? ''}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                const Text(
                  'Payment method',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final PaymentMethod m in PaymentMethod.values)
                  SectionCard(
                    onTap: () => setState(() => _method = m),
                    child: Row(
                      children: <Widget>[
                        Icon(_icon(m), color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(m.label)),
                        Icon(
                          _method == m
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: _method == m
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                if (_method.isWallet)
                  Form(
                    key: _form,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _account,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: '${_method.label} number',
                          hintText: '0300 1234567',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: Validators.phone,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: _method.isWallet ? 'Pay now' : 'Pay with cash',
                  isLoading: c.isLoading,
                  onPressed: _pay,
                ),
                if (_method.isWallet)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Demo: wallet payments are simulated. The number '
                      '0300 0000000 always fails.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
