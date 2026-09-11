import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../domain/nearby_trip.dart';

/// The cap of the ไปกัน board: back button, title, and the card that says
/// where "near me" is measured from.
///
/// Photo and scrim are Home's, so the two boards read as one family — see
/// [HomeHero], whose gradient stops these match.
class PaigunHeader extends StatelessWidget {
  const PaigunHeader({
    super.key,
    required this.origin,
    required this.onBack,
    required this.onTune,
    required this.onEditLocation,
    this.coverImage = coverAsset,
  });

  /// The same photo Home puts behind its hero.
  static const String coverAsset = 'assets/images/home_hero.jpg';

  final PaigunOrigin origin;
  final String coverImage;
  final VoidCallback onBack;

  /// The dark control beside the address.
  final VoidCallback onTune;

  /// Tapping the address itself — opens the map picker to move the origin.
  final VoidCallback onEditLocation;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        children: [
          Positioned.fill(
            // Biased upward for the same reason Home's is: the wide crop keeps
            // the traveller and the mountains in frame.
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
            padding: EdgeInsets.fromLTRB(18, topInset + 10, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        'ไปกัน',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _CircleButton(
                          icon: Icons.chevron_left,
                          onTap: onBack,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _LocationCard(
                  origin: origin,
                  onTune: onTune,
                  onEdit: onEditLocation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.origin,
    required this.onTune,
    required this.onEdit,
  });

  final PaigunOrigin origin;
  final VoidCallback onTune;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: AppColors.paigunPinWell,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on,
                          size: 12,
                          color: AppColors.brandOrange,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          origin.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    origin.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onTune,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.paigunControl,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tune, color: Colors.white, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}
