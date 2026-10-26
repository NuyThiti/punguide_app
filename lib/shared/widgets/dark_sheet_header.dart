import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'cover_image.dart';

/// The short dark header the profile's sub-pages open on: the cover photo
/// under a flat scrim, a white back disc, and the page's name in the middle.
///
/// Shared by จัดการบัญชี and Save Draft, which draw the identical bar — a
/// second copy would drift the moment one of them is nudged.
class DarkSheetHeader extends StatelessWidget {
  const DarkSheetHeader({
    super.key,
    required this.title,
    required this.coverImage,
    required this.onBack,
  });

  final String title;
  final String coverImage;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: Stack(
        children: [
          Positioned.fill(
            child: CoverImage(source: coverImage, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 10,
              16,
              20,
            ),
            child: SizedBox(
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: onBack,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_left,
                          color: AppColors.foreground,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
