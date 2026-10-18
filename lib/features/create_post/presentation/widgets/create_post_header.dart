import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../../shared/widgets/full_image_viewer.dart';
import '../../../auth/domain/auth_session.dart';
import '../../domain/models/post_draft.dart';
import 'post_audience_chip.dart';

/// The composer's dark cap: back, the title, and the cover photo behind it.
///
/// It absorbs the status bar itself — the screen's [SafeArea] stops at the top
/// so the dark can run under the clock, the way the design draws it. The
/// one-tap "AI สร้างโพสจากรูป" button that used to live here moved into the
/// spot's own toolbar as "ช่วยเขียน" — this cap is back to just back, title,
/// and the cover action. A cover photo keeps the cap at this same height
/// rather than growing it — tapping the photo itself is what opens it up, full
/// screen.
class CreatePostHeader extends StatelessWidget {
  const CreatePostHeader({
    super.key,
    required this.onClose,
    required this.onPickCover,
    required this.onClearCover,
    this.coverPath,
  });

  final VoidCallback onClose;

  /// The round action opposite the back button: the post's cover photo.
  final VoidCallback onPickCover;

  /// Removes the cover from both the header background and its action.
  final VoidCallback onClearCover;

  /// The selected photo, displayed across the header and in the cover action.
  final String? coverPath;

  @override
  Widget build(BuildContext context) {
    final hasCover = coverPath != null && coverPath!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: ColoredBox(
        color: AppColors.postHeader,
        child: Stack(
          children: [
            if (hasCover) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showFullImages(context, urls: [coverPath!]),
                  child: CoverImage(source: coverPath!),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x26000000), Color(0xF2000000)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + 8,
                16,
                18,
              ),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    _RoundBackButton(onTap: onClose),
                    // `IgnorePointer`, not just an absent `GestureDetector`:
                    // `RenderParagraph` claims hit-testing across its own
                    // painted line regardless, and without this a tap meant
                    // for the cover image behind it never reaches it.
                    const Expanded(
                      child: IgnorePointer(
                        child: Text(
                          'PunGuide',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (!hasCover)
                      _RoundAction(
                        icon: Icons.add_photo_alternate_outlined,
                        tooltip: 'รูปหน้าปก',
                        onTap: onPickCover,
                      )
                    else
                      _CoverMenuButton(
                        onChange: onPickCover,
                        onRemove: onClearCover,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'ปิด',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.chevron_left,
              size: 26,
              color: AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// The dark round action on the right of the bar, mirroring the back button.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white24,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 21, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

enum _CoverMenuAction { change, remove }

/// Once there is a cover, the round action opens a menu instead of jumping
/// straight back into the picker — "เปลี่ยน" to swap it, "ลบ" to take it off
/// entirely, both spelled out rather than left for a long press to discover.
class _CoverMenuButton extends StatelessWidget {
  const _CoverMenuButton({required this.onChange, required this.onRemove});

  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white24,
      shape: const CircleBorder(),
      child: PopupMenuButton<_CoverMenuAction>(
        tooltip: 'รูปหน้าปก',
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (action) => switch (action) {
          _CoverMenuAction.change => onChange(),
          _CoverMenuAction.remove => onRemove(),
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _CoverMenuAction.change,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(Icons.add_photo_alternate_outlined, color: AppColors.postPurple),
              title: Text('เปลี่ยนรูปหน้าปก'),
            ),
          ),
          PopupMenuItem(
            value: _CoverMenuAction.remove,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: AppColors.brandOrangeDeep),
              title: Text('ลบรูปหน้าปก'),
            ),
          ),
        ],
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.add_photo_alternate_outlined,
              size: 21, color: Colors.white),
        ),
      ),
    );
  }
}

/// Who is posting, and who will see it — the audience sits on the right of the
/// name rather than under it.
class PostAuthorRow extends StatelessWidget {
  const PostAuthorRow({
    super.key,
    required this.session,
    required this.audience,
    required this.onChangeAudience,
  });

  /// Null while signed out — the guest path still reaches the composer, so the
  /// avatar falls back to a placeholder rather than blowing up.
  final AuthSession? session;

  final PostAudience audience;
  final VoidCallback onChangeAudience;

  @override
  Widget build(BuildContext context) {
    final avatar = session?.avatarImage;
    final name = session?.displayName ?? 'ผู้ใช้ PunGuide';

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.postField,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: avatar == null || avatar.isEmpty
                ? const Icon(Icons.person, size: 24, color: AppColors.muted)
                : CoverImage(source: avatar),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        PostAudienceChip(audience: audience, onTap: onChangeAudience),
      ],
    );
  }
}
