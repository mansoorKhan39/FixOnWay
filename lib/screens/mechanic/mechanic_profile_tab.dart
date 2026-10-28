import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/mechanic_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/edit_profile_dialog.dart';
import '../../core/widgets/logout_button.dart';
import '../../core/widgets/section_card.dart';
import '../../models/app_user.dart';
import '../../models/mechanic_profile.dart';
import '../../routes/app_router.dart';

/// UC-05 profile and UC-24 entry point for the mechanic.
class MechanicProfileTab extends StatelessWidget {
  const MechanicProfileTab({super.key});

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
    final MechanicProfile? profile = context.watch<MechanicController>().profile;
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
                    Text(user.phone),
                    Text(
                      user.email,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Verified mechanic',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
        if (profile != null)
          SectionCard(
            onTap: () => Navigator.of(context).pushNamed(AppRouter.serviceArea),
            child: Row(
              children: <Widget>[
                const Icon(Icons.map_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Service area and working hours',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Within ${profile.serviceRadiusKm} km  -  '
                        '${profile.workingHours}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
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
