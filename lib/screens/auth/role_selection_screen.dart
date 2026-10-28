import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/auth_scaffold.dart';
import '../../models/enums/user_role.dart';
import '../../routes/app_router.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'How will you use FixOnWay?',
      subtitle: 'Choose your role to continue.',
      showBack: false,
      child: Column(
        children: <Widget>[
          _RoleCard(
            icon: Icons.directions_car_outlined,
            title: 'I need help (Customer)',
            text: 'Request roadside assistance for your vehicle.',
            onTap: () => Navigator.of(context)
                .pushNamed(AppRouter.login, arguments: UserRole.customer),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.handyman_outlined,
            title: 'I am a mechanic',
            text: 'Receive nearby requests and earn.',
            onTap: () => Navigator.of(context)
                .pushNamed(AppRouter.login, arguments: UserRole.mechanic),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pushNamed(AppRouter.login, arguments: UserRole.admin),
            child: const Text('Admin login'),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primarySoft,
                child: Icon(icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
