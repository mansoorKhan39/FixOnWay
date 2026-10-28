import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/star_row.dart';
import '../../models/service_request.dart';

/// UC-19: rate and review the mechanic.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final TextEditingController _comment = TextEditingController();
  int _rating = 0;
  String? _ratingError;

  @override
  void initState() {
    super.initState();
    context.read<CustomerController>().clearError();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _ratingError = 'Please choose 1 to 5 stars.');
      return;
    }
    setState(() => _ratingError = null);
    final CustomerController c = context.read<CustomerController>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await c.submitReview(
      widget.requestId,
      _rating,
      _comment.text,
    );
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Thank you for your review!')),
      );
      navigator.pop();
    }
  }

  Future<void> _skip() async {
    final CustomerController c = context.read<CustomerController>();
    final NavigatorState navigator = Navigator.of(context);
    final bool ok = await c.skipReview(widget.requestId);
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final CustomerController c = context.watch<CustomerController>();
    final ServiceRequest? r = c.requestById(widget.requestId);
    return Scaffold(
      appBar: AppBar(title: const Text('Rate your mechanic')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                if (c.errorMessage != null)
                  ErrorBanner(message: c.errorMessage!),
                Center(
                  child: Text(
                    r?.mechanicName ?? 'Your mechanic',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'How was the service?',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: StarRow(
                    rating: _rating,
                    size: 44,
                    onChanged: (int v) => setState(() => _rating = v),
                  ),
                ),
                if (_ratingError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Text(
                        _ratingError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: _comment,
                  maxLines: 4,
                  maxLength: AppConstants.maxReviewLength,
                  decoration: const InputDecoration(
                    labelText: 'Comment (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Submit review',
                  isLoading: c.isLoading,
                  onPressed: _submit,
                ),
                TextButton(
                  onPressed: c.isLoading ? null : _skip,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
