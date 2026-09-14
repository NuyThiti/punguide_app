import 'package:flutter/material.dart';

import '../../../../core/api/models/trip_content.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../domain/models/post_draft.dart';

class PostBlockItem {
  const PostBlockItem({
    required this.bodyController,
    required this.imagePaths,
    this.place,
    this.location,
    this.legacyMapId,
  });

  final TextEditingController bodyController;
  final List<String> imagePaths;
  final PostPlace? place;
  final ContentLocation? location;
  final String? legacyMapId;
}

typedef PostPhotoMove = ({int block, int item, int photo});

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
    this.imagePaths = const [],
    this.unavailableImages = const {},
    this.onRemoveImage,
    this.coverPath,
    this.onSelectCover,
    this.onMoveImage,
    this.onDropBeforeImage,
    this.onDropImage,
    this.blockIndex = 0,
    this.items,
    this.onAddItem,
    this.onRemoveItem,
    this.onPickImageInItem,
    this.onClearImagesInItem,
    this.onRemoveImageInItem,
    this.onMoveImageInItem,
    this.onDropImageInItem,
    this.onDropBeforeImageInItem,
    this.onPickPlaceInItem,
    this.onClearPlaceInItem,
    this.onConfirmLocationInItem,
  });

  final void Function((int, int), int)? onDropBeforeImage;
  final ValueChanged<int>? onMoveImage;
  final ValueChanged<(int, int)>? onDropImage;
  final List<PostBlockItem>? items;
  final VoidCallback? onAddItem;
  final ValueChanged<int>? onRemoveItem;
  final ValueChanged<int>? onPickImageInItem;
  final ValueChanged<int>? onClearImagesInItem;
  final void Function(int, int)? onRemoveImageInItem;
  final void Function(int, int)? onMoveImageInItem;
  final void Function(PostPhotoMove, int)? onDropImageInItem;
  final void Function(PostPhotoMove, int, int)? onDropBeforeImageInItem;
  final ValueChanged<int>? onPickPlaceInItem;
  final ValueChanged<int>? onClearPlaceInItem;
  final ValueChanged<int>? onConfirmLocationInItem;
  final int blockIndex;
  final TextEditingController titleController;
  final FocusNode titleFocus;
  final TextEditingController bodyController;

  /// The heading field is on screen. Separate from the text being empty: a
  /// heading just added is showing and still blank.
  final bool showTitle;

  final String? coverPath;
  final ValueChanged<String>? onSelectCover;
  final String? imagePath;
  final List<String> imagePaths;
  final Set<String> unavailableImages;
  final ValueChanged<int>? onRemoveImage;
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
    final blockItems = items ??
        [
          PostBlockItem(
              bodyController: bodyController,
              imagePaths: [...imagePaths, if (imagePath != null) imagePath!],
              place: place)
        ];

    return DragTarget<PostPhotoMove>(
        onAcceptWithDetails: (details) =>
            (onDropImageInItem ?? _legacyDropImage)(details.data, 0),
        builder: (context, candidates, rejected) => Container(
            decoration: BoxDecoration(
                border: candidates.isEmpty
                    ? null
                    : Border.all(color: AppColors.createTop)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onRemove != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          maxLength: 200,
                          focusNode: titleFocus,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            color: AppColors.foreground,
                            fontSize: 19,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
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
                for (var item = 0; item < blockItems.length; item++) ...[
                  if (item > 0)
                    const Divider(height: 28, color: AppColors.line),
                  _PostBlockContentItem(
                    blockIndex: blockIndex,
                    itemIndex: item,
                    item: blockItems[item],
                    showPhotoChip: showTitle,
                    unavailableImages: unavailableImages,
                    coverPath: coverPath,
                    onSelectCover: onSelectCover,
                    onPickImage: () {
                      final handler = onPickImageInItem;
                      if (handler == null) {
                        onPickImage();
                      } else {
                        handler(item);
                      }
                    },
                    onClearImages: () {
                      final handler = onClearImagesInItem;
                      if (handler == null) {
                        onClearImage();
                      } else {
                        handler(item);
                      }
                    },
                    onRemoveImage: (photo) => (onRemoveImageInItem ??
                        _legacyRemoveImage)(item, photo),
                    onMoveImage: (photo) =>
                        (onMoveImageInItem ?? _legacyMoveImage)(item, photo),
                    onDropImage: (move) =>
                        (onDropImageInItem ?? _legacyDropImage)(move, item),
                    onDropBeforeImage: (move, position) =>
                        (onDropBeforeImageInItem ?? _legacyDropBeforeImage)(
                            move, item, position),
                    onPickPlace: () =>
                        (onPickPlaceInItem ?? _legacyPickPlace)(item),
                    onClearPlace: () =>
                        (onClearPlaceInItem ?? _legacyClearPlace)(item),
                    onConfirmLocation: onConfirmLocationInItem == null
                        ? null
                        : () => onConfirmLocationInItem!(item),
                  ),
                  if (showTitle &&
                      blockItems.length > 1 &&
                      onRemoveItem != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => onRemoveItem!(item),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('ลบชุดข้อมูลนี้'),
                      ),
                    ),
                ],
                if (showTitle && onAddItem != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onAddItem,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('เพิ่มรูปภาพและคำอธิบาย'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.createTop),
                  ),
                ],
                const SizedBox(height: 14),
                _AddRow(
                  onAddTitle: showTitle ? null : onAddTitle,
                  onPickImage: showTitle ? null : onPickImage,
                  onPickPlace: showTitle ? null : onPickPlace,
                ),
              ],
            )));
  }

  void _legacyMoveImage(int item, int photo) {
    if (item == 0) onMoveImage?.call(photo);
  }

  void _legacyRemoveImage(int item, int photo) {
    if (item == 0) onRemoveImage?.call(photo);
  }

  void _legacyDropImage(PostPhotoMove move, int item) {
    if (item == 0) onDropImage?.call((move.block, move.photo));
  }

  void _legacyDropBeforeImage(PostPhotoMove move, int item, int position) {
    if (item == 0) onDropBeforeImage?.call((move.block, move.photo), position);
  }

  void _legacyPickPlace(int item) {
    if (item == 0) onPickPlace();
  }

  void _legacyClearPlace(int item) {
    if (item == 0) onClearPlace();
  }
}

