import 'package:flutter/material.dart';

import '../../models/photo_attachment.dart';
import '../theme/app_theme.dart';

/// Small thumbnails of the uploaded photos. Photos without an address (demo
/// mode) are only counted.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({super.key, required this.photos, this.size = 72});

  final List<PhotoAttachment> photos;
  final double size;

  @override
  Widget build(BuildContext context) {
    final List<PhotoAttachment> real =
        photos.where((PhotoAttachment p) => p.url != null).toList();
    if (real.isEmpty) {
      return Text(
        '${photos.length} photo(s) attached',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final PhotoAttachment p in real)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              p.url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                  Container(
                width: size,
                height: size,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
      ],
    );
  }
}
