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
    required this.onImportPhotos,
    required this.importing,
    required this.onCancelImport,
  });

  final VoidCallback onClose;

  /// "Creates post from Photos" — reads the picked photos' EXIF and groups
  /// them into sections.
  final VoidCallback onImportPhotos;

  /// The import is running; the button turns into its own progress row so the
  /// dark cap does not change height underneath it.
  final bool importing;

  final VoidCallback onCancelImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        18,
      ),
      decoration: const BoxDecoration(
        color: AppColors.postHeader,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
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
                    'Create Post',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                // Balances the back button so the title sits centred.
                const SizedBox(width: 40),
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
                          'Creates post from Photos',
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
