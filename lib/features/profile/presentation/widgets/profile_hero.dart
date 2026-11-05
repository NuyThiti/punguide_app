import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../auth/domain/auth_session.dart';
import 'profile_top_bar.dart';

/// One figure under the avatar. [onTap] null draws it inert.
typedef ProfileCount = ({String value, String label, VoidCallback? onTap});

/// The dark card the profile opens on (Figma 1539-8068): cover photo, the
/// avatar, the name, and the four counts. Back and จัดการบัญชี live in
/// [ProfileTopBar], which is pinned over this rather than scrolling with it.
///
/// Falls back to a guest presentation when there is no session.
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.session,
    required this.coverImage,
    required this.onEditAvatar,
    this.counts = designCounts,
  });

  final AuthSession? session;
  final String coverImage;
  final VoidCallback onEditAvatar;

  /// What the counts row prints. Defaults to the design's own figures.
  final List<ProfileCount> counts;

  static const double avatarSize = 84;

  /// Remix / Like / Follower / Following as the design prints them. The API
  /// has no account-wide Remix or Like totals, so those two stay the design's
  /// own; the profile screen swaps in real follower counts.
  static const designCounts = <ProfileCount>[
    (value: '2.9K', label: 'Remix', onTap: null),
    (value: '1K', label: 'Like', onTap: null),
    (value: '828', label: 'Follower', onTap: null),
    (value: '342', label: 'Following', onTap: null),
  ];

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    final signedIn = session != null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: Stack(
        children: [
          Positioned.fill(
            child: CoverImage(source: coverImage, fit: BoxFit.cover),
          ),
          // The card reads as near-black in the design; the photo survives as
          // texture, which is what keeps the white type legible over it.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.80),
                    Colors.black.withValues(alpha: 0.66),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              // Clears the pinned bar, which overlays this card.
              ProfileTopBar.heightOf(context) + 4,
              16,
              18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Avatar(
                  avatarImage: session?.avatarImage,
                  showEdit: signedIn,
                  onEdit: onEditAvatar,
                ),
                const SizedBox(height: 10),
                Text(
                  session?.displayName ?? 'ผู้เยี่ยมชม',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session?.handle ?? 'ยังไม่ได้เข้าสู่ระบบ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (signedIn) ...[
                  const SizedBox(height: 16),
                  ProfileCountsRow(counts: counts),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The counts, straight on the cover — no pill behind them.
class ProfileCountsRow extends StatelessWidget {
  const ProfileCountsRow({super.key, this.counts = ProfileHero.designCounts});

  final List<ProfileCount> counts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (:value, :label, :onTap) in counts)
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.avatarImage,
    required this.showEdit,
    required this.onEdit,
  });

  final String? avatarImage;
  final bool showEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    const size = ProfileHero.avatarSize;
    final avatarImage = this.avatarImage;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: avatarImage != null && avatarImage.isNotEmpty
                ? CoverImage(source: avatarImage, fit: BoxFit.cover)
                : const Icon(Icons.person, color: Colors.white, size: 40),
          ),
          if (showEdit)
            Positioned(
              right: -2,
              bottom: 2,
              child: GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
