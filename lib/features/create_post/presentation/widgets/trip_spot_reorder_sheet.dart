import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';

/// One spot as the reorder sheet shows it — a read-only snapshot, not the
/// live `_BlockFields`: this sheet only ever needs to display and reorder,
/// never edit.
@immutable
class ReorderableSpot {
  const ReorderableSpot({
    required this.id,
    required this.title,
    required this.placeCount,
    this.thumbnailPath,
  });

  /// The block's own stable id — never the screen position, which changes
  /// the moment anything is reordered or deleted.
  final String id;
  final String title;
  final String? thumbnailPath;
  final int placeCount;
}

/// "จัดเรียงลำดับหัวข้อ" — drag to reorder, tap the bin to delete. Both act
/// immediately on the caller's own data through [onReorder]/[onDelete]; this
/// sheet only keeps its own copy to animate the list while it is open.
Future<void> showTripSpotReorderSheet(
  BuildContext context, {
  required List<ReorderableSpot> spots,
  required void Function(int oldIndex, int newIndex) onReorder,
  required ValueChanged<String> onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => TripSpotReorderSheet(
      spots: spots,
      onReorder: onReorder,
      onDelete: onDelete,
    ),
  );
}

class TripSpotReorderSheet extends StatefulWidget {
  const TripSpotReorderSheet({
    super.key,
    required this.spots,
    required this.onReorder,
    required this.onDelete,
  });

  final List<ReorderableSpot> spots;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<String> onDelete;

  @override
  State<TripSpotReorderSheet> createState() => _TripSpotReorderSheetState();
}

class _TripSpotReorderSheetState extends State<TripSpotReorderSheet> {
  late final List<ReorderableSpot> _items = List.of(widget.spots);

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    widget.onReorder(oldIndex, newIndex);
  }

  void _delete(int index) {
    final spot = _items[index];
    setState(() => _items.removeAt(index));
    widget.onDelete(spot.id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // Material, not a decorated box: the rows paint their ink on the
      // nearest Material and assert when a coloured box sits in between.
      child: Material(
        color: AppColors.screen,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D6D1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'จัดเรียงลำดับหัวข้อ',
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _items.length,
                    onReorderItem: _reorder,
                    itemBuilder: (context, index) => TripSpotReorderItem(
                      key: ValueKey(_items[index].id),
                      index: index,
                      spot: _items[index],
                      canDelete: _items.length > 1,
                      onDelete: () => _delete(index),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row: a drag handle, a thumbnail if the spot has a photo, its place
/// count, its title (or the empty-state label), and a delete button —
/// disabled on the last remaining spot, the same rule the composer's own
/// "ลบจุดนี้" already follows.
class TripSpotReorderItem extends StatelessWidget {
  const TripSpotReorderItem({
    super.key,
    required this.index,
    required this.spot,
    required this.canDelete,
    required this.onDelete,
  });

  final int index;
  final ReorderableSpot spot;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = spot.title.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.drag_indicator, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.postField,
              borderRadius: BorderRadius.circular(10),
            ),
            child: spot.thumbnailPath == null
                ? const Icon(Icons.image_outlined,
                    color: AppColors.muted, size: 20)
                : CoverImage(source: spot.thumbnailPath!),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spot ${index + 1} • ${spot.placeCount} place'
                  '${spot.placeCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'หัวข้อ: ${title.isEmpty ? '(ยังไม่ตั้งชื่อ)' : title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: canDelete ? 'ลบจุดนี้' : 'ต้องมีอย่างน้อยหนึ่งจุด',
            onPressed: canDelete ? onDelete : null,
            icon: Icon(Icons.delete_outline,
                color: canDelete ? AppColors.postShare : AppColors.muted),
          ),
        ],
      ),
    );
  }
}
