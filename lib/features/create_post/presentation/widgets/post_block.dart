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

/// The extras a spot offers that the trip API has no field for yet.
///
/// They are real rows in the design, so they are drawn; the screen answers for
/// them in one place rather than each row inventing somewhere to be stored.
enum PostSpotExtra {
  video('วิดีโอ'),
  tripHack('Trip Hack'),
  recommendTime('Recommend Time'),
  activityAndStyle('Activity And Style'),
  howToGetHere('How to Get Here');

  const PostSpotExtra(this.label);

  final String label;
}

/// One spot (จุด) of the post: its name, where it is, the story, the photos,
/// and the extras underneath.
///
/// The composer repeats this whole unit — "เพิ่มจุดต่อไป" adds the next one.
class PostBlock extends StatelessWidget {
  const PostBlock({
    super.key,
    required this.titleController,
    required this.titleFocus,
    required this.bodyController,
    required this.imagePath,
    required this.imagePaths,
    required this.place,
    required this.onPickImage,
    required this.onClearImage,
    required this.onPickPlace,
    required this.onClearPlace,
    required this.onExtra,
    this.blockIndex = 0,
    this.items,
    this.unavailableImages = const {},
    this.coverPath,
    this.onSelectCover,
    this.onRemoveImage,
    this.onMoveImage,
    this.onDropImage,
    this.onDropBeforeImage,
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
    this.onCaptureImage,
    this.onRemove,
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
  final String? coverPath;
  final ValueChanged<String>? onSelectCover;
  final String? imagePath;
  final List<String> imagePaths;
  final Set<String> unavailableImages;
  final ValueChanged<int>? onRemoveImage;
  final PostPlace? place;

  final VoidCallback onPickImage;

  /// Straight to the camera, from the first chip.
  final VoidCallback? onCaptureImage;

  final VoidCallback onClearImage;
  final VoidCallback onPickPlace;
  final VoidCallback onClearPlace;

  /// Answers for the rows the API cannot store yet.
  final ValueChanged<PostSpotExtra> onExtra;

  /// Null on the only spot — a post always keeps one.
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
              : Border.all(color: AppColors.postPurple),
        ),
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
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'ลบจุดนี้',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            _TitleRow(controller: titleController, focusNode: titleFocus),
            const _Hairline(),
            for (var item = 0; item < blockItems.length; item++) ...[
              if (item > 0) const _Hairline(),
              _PostBlockContentItem(
                blockIndex: blockIndex,
                itemIndex: item,
                item: blockItems[item],
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
                onRemoveImage: (photo) =>
                    (onRemoveImageInItem ?? _legacyRemoveImage)(item, photo),
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
              if (blockItems.length > 1 && onRemoveItem != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => onRemoveItem!(item),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('ลบชุดข้อมูลนี้'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            _AttachmentRow(
              onCapture: onCaptureImage ?? onPickImage,
              onPickImage: onPickImage,
              onExtra: onExtra,
            ),
            const SizedBox(height: 8),
            _ExtraRow(
              icon: Icons.schedule,
              extra: PostSpotExtra.recommendTime,
              onTap: onExtra,
            ),
            const _Hairline(),
            _ExtraRow(
              icon: Icons.emoji_emotions_outlined,
              extra: PostSpotExtra.activityAndStyle,
              onTap: onExtra,
            ),
            const _Hairline(),
            _ExtraRow(
              icon: Icons.directions_car_outlined,
              extra: PostSpotExtra.howToGetHere,
              onTap: onExtra,
            ),
            const _Hairline(),
          ],
        ),
      ),
    );
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

/// The spot's name, with the pencil that puts the caret in it.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLength: 200,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 17,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              counterText: '',
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
              hintText: 'ตั้งชื่อโพส..',
              hintStyle: TextStyle(
                color: AppColors.postFieldHint,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: focusNode.requestFocus,
          icon: const Icon(Icons.edit_outlined, size: 20),
          color: AppColors.postPurple,
          tooltip: 'แก้ชื่อ',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _PostBlockContentItem extends StatelessWidget {
  const _PostBlockContentItem({
    required this.blockIndex,
    required this.itemIndex,
    required this.item,
    required this.unavailableImages,
    required this.coverPath,
    required this.onSelectCover,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onMoveImage,
    required this.onDropImage,
    required this.onDropBeforeImage,
    required this.onPickPlace,
    required this.onClearPlace,
    required this.onConfirmLocation,
  });

  final int blockIndex, itemIndex;
  final PostBlockItem item;
  final Set<String> unavailableImages;
  final String? coverPath;
  final ValueChanged<String>? onSelectCover;
  final VoidCallback onPickImage;
  final ValueChanged<int> onRemoveImage, onMoveImage;
  final ValueChanged<PostPhotoMove> onDropImage;
  final void Function(PostPhotoMove, int) onDropBeforeImage;
  final VoidCallback onPickPlace, onClearPlace;
  final VoidCallback? onConfirmLocation;

  /// What the location row reads: the place over its distance and address, or
  /// the prompt when nothing is pinned yet.
  (String, String?, bool) get _locationLabel {
    final pinned = item.place;
    if (pinned != null) {
      final subtitle = pinned.subtitle;
      return (pinned.name, subtitle.isEmpty ? pinned.area : subtitle, true);
    }

    final location = item.location;
    if (location != null && location.status != ContentLocationStatus.none) {
      final name = location.name;
      if (location.status == ContentLocationStatus.suggested) {
        return (name ?? 'รอยืนยัน', 'สถานที่ที่แนะนำจากรูป', true);
      }
      return (name ?? 'สถานที่ที่ยืนยัน', null, true);
    }

    if (item.legacyMapId != null) {
      return ('สถานที่เดิม', 'ยังไม่ยืนยัน', true);
    }
    return ('Add Location', null, false);
  }

  @override
  Widget build(BuildContext context) {
    final (label, sublabel, pinned) = _locationLabel;
    final suggested =
        item.location?.status == ContentLocationStatus.suggested ||
            (item.legacyMapId != null && item.location == null);

    return DragTarget<PostPhotoMove>(
      onAcceptWithDetails: (details) => onDropImage(details.data),
      builder: (context, candidates, rejected) => DecoratedBox(
        decoration: BoxDecoration(
            border: candidates.isEmpty
                ? null
                : Border.all(color: AppColors.postPurple)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LocationRow(
              label: label,
              sublabel: sublabel,
              pinned: pinned,
              onTap: onPickPlace,
            ),
            if (suggested && onConfirmLocation != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onConfirmLocation,
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.postPurple),
                  child: const Text('ยืนยันสถานที่'),
                ),
              ),
            const _Hairline(),
            TextField(
              controller: item.bodyController,
              maxLength: 10000,
              minLines: 3,
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
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                counterText: '',
                hintText: 'Tell us about your trip..',
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
                          : Border.all(color: AppColors.postPurple, width: 3)),
                  child: LongPressDraggable<PostPhotoMove>(
                    data: (block: blockIndex, item: itemIndex, photo: index),
                    feedback: Material(
                      color: AppColors.postPurple,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(Icons.photo, color: Colors.white),
                      ),
                    ),
                    child: _BlockPhoto(
                      source: item.imagePaths[index],
                      unavailable:
                          unavailableImages.contains(item.imagePaths[index]),
                      isCover: item.imagePaths[index] == coverPath,
                      onSelectCover: onSelectCover == null
                          ? null
                          : () => onSelectCover!(item.imagePaths[index]),
                      onClear: () => onRemoveImage(index),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onMoveImage(index),
                  icon: const Icon(Icons.drive_file_move_outline, size: 18),
                  label: const Text('ย้ายรูป'),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.muted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Add Location", or the place over its distance and address once there is
/// one. Taking a pin off again happens in the sheet — the design's row carries
/// a chevron and nothing else.
class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.label,
    required this.sublabel,
    required this.pinned,
    required this.onTap,
  });

  final String label;

  /// "240 m. • ถนนพระสุเมรุ …", when the place came with either.
  final String? sublabel;

  /// A place is set, so the row reads as a value rather than a prompt.
  final bool pinned;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.paigunPinWell,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 18,
                  color: AppColors.locationPin,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pinned
                            ? AppColors.foreground
                            : AppColors.postFieldHint,
                        fontSize: 15,
                        fontWeight: pinned ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (sublabel != null && sublabel!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sublabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: Color(0xFF9A9A95),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                      ? AppColors.postPurple
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

/// The dashed row under the story: camera, gallery, video, and Trip Hack.
class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.onCapture,
    required this.onPickImage,
    required this.onExtra,
  });

  final VoidCallback onCapture;
  final VoidCallback onPickImage;
  final ValueChanged<PostSpotExtra> onExtra;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        PostAddChip(
          icon: Icons.photo_camera_outlined,
          tooltip: 'ถ่ายรูป',
          onTap: onCapture,
        ),
        PostAddChip(
          icon: Icons.photo_library_outlined,
          tooltip: 'รูปภาพ',
          onTap: onPickImage,
        ),
        PostAddChip(
          icon: Icons.videocam_outlined,
          tooltip: PostSpotExtra.video.label,
          onTap: () => onExtra(PostSpotExtra.video),
        ),
        PostAddChip(
          icon: Icons.info_outline,
          label: PostSpotExtra.tripHack.label,
          tooltip: PostSpotExtra.tripHack.label,
          onTap: () => onExtra(PostSpotExtra.tripHack),
        ),
      ],
    );
  }
}

