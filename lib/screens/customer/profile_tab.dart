import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/customer_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/edit_profile_dialog.dart';
import '../../core/widgets/logout_button.dart';
import '../../core/widgets/section_card.dart';
import '../../models/app_user.dart';
import '../../routes/app_router.dart';

/// UC-05: manage profile, plus links to vehicles and logout (UC-07).
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _edit(BuildContext context, AppUser user) async {
    final AuthController auth = context.read<AuthController>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ({String name, String email})? result =
        await EditProfileDialog.show(context, user);
    if (result == null) return;
    final bool ok = await auth.updateProfile(
      name: result.name,
      email: result.email,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profile updated.' : auth.errorMessage ?? 'Failed.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = context.watch<AuthController>().user;
    final int vehicleCount = context.watch<CustomerController>().vehicles.length;
    if (user == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          'Profile',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
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
                    const SizedBox(height: 2),
                    Text(user.phone),
                    Text(
                      user.email,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(context, user),
              ),
            ],
          ),
        ),
        SectionCard(
          onTap: () => Navigator.of(context).pushNamed(AppRouter.vehicles),
          child: Row(
            children: <Widget>[
              const Icon(Icons.directions_car_outlined,
                  color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text('My vehicles ($vehicleCount)')),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => performLogout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: AppColors.error,
          ),
        ),
      ],
    );
  }
}
