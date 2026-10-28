import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/edit_profile_dialog.dart';
import '../../core/widgets/logout_button.dart';
import '../../core/widgets/section_card.dart';
import '../../models/app_user.dart';

/// UC-42: the admin's own profile and password.
class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  Future<void> _edit(BuildContext context, AppUser user) async {
    final AuthController auth = context.read<AuthController>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ({String name, String email})? v =
        await EditProfileDialog.show(context, user);
    if (v == null) return;
    final bool ok = await auth.updateProfile(name: v.name, email: v.email);
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? 'Profile updated.' : auth.errorMessage ?? 'Failed.')),
    );
  }

  Future<void> _password(BuildContext context) async {
    final AuthController auth = context.read<AuthController>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final GlobalKey<FormState> form = GlobalKey<FormState>();
    final TextEditingController current = TextEditingController();
    final TextEditingController next = TextEditingController();
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppTextField(
                controller: current,
                label: 'Current password',
                obscure: true,
                validator: (String? v) => Validators.required(v, 'Current password'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: next,
                label: 'New password',
                obscure: true,
                validator: Validators.password,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
    final String cur = current.text;
    final String nw = next.text;
    current.dispose();
    next.dispose();
    if (go != true) return;
    final bool ok =
        await auth.changePassword(currentPassword: cur, newPassword: nw);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Password changed.' : auth.errorMessage ?? 'Failed.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = context.watch<AuthController>().user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: const <Widget>[LogoutButton()],
      ),
      body: user == null
          ? const Center(child: Text('Not signed in.'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(user.email),
                          Text(
                            user.phone,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _edit(context, user),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit name and email'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _password(context),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Change password'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