/// One "add something" pill: a dashed well, and a label only when the glyph
/// alone would not say what it is.
class PostAddChip extends StatelessWidget {
  const PostAddChip({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.label,
  });

  final IconData icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = label;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: AppColors.screen,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(
              painter: const _DashedBorder(
                color: AppColors.postDashed,
                radius: 14,
              ),
              // No `alignment` here: under a Wrap's loose constraints it would
              // stretch every chip to the full width and stack them.
              child: Container(
                height: 48,
                constraints: const BoxConstraints(minWidth: 64),
                padding:
                    EdgeInsets.symmetric(horizontal: text == null ? 8 : 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: AppColors.postPurple),
                    if (text != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: const TextStyle(
                          color: AppColors.postPurple,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the three rows under the attachments.
class _ExtraRow extends StatelessWidget {
  const _ExtraRow({
    required this.icon,
    required this.extra,
    required this.onTap,
  });

  final IconData icon;
  final PostSpotExtra extra;
  final ValueChanged<PostSpotExtra> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(extra),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 21, color: AppColors.postRowIcon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  extra.label,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: Color(0xFF9A9A95),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.line);
}

/// Flutter has no dashed border; the attachment chips are the one place that
/// needs one.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 5.0, _gap = 4.0, _strokeWidth = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    for (final metric in outline.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = start + _dash;
        canvas.drawPath(
            metric.extractPath(start, end.clamp(0, metric.length)), paint);
        start = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

