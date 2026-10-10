import 'package:flutter/material.dart';

import '../../../../core/api/models/trip_content.dart';
import '../../../../core/theme/app_colors.dart';
import 'post_spot_details.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../domain/models/post_draft.dart';

class PostBlockItem {
  const PostBlockItem({
    required this.id,
    required this.bodyController,
    required this.imagePaths,
    this.place,
    this.location,
    this.legacyMapId,
    this.details = const PostSpotDetails(),
    this.locationFieldKey,
    this.locationHasError = false,
  });

  /// Stable across adds/removes/reorders — never the item's position.
  final String id;
  final TextEditingController bodyController;
  final List<String> imagePaths;
  final PostPlace? place;
  final ContentLocation? location;
  final String? legacyMapId;

  /// When to go, how to get there, and the tip — this item's own, never
  /// shared with any sibling under the same heading.
  final PostSpotDetails details;

  /// Where "เพิ่มจุดต่อไป"/"Next" scroll to when this item failed its
  /// location check, and whether it currently has.
  final Key? locationFieldKey;
  final bool locationHasError;
}

typedef PostPhotoMove = ({int block, int item, int photo});

/// The extras a spot offers that the trip API has no field for yet.
///
/// They are real rows in the design, so they are drawn; the screen answers for
/// them in one place rather than each row inventing somewhere to be stored.
enum PostSpotExtra {
  tripHack('Trip Hack'),
  recommendTime('เวลาที่แนะนำ'),
  howToGetHere('การเดินทาง'),
  contact('ติดต่อ');

  const PostSpotExtra(this.label);

  final String label;
}

/// One spot (จุด) of the post: its name, where it is, the story, the photos,
/// and the extras underneath.
///
/// The composer repeats this whole unit — "เพิ่มจุดต่อไป" adds the next one.
class PostBlock extends StatefulWidget {
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
    this.onRemove,
    this.locationErrorText,
  });

  final void Function((int, int), int)? onDropBeforeImage;
  final ValueChanged<int>? onMoveImage;
  final ValueChanged<(int, int)>? onDropImage;
  final List<PostBlockItem>? items;
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

  final VoidCallback onClearImage;
  final VoidCallback onPickPlace;
  final VoidCallback onClearPlace;

  /// Answers for the rows the API cannot store yet — per item, since each
  /// item in a section has its own now.
  final void Function(int itemIndex, PostSpotExtra extra) onExtra;

  /// Null on the only spot — a post always keeps one.
  final VoidCallback? onRemove;

  /// The message every flagged item's row shows — the per-item key/flag
  /// themselves live on each `PostBlockItem` now, not here.
  final String? locationErrorText;

  @override
  State<PostBlock> createState() => _PostBlockState();
}

class _PostBlockState extends State<PostBlock> {
  @override
  void initState() {
    super.initState();
    widget.titleController.addListener(_refresh);
    widget.titleFocus.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.titleController.removeListener(_refresh);
    widget.titleFocus.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final blockItems = widget.items ??
        [
          PostBlockItem(
              // The single-item legacy fallback below `widget.items` never has
              // a sibling to disambiguate from, so a constant id is fine.
              id: 'legacy',
              bodyController: widget.bodyController,
              imagePaths: [
                ...widget.imagePaths,
                if (widget.imagePath != null) widget.imagePath!
              ],
              place: widget.place)
        ];

    return DragTarget<PostPhotoMove>(
      onAcceptWithDetails: (drop) =>
          (widget.onDropImageInItem ?? _legacyDropImage)(drop.data, 0),
      builder: (context, candidates, rejected) => Container(
        decoration: BoxDecoration(
          border: candidates.isEmpty
              ? null
              : Border.all(color: AppColors.postPurple),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.onRemove != null)
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: widget.onRemove,
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
            _TitleRow(
              controller: widget.titleController,
              focusNode: widget.titleFocus,
            ),
            const _Hairline(),
            for (var item = 0; item < blockItems.length; item++) ...[
              if (item > 0) const _Hairline(),
              _PostBlockContentItem(
                key: ValueKey(blockItems[item].id),
                blockIndex: widget.blockIndex,
                itemIndex: item,
                item: blockItems[item],
                locationFieldKey: blockItems[item].locationFieldKey,
                locationHasError: blockItems[item].locationHasError,
                locationErrorText: widget.locationErrorText,
                onExtra: (extra) => widget.onExtra(item, extra),
                unavailableImages: widget.unavailableImages,
                coverPath: widget.coverPath,
                onSelectCover: widget.onSelectCover,
                onPickImage: () {
                  final handler = widget.onPickImageInItem;
                  if (handler == null) {
                    widget.onPickImage();
                  } else {
                    handler(item);
                  }
                },
                onRemoveImage: (photo) => (widget.onRemoveImageInItem ??
                    _legacyRemoveImage)(item, photo),
                onMoveImage: (photo) =>
                    (widget.onMoveImageInItem ?? _legacyMoveImage)(item, photo),
                onDropImage: (move) =>
                    (widget.onDropImageInItem ?? _legacyDropImage)(move, item),
                onDropBeforeImage: (move, position) =>
                    (widget.onDropBeforeImageInItem ?? _legacyDropBeforeImage)(
                        move, item, position),
                onPickPlace: () =>
                    (widget.onPickPlaceInItem ?? _legacyPickPlace)(item),
                onClearPlace: () =>
                    (widget.onClearPlaceInItem ?? _legacyClearPlace)(item),
                onConfirmLocation: widget.onConfirmLocationInItem == null
                    ? null
                    : () => widget.onConfirmLocationInItem!(item),
              ),
              if (blockItems.length > 1 && widget.onRemoveItem != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => widget.onRemoveItem!(item),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('ลบชุดข้อมูลนี้'),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.muted),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            const _Hairline(),
          ],
        ),
      ),
    );
  }

  void _legacyMoveImage(int item, int photo) {
    if (item == 0) widget.onMoveImage?.call(photo);
  }

  void _legacyRemoveImage(int item, int photo) {
    if (item == 0) widget.onRemoveImage?.call(photo);
  }

  void _legacyDropImage(PostPhotoMove move, int item) {
    if (item == 0) widget.onDropImage?.call((move.block, move.photo));
  }

  void _legacyDropBeforeImage(PostPhotoMove move, int item, int position) {
    if (item == 0)
      widget.onDropBeforeImage?.call((move.block, move.photo), position);
  }

  void _legacyPickPlace(int item) {
    if (item == 0) widget.onPickPlace();
  }

  void _legacyClearPlace(int item) {
    if (item == 0) widget.onClearPlace();
  }
}

