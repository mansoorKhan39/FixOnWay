import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

/// UC-05: edit name and email. Returns the new values, or null on cancel.
class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key, required this.user});

  final AppUser user;

  static Future<({String name, String email})?> show(
    BuildContext context,
    AppUser user,
  ) {
    return showDialog<({String name, String email})>(
      context: context,
      builder: (BuildContext _) => EditProfileDialog(user: user),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.user.name);
  late final TextEditingController _email =
      TextEditingController(text: widget.user.email);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: Validators.name,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your phone number cannot be changed here.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.of(context).pop(
              (name: _name.text.trim(), email: _email.text.trim()),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
