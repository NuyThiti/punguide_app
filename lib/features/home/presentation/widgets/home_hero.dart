import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';

/// Photo header with the app title, the "วันนี้อยากไปหรือปัน ?" prompt and the
/// two entry-point cards, all under one rounded bottom edge.
class HomeHero extends StatelessWidget {
  const HomeHero({
    super.key,
    required this.coverImage,
    required this.avatarImage,
    required this.onProfile,
    required this.onFindTrip,
    required this.onShareTrip,
  });

  final String coverImage;

  /// Null while signed out, or when the account has no photo.
  final String? avatarImage;
  final VoidCallback onProfile;
  final VoidCallback onFindTrip;
  final VoidCallback onShareTrip;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        children: [
          Positioned.fill(
            // Biased upward so the wide crop keeps the traveller and the
            // mountains in frame instead of only the suitcase wheels.
            child: CoverImage(
              source: coverImage,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.3),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.32, 0.62, 1],
                  colors: [
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.14),
                    Colors.black.withValues(alpha: 0.70),
                    Colors.black.withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, topInset + 8, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // _TitleBar(avatarImage: avatarImage, onProfile: onProfile),
                const SizedBox(height: 40),
                const Text(
                  'วันนี้อยากไปหรือปัน ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                // Intrinsic height so both cards match whichever wraps taller.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: HomeActionCard(
                          title: 'ไปกัน',
                          subtitle:
                              'ค้นหา แนะนำการทริปเที่ยว\nจากสถานที่ของคุณ',
                          color: AppColors.brandOrange,
                          onTap: onFindTrip,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: HomeActionCard(
                          title: 'ปันไกด์',
                          subtitle: 'แบ่งปันประสบการณ์\nเที่ยวของคุณ',
                          color: AppColors.brandPurple,
                          onTap: onShareTrip,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.avatarImage, required this.onProfile});

  final String? avatarImage;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'PunGuide',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onProfile,
              child: Container(
                width: 36,
                height: 36,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                ),
                child: avatarImage != null
                    ? CoverImage(source: avatarImage!, fit: BoxFit.cover)
                    : const ColoredBox(
                        color: Colors.white24,
                        child: Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeActionCard extends StatelessWidget {
  const HomeActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  width: 30,
                  height: 25,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: const Icon(
                    Icons.arrow_outward,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
