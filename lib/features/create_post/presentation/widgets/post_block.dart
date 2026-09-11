import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../domain/models/post_draft.dart';

/// One section of the composer: the story, then whatever was added to it.
///
/// Nothing here is a labelled form field — the body sits straight on the page
/// and the optional parts appear only once asked for, which is why the chips
/// underneath carry a '+'.
class PostBlock extends StatelessWidget {
  const PostBlock({
    super.key,
    required this.titleController,
    required this.titleFocus,
    required this.bodyController,
    required this.showTitle,
    required this.imagePath,
    required this.place,
    required this.onAddTitle,
    required this.onClearTitle,
    required this.onPickImage,
    required this.onClearImage,
    required this.onPickPlace,
    required this.onClearPlace,
    this.onRemove,
  });

  final TextEditingController titleController;
  final FocusNode titleFocus;
  final TextEditingController bodyController;

  /// The heading field is on screen. Separate from the text being empty: a
  /// heading just added is showing and still blank.
  final bool showTitle;

  final String? imagePath;
  final PostPlace? place;

  final VoidCallback onAddTitle;
  final VoidCallback onClearTitle;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onPickPlace;
  final VoidCallback onClearPlace;

  /// Null on the first section — a post always keeps one — and a small "ลบ"
  /// above the rest.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final photo = imagePath;
    final pinned = place;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onRemove != null)
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'ลบเนื้อหานี้',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (showTitle) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: titleController,
                  focusNode: titleFocus,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 19,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'หัวข้อ',
                    hintStyle: TextStyle(
                      color: AppColors.postFieldHint,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              _ClearButton(onTap: onClearTitle, tooltip: 'ลบหัวข้อ'),
            ],
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: bodyController,
          minLines: 2,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 16,
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: 'เล่าเรื่องราวของทริปนี้…',
            hintStyle: TextStyle(
              color: AppColors.postFieldHint,
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (photo != null) ...[
          const SizedBox(height: 14),
          _BlockPhoto(source: photo, onClear: onClearImage),
        ],
        if (pinned != null) ...[
          const SizedBox(height: 14),
          _PinnedPlaceRow(place: pinned, onClear: onClearPlace),
        ],
        const SizedBox(height: 14),
        _AddRow(
          onAddTitle: showTitle ? null : onAddTitle,
          onPickImage: onPickImage,
          onPickPlace: onPickPlace,
        ),
      ],
    );
  }
}

/// The photo, full width. The remove button is the only chrome over it — the
/// design keeps the picture itself clean.
class _BlockPhoto extends StatelessWidget {
  const _BlockPhoto({required this.source, required this.onClear});

  final String source;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1.6,
            child: CoverImage(source: source),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onClear,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 17, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// The pinned place, as its own outlined row with a pin plate and a ✕.
class _PinnedPlaceRow extends StatelessWidget {
  const _PinnedPlaceRow({required this.place, required this.onClear});

  final PostPlace place;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 4, 7),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.postIconWell,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.map,
              size: 19,
              color: AppColors.brandOrange,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              place.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _ClearButton(onTap: onClear, tooltip: 'ลบสถานที่'),
        ],
      ),
    );
  }
}

/// "+ หัวข้อ · + รูปภาพ · + สถานที่", then the note that none of them are
/// required.
class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.onAddTitle,
    required this.onPickImage,
    required this.onPickPlace,
  });

  /// Null once the heading is on screen — there is nothing left to add.
  final VoidCallback? onAddTitle;

  final VoidCallback onPickImage;
  final VoidCallback onPickPlace;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onAddTitle != null)
          PostAddChip(
            icon: Icons.add,
            label: 'หัวข้อ',
            onTap: onAddTitle!,
          ),
        PostAddChip(
          icon: Icons.photo_library_outlined,
          label: 'รูปภาพ',
          onTap: onPickImage,
        ),
        PostAddChip(
          icon: Icons.map_outlined,
          label: 'สถานที่',
          onTap: onPickPlace,
        ),
        // One unit, so a hairline can never end up stranded at the end of a
        // wrapped line with its label on the next.
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              child: VerticalDivider(
                width: 13,
                thickness: 1,
                color: AppColors.line,
              ),
            ),
            Text(
              'ไม่บังคับ',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One "add something" pill, led by the glyph of the thing it adds.
class PostAddChip extends StatelessWidget {
  const PostAddChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.screen,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.chipBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.brandOrange),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.close, size: 20),
      color: const Color(0xFF8E948F),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
