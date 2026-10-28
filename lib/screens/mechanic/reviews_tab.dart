import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/mechanic_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/star_row.dart';
import '../../models/mechanic_profile.dart';
import '../../models/review.dart';

/// UC-33: reviews received.
class ReviewsTab extends StatelessWidget {
  const ReviewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final MechanicController c = context.watch<MechanicController>();
    final MechanicProfile? profile = c.profile;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          'Reviews',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        if (profile != null)
          SectionCard(
            child: Row(
              children: <Widget>[
                Text(
                  profile.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    StarRow(rating: profile.rating.round()),
                    Text(
                      '${profile.reviewCount} reviews',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (c.reviews.isEmpty)
          const Text(
            'No reviews yet. They appear after customers rate your jobs.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        for (final Review r in c.reviews)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    StarRow(rating: r.rating),
                    const Spacer(),
                    Text(
                      formatDateTime(r.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  r.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (r.comment.isNotEmpty) Text(r.comment),
              ],
            ),
          ),
      ],
    );
  }
}
