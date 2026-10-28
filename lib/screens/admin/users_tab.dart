import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/section_card.dart';
import '../../models/app_user.dart';
import '../../models/enums/user_role.dart';

/// UC-35 block/unblock and UC-36 manage customers (and mechanics).
class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _block(AppUser u) async {
    final AdminController c = context.read<AdminController>();
    final TextEditingController reason = TextEditingController();
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Block ${u.name}?'),
        content: TextField(
          controller: reason,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    final String text = reason.text;
    reason.dispose();
    if (go == true) await c.block(u.id, text);
  }

  @override
  Widget build(BuildContext context) {
    final AdminController c = context.watch<AdminController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'Users',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (String v) => c.filterUsers(role: c.userRole, query: v),
            decoration: InputDecoration(
              hintText: 'Search name, phone or email',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _search.clear();
                  c.filterUsers(role: c.userRole, query: '');
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('All'),
                selected: c.userRole == null,
                onSelected: (_) => c.filterUsers(role: null),
              ),
              ChoiceChip(
                label: const Text('Customers'),
                selected: c.userRole == UserRole.customer,
                onSelected: (_) => c.filterUsers(role: UserRole.customer),
              ),
              ChoiceChip(
                label: const Text('Mechanics'),
                selected: c.userRole == UserRole.mechanic,
                onSelected: (_) => c.filterUsers(role: UserRole.mechanic),
              ),
            ],
          ),
        ),
        if (c.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: ErrorBanner(message: c.errorMessage!),
          ),
        Expanded(
          child: c.users.isEmpty
              ? const EmptyState(
                  icon: Icons.person_search_outlined,
                  message: 'No users match.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: c.users.length,
                  itemBuilder: (BuildContext context, int i) {
                    final AppUser u = c.users[i];
                    return SectionCard(
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor: u.isBlocked
                                ? AppColors.errorSoft
                                : AppColors.primarySoft,
                            child: Icon(
                              u.role == UserRole.mechanic
                                  ? Icons.handyman
                                  : Icons.person,
                              color: u.isBlocked
                                  ? AppColors.error
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  u.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${u.role.label}  -  ${u.phone}\n${u.email}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                if (u.isBlocked)
                                  const Text(
                                    'Blocked',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (u.role == UserRole.mechanic &&
                                    u.isPendingVerification)
                                  const Text(
                                    'Not verified yet',
                                    style: TextStyle(
                                      color: AppColors.info,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (u.isBlocked)
                            OutlinedButton(
                              onPressed:
                                  c.isLoading ? null : () => c.unblock(u.id),
                              child: const Text('Unblock'),
                            )
                          else
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                              onPressed: c.isLoading ? null : () => _block(u),
                              child: const Text('Block'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