/// The spot's heading: a purple + and the name beside it, which is how the
/// design offers it — one line, no label.
/// The spot's heading, once the options row has asked for it.
class _TitleRow extends StatefulWidget {
  const _TitleRow({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  State<_TitleRow> createState() => _TitleRowState();
}

class _TitleRowState extends State<_TitleRow> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // The plus stays on a filled row too, as the design draws it.
        IconButton(
          onPressed: widget.focusNode.requestFocus,
          icon: const Icon(Icons.add, size: 21),
          color: AppColors.postPurple,
          tooltip: 'ตั้งชื่อหัวข้อ',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: widget.controller,
            maxLength: 200,
            focusNode: widget.focusNode,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              counterText: '',
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
              hintText: 'ชื่อหัวข้อ  (เช่น รวมร้านอาหาร, จุดห้ามพลาด)',
              hintStyle: TextStyle(
                color: AppColors.postFieldHint,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small "+ something" pill for a part of the post that is optional.
///
/// The composer's default state should read as the shortest post worth
/// publishing; anything beyond that announces itself as a choice rather than
/// as a blank waiting to be filled.
class PostAddOption extends StatelessWidget {
  const PostAddOption({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: CustomPaint(
        painter:
            const PostDashedBorder(radius: 99, color: AppColors.postDashed),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 15, color: AppColors.postPurple),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.postPurple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostBlockContentItem extends StatelessWidget {
  const _PostBlockContentItem({
    super.key,
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
    required this.onExtra,
    this.locationFieldKey,
    this.locationHasError = false,
    this.locationErrorText,
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

  /// Answers for this item's own rows the API cannot store yet.
  final ValueChanged<PostSpotExtra> onExtra;

  /// Where "+ เพิ่มจุดต่อไป"/"Next" scroll to when this item failed its
  /// location check.
  final Key? locationFieldKey;
  final bool locationHasError;
  final String? locationErrorText;

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
        // Not "จากรูป": a suggestion can come from the photo's coordinates, from
        // a sign the assistant read in the picture, or from where the traveller
        // is standing. Which one it was is spelled out in the picker, where
        // there is room to say it and a decision to make.
        return (name ?? 'รอยืนยัน', 'ผู้ช่วยแนะนำ ยังไม่ยืนยัน', true);
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
            // The row itself is only worth showing once there's something to
            // show — a pinned place, or a validation error to explain. The
            // empty, nothing-picked-yet state is the chip's job now.
            if (pinned || locationHasError)
              _LocationRow(
                key: locationFieldKey,
                label: label,
                sublabel: sublabel,
                pinned: pinned,
                onTap: onPickPlace,
                hasError: locationHasError,
                errorText: locationErrorText,
              ),
            if (suggested && onConfirmLocation != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onConfirmLocation,
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.postPurple),
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
                  style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                ),
              ),
            ],
            if (!item.details.isEmpty) ...[
              const SizedBox(height: 4),
              PostSpotDetailRows(
                details: item.details,
                onEdit: (detail) => onExtra(switch (detail) {
                  PostSpotDetail.time => PostSpotExtra.recommendTime,
                  PostSpotDetail.transport => PostSpotExtra.howToGetHere,
                  PostSpotDetail.hack => PostSpotExtra.tripHack,
                  PostSpotDetail.contact => PostSpotExtra.contact,
                }),
              ),
            ],
            const SizedBox(height: 10),
            _ItemExtrasRow(
              onPickImage: onPickImage,
              onPickPlace: onPickPlace,
              onExtra: onExtra,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Add Location", required (the asterisk), or the place over its distance
/// and address once there is one. Taking a pin off again happens in the
/// sheet — the row itself carries only a chevron, plus an error glyph and a
/// line of help text underneath once validation has failed it.
class _LocationRow extends StatelessWidget {
  const _LocationRow({
    super.key,
    required this.label,
    required this.sublabel,
    required this.pinned,
    required this.onTap,
    this.hasError = false,
    this.errorText,
  });

  final String label;

  /// "240 m. • ถนนพระสุเมรุ …", when the place came with either.
  final String? sublabel;

  /// A place is set, so the row reads as a value rather than a prompt.
  final bool pinned;

  final VoidCallback onTap;

  /// "เพิ่มจุดต่อไป"/"Next" asked for a location and this spot had none.
  final bool hasError;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final tint = hasError ? AppColors.brandOrangeDeep : AppColors.postPurple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: hasError
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.brandOrangeDeep),
                  ),
                )
              : const BoxDecoration(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    // A plain purple pin, the size of the heading's plus
                    // above it — this pass drops the tinted plate the last
                    // one had.
                    SizedBox(
                      width: 34,
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 21,
                        color: tint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: hasError
                                        ? AppColors.brandOrangeDeep
                                        : pinned
                                            ? AppColors.foreground
                                            : AppColors.postFieldHint,
                                    fontSize: 15,
                                    fontWeight: pinned
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (!pinned)
                                Text(
                                  '*',
                                  style: TextStyle(
                                    color: hasError
                                        ? AppColors.brandOrangeDeep
                                        : AppColors.postFieldHint,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
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
                    if (hasError) ...[
                      const Icon(
                        Icons.error,
                        size: 18,
                        color: AppColors.brandOrangeDeep,
                      ),
                      const SizedBox(width: 6),
                    ],
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right,
                      size: 22,
                      color: Color(0xFF9A9A95),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError && errorText != null && errorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 46, bottom: 4),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: AppColors.brandOrangeDeep,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
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

/// One item's own "+ something" chips — add a photo, then when to go, how to
/// get there, who to call, the one tip worth passing on. Independent per
/// item, so the same row appears once under every content item in a
/// section, not once for the whole heading.
class _ItemExtrasRow extends StatelessWidget {
  const _ItemExtrasRow({
    required this.onPickImage,
    required this.onPickPlace,
    required this.onExtra,
  });

  final VoidCallback onPickImage;
  final VoidCallback onPickPlace;
  final ValueChanged<PostSpotExtra> onExtra;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(children: [
        PostAddChip(
          icon: Icons.add_photo_alternate_outlined,
          tooltip: 'รูปภาพ',
          onTap: onPickImage,
        ),
        const SizedBox(width: 8),
        PostAddChip(
          icon: Icons.location_on_outlined,
          tooltip: 'Add Location',
          onTap: onPickPlace,
        ),
        const SizedBox(width: 8),
        PostAddChip(
          icon: Icons.schedule,
          tooltip: PostSpotExtra.recommendTime.label,
          onTap: () => onExtra(PostSpotExtra.recommendTime),
        ),
        const SizedBox(width: 8),
        PostAddChip(
          icon: Icons.directions_car_outlined,
          tooltip: PostSpotExtra.howToGetHere.label,
          onTap: () => onExtra(PostSpotExtra.howToGetHere),
        ),
        const SizedBox(width: 8),
        PostAddChip(
          icon: Icons.call_outlined,
          label: PostSpotExtra.contact.label,
          tooltip: PostSpotExtra.contact.label,
          onTap: () => onExtra(PostSpotExtra.contact),
        ),
        const SizedBox(width: 8),
        PostAddChip(
          icon: Icons.info_outline,
          label: PostSpotExtra.tripHack.label,
          tooltip: PostSpotExtra.tripHack.label,
          onTap: () => onExtra(PostSpotExtra.tripHack),
        ),
      ]),
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
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: CustomPaint(
              painter: const PostDashedBorder(
                color: AppColors.postDashed,
                radius: 11,
              ),
              child: Container(
                height: 36,
                constraints: const BoxConstraints(minWidth: 46),
                padding:
                    EdgeInsets.symmetric(horizontal: text == null ? 6 : 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: AppColors.postPurple),
                    if (text != null) ...[
                      const SizedBox(width: 5),
                      Text(
                        text,
                        style: const TextStyle(
                          color: AppColors.postPurple,
                          fontSize: 12,
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

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.line);
}

/// Flutter has no dashed border, and this design leans on one: the attachment
/// chips and the "เพิ่มจุดต่อไป" button.
class PostDashedBorder extends CustomPainter {
  const PostDashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 5.0, _gap = 4.0, _strokeWidth = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
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
  bool shouldRepaint(PostDashedBorder old) =>
      old.color != color || old.radius != radius;
}
