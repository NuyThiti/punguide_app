import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../auth/domain/auth_session.dart';
import '../../domain/models/post_draft.dart';
import 'post_audience_chip.dart';

/// The composer's dark cap: back, the title, and the one-tap import that
/// builds a post out of a trip's photos.
///
/// It absorbs the status bar itself — the screen's [SafeArea] stops at the top
/// so the dark can run under the clock, the way the design draws it.
class CreatePostHeader extends StatelessWidget {
  const CreatePostHeader({
    super.key,
    required this.onClose,
    required this.onPickCover,
    required this.onClearCover,
    this.coverPath,
    required this.onImportPhotos,
    required this.importing,
    required this.onCancelImport,
  });

  final VoidCallback onClose;

  /// The round action opposite the back button: the post's cover photo.
  final VoidCallback onPickCover;

  /// Removes the cover from both the header background and its action.
  final VoidCallback onClearCover;

  /// The selected photo, displayed across the header and in the cover action.
  final String? coverPath;

  /// "Creates post from Photos" — reads the picked photos' EXIF and groups
  /// them into sections.
  final VoidCallback onImportPhotos;

  /// The import is running; the button turns into its own progress row so the
  /// dark cap does not change height underneath it.
  final bool importing;

  final VoidCallback onCancelImport;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: ColoredBox(
        color: AppColors.postHeader,
        child: Stack(
          children: [
            if (coverPath != null && coverPath!.trim().isNotEmpty) ...[
              Positioned.fill(
                child: CoverImage(source: coverPath!),
              ),
              const Positioned.fill(
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
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + 8,
                16,
                18,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        _RoundBackButton(onTap: onClose),
                        const Expanded(
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
                        if (coverPath == null)
                          _RoundAction(
                            icon: Icons.add_photo_alternate_outlined,
                            tooltip: 'รูปหน้าปก',
                            onTap: onPickCover,
                          )
                        else
                          _CoverAction(
                            path: coverPath!,
                            onTap: onPickCover,
                            onClear: onClearCover,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ImportButton(
                    importing: importing,
                    onTap: onImportPhotos,
                    onCancel: onCancelImport,
                  ),
                ],
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

/// The gradient call to action. While importing it keeps its shape and shows
/// progress plus a way out, rather than vanishing and reflowing the header.
class _ImportButton extends StatelessWidget {
  const _ImportButton({
    required this.importing,
    required this.onTap,
    required this.onCancel,
  });

  final bool importing;
  final VoidCallback onTap;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.postImportStart,
            AppColors.postImportMid,
            AppColors.postImportEnd,
          ],
          stops: [0, 0.62, 1],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: importing ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: importing
                ? Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'กำลังจัดรูปเป็นเรื่องราว…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('ยกเลิก'),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 22,
                        color: Colors.white,
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Create from Photos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
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

/// The cover once there is one: the picture itself, with the way to take it
/// off sitting on its corner.
class _CoverAction extends StatelessWidget {
  const _CoverAction(
      {required this.path, required this.onTap, required this.onClear});

  final String path;
  final VoidCallback onTap, onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      // The clear badge is allowed past the corner, which is the only way it
      // fits without eating the picture it belongs to.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Tooltip(
              message: 'เปลี่ยนรูปหน้าปก',
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CoverImage(source: path),
                ),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Tooltip(
              message: 'เอารูปหน้าปกออก',
              child: GestureDetector(
                onTap: onClear,
                // A 20pt dot is under the comfortable tap size, so the target
                // is padded out around it rather than drawn bigger.
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.postHeader,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, size: 13, color: Colors.white),
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
