import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/enums/complaint_category.dart';

/// UC-22: submit a complaint about a job.
class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _text = TextEditingController();
  ComplaintCategory _category = ComplaintCategory.overcharged;

  @override
  void initState() {
    super.initState();
    context.read<CustomerController>().clearError();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final int length = (value ?? '').trim().length;
    if (length < AppConstants.minComplaintLength) {
      return 'Please write at least ${AppConstants.minComplaintLength} characters';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final CustomerController c = context.read<CustomerController>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await c.submitComplaint(
      widget.requestId,
      _category,
      _text.text,
    );
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Complaint submitted.')),
      );
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final CustomerController c = context.watch<CustomerController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Submit a complaint')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  if (c.errorMessage != null)
                    ErrorBanner(message: c.errorMessage!),
                  const Text(
                    'What went wrong?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final ComplaintCategory k in ComplaintCategory.values)
                        ChoiceChip(
                          label: Text(k.label),
                          selected: _category == k,
                          onSelected: (_) => setState(() => _category = k),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _text,
                    maxLines: 5,
                    maxLength: AppConstants.maxComplaintLength,
                    decoration: const InputDecoration(
                      labelText: 'Describe the problem',
                    ),
                    validator: _validate,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Submit complaint',
                    isLoading: c.isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