class _PostBlockContentItem extends StatelessWidget {
  const _PostBlockContentItem({
    required this.blockIndex,
    required this.itemIndex,
    required this.item,
    required this.showPhotoChip,
    required this.unavailableImages,
    required this.onPickImage,
    required this.onClearImages,
    required this.onRemoveImage,
    required this.onMoveImage,
    required this.onDropImage,
    required this.onDropBeforeImage,
    required this.onPickPlace,
    required this.onClearPlace,
    this.onConfirmLocation,
    this.coverPath,
    this.onSelectCover,
  });

  final int blockIndex, itemIndex;
  final PostBlockItem item;
  final bool showPhotoChip;
  final Set<String> unavailableImages;
  final String? coverPath;
  final ValueChanged<String>? onSelectCover;
  final VoidCallback onPickImage, onClearImages;
  final ValueChanged<int> onRemoveImage, onMoveImage;
  final ValueChanged<PostPhotoMove> onDropImage;
  final void Function(PostPhotoMove, int) onDropBeforeImage;
  final VoidCallback onPickPlace, onClearPlace;
  final VoidCallback? onConfirmLocation;

  @override
  Widget build(BuildContext context) {
    return DragTarget<PostPhotoMove>(
      onAcceptWithDetails: (details) => onDropImage(details.data),
      builder: (context, candidates, rejected) => DecoratedBox(
        decoration: BoxDecoration(
            border: candidates.isEmpty
                ? null
                : Border.all(color: AppColors.createTop)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: item.bodyController,
              maxLength: 10000,
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
                counterText: '',
                hintText: 'เล่าเรื่องราวของทริปนี้…',
                hintStyle: TextStyle(
                  color: AppColors.postFieldHint,
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            for (var index = 0; index < item.imagePaths.length; index++) ...[
              const SizedBox(height: 14),
              DragTarget<PostPhotoMove>(
                  onAcceptWithDetails: (details) =>
                      onDropBeforeImage(details.data, index),
                  builder: (context, candidates, rejected) => DecoratedBox(
                      decoration: BoxDecoration(
                          border: candidates.isEmpty
                              ? null
                              : Border.all(
                                  color: AppColors.createTop, width: 3)),
                      child: LongPressDraggable<PostPhotoMove>(
                          data: (
                            block: blockIndex,
                            item: itemIndex,
                            photo: index
                          ),
                          feedback: Material(
                              color: AppColors.createTop,
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                  padding: EdgeInsets.all(16),
                                  child:
                                      Icon(Icons.photo, color: Colors.white))),
                          child: _BlockPhoto(
                              source: item.imagePaths[index],
                              unavailable: unavailableImages
                                  .contains(item.imagePaths[index]),
                              isCover: item.imagePaths[index] == coverPath,
                              onSelectCover: onSelectCover == null
                                  ? null
                                  : () =>
                                      onSelectCover!(item.imagePaths[index]),
                              onClear: () => onRemoveImage(index))))),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      onPressed: () => onMoveImage(index),
                      icon: const Icon(Icons.drive_file_move_outline),
                      label: const Text('ย้ายรูป'))),
            ],
            if (showPhotoChip) ...[
              const SizedBox(height: 14),
              PostAddChip(
                icon: Icons.photo_library_outlined,
                label: 'รูปภาพ',
                onTap: onPickImage,
              ),
            ],
            if (item.place != null) ...[
              const SizedBox(height: 14),
              _PinnedPlaceRow(place: item.place!, onClear: onClearPlace),
            ],
            if (item.legacyMapId != null && item.location == null) ...[
              const SizedBox(height: 14),
              _LocationTile(
                title: 'สถานที่เดิม (ยังไม่ยืนยัน)',
                onTap: onPickPlace,
                onClear: onClearPlace,
              ),
            ],
            if (item.location != null &&
                item.location!.status != ContentLocationStatus.none) ...[
              const SizedBox(height: 14),
              _LocationTile(
                title: item.location!.status == ContentLocationStatus.suggested
                    ? 'สถานที่ที่แนะนำ: ${item.location!.name ?? "รอยืนยัน"}'
                    : item.location!.name ?? 'สถานที่ที่ยืนยัน',
                actionLabel:
                    item.location!.status == ContentLocationStatus.suggested
                        ? 'ยืนยันสถานที่'
                        : null,
                onAction:
                    item.location!.status == ContentLocationStatus.suggested
                        ? onConfirmLocation
                        : null,
                onTap: onPickPlace,
                onClear: onClearPlace,
              ),
            ],
            if (showPhotoChip) ...[
              const SizedBox(height: 10),
              PostAddChip(
                icon: Icons.map_outlined,
                label: 'เพิ่มสถานที่ (ไม่บังคับ)',
                onTap: onPickPlace,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.title,
    required this.onTap,
    required this.onClear,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onTap, onClear;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: actionLabel == null
              ? null
              : TextButton(onPressed: onAction, child: Text(actionLabel!)),
          onTap: onTap,
          trailing: IconButton(
            tooltip: 'ลบสถานที่',
            icon: const Icon(Icons.close),
            onPressed: onClear,
          ),
        ),
      );
}

/// A full-width photo with a single-cover selector.
class _BlockPhoto extends StatelessWidget {
  const _BlockPhoto(
      {required this.source,
      required this.onClear,
      this.isCover = false,
      this.unavailable = false,
      this.onSelectCover});

  final bool isCover;
  final bool unavailable;
  final VoidCallback? onSelectCover;

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
            child: unavailable
                ? const ColoredBox(
                    color: AppColors.line,
                    child: Center(child: Text('รูปนี้ไม่พร้อมใช้งาน')))
                : CoverImage(source: source),
          ),
        ),
        if (onSelectCover != null && !unavailable)
          Positioned(
            bottom: 8,
            left: 8,
            child: Semantics(
              selected: isCover,
              child: FilledButton.icon(
                onPressed: onSelectCover,
                style: FilledButton.styleFrom(
                  backgroundColor: isCover
                      ? AppColors.createTop
                      : Colors.black.withValues(alpha: 0.65),
                  foregroundColor: Colors.white,
                ),
                icon: Icon(isCover ? Icons.check_circle : Icons.image_outlined,
                    size: 18),
                label: Text(isCover ? 'รูปหน้าปก' : 'ใช้เป็นหน้าปก'),
              ),
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
              color: AppColors.createTop,
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

  final VoidCallback? onPickImage;
  final VoidCallback? onPickPlace;

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
        if (onPickImage != null)
          PostAddChip(
            icon: Icons.photo_library_outlined,
            label: 'รูปภาพ',
            onTap: onPickImage!,
          ),
        if (onPickPlace != null)
          PostAddChip(
            icon: Icons.map_outlined,
            label: 'เพิ่มสถานที่ (ไม่บังคับ)',
            onTap: onPickPlace!,
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
              Icon(icon, size: 16, color: AppColors.createTop),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              )),
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
