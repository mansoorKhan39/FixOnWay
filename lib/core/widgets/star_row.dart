import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shows 1 to 5 stars. Pass [onChanged] to make it tappable (UC-19).
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.onChanged, this.size = 20});

  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: Icon(
              i <= rating ? Icons.star : Icons.star_border,
              color: AppColors.primary,
              size: size,
            ),
          ),
      ],
    );
  }
}
