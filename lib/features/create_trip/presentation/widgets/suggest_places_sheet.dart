import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../trips/presentation/itinerary_display.dart';
import '../../domain/plan_labels.dart';
import '../providers/suggest_places_providers.dart';

const _sheetOrange = AppColors.brandOrange;
const _confirmBrown = Color(0xFF4A2F2A);
const _chipActive = Color(0xFFE7F2E9);
const _chipActiveText = Color(0xFF2E6B4C);

/// Opens แนะนำสถานที่ for [dayId].
///
/// Returns true when at least one stop was added, so the caller knows to
/// refresh the trip. [latitude]/[longitude] anchor the suggestions.
Future<bool> showSuggestPlacesSheet(
  BuildContext context, {
  required String tripId,
  required String dayId,
  required int dayNumber,
  required double latitude,
  required double longitude,
}) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // The design leaves the trip header showing behind the sheet.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    builder: (_) => SuggestPlacesSheet(
      tripId: tripId,
      dayId: dayId,
      dayNumber: dayNumber,
      latitude: latitude,
      longitude: longitude,
    ),
  );
  return added ?? false;
}

class SuggestPlacesSheet extends ConsumerStatefulWidget {
  const SuggestPlacesSheet({
    super.key,
    required this.tripId,
    required this.dayId,
    required this.dayNumber,
    required this.latitude,
    required this.longitude,
  });

  final String tripId;
  final String dayId;
  final int dayNumber;
  final double latitude;
  final double longitude;

  @override
  ConsumerState<SuggestPlacesSheet> createState() => _SuggestPlacesSheetState();
}

class _SuggestPlacesSheetState extends ConsumerState<SuggestPlacesSheet> {
  /// 0 = pick places, 1 = fill in their details.
  int _step = 0;

  String _categoryLabel = 'ทั้งหมด';
  bool _searchOpen = false;
  String _search = '';
  final _searchController = TextEditingController();

  /// Selection order is the order they will be added to the day, so this is a
  /// list rather than a set.
  final List<Place> _picked = <Place>[];
  final Map<String, _StopDraft> _drafts = <String, _StopDraft>{};
  String? _expandedId;

  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  SuggestQuery get _query => SuggestQuery(
        latitude: widget.latitude,
        longitude: widget.longitude,
        category: placeCategoryByLabel[_categoryLabel],
        search: _search,
      );

  bool _isPicked(Place place) => _picked.any((p) => p.id == place.id);

  void _toggle(Place place) {
    setState(() {
      final at = _picked.indexWhere((p) => p.id == place.id);
      if (at >= 0) {
        _picked.removeAt(at);
        _drafts.remove(place.id)?.dispose();
      } else {
        _picked.add(place);
        _drafts[place.id] = _StopDraft.forPlace(place);
      }
    });
  }

  void _clearPicked() {
    setState(() {
      _picked.clear();
      for (final draft in _drafts.values) {
        draft.dispose();
      }
      _drafts.clear();
      _expandedId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(onClose: () => Navigator.of(context).pop(false)),
          Expanded(
            child: _step == 0 ? _browseStep() : _detailsStep(),
          ),
          _BottomBar(
            note: _barNote(),
            count: _picked.length,
            onClear: _picked.isEmpty ? null : _clearPicked,
            leftLabel: _step == 0 ? 'ยกเลิก' : 'ย้อนกลับ',
            onLeft: _saving
                ? null
                : () {
                    if (_step == 0) {
                      Navigator.of(context).pop(false);
                    } else {
                      setState(() => _step = 0);
                    }
                  },
            rightLabel: _step == 0 ? 'ถัดไป' : 'เพิ่มลงแผน',
            rightColor: _step == 0 ? _sheetOrange : _confirmBrown,
            onRight: _picked.isEmpty || _saving
                ? null
                : () {
                    if (_step == 0) {
                      setState(() => _step = 1);
                    } else {
                      _submit();
                    }
                  },
            busy: _saving,
          ),
        ],
      ),
    );
  }

  String _barNote() {
    if (_picked.isEmpty) return 'ยังไม่ได้เลือกสถานที่';
    if (_step == 0) return 'กด "ถัดไป" เพื่อใส่รายละเอียด';
    return 'สถานที่';
  }

  // ---------- step 1: pick ----------

  Widget _browseStep() {
    final places = ref.watch(suggestedPlacesProvider(_query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: _searchOpen
              ? _SearchField(
                  controller: _searchController,
                  onSubmit: (value) => setState(() => _search = value),
                  onClose: () => setState(() {
                    _searchOpen = false;
                    _search = '';
                    _searchController.clear();
                  }),
                )
              : _CategoryRow(
                  selected: _categoryLabel,
                  onSelect: (label) => setState(() => _categoryLabel = label),
                  onOpenSearch: () => setState(() => _searchOpen = true),
                ),
        ),
        Expanded(
          child: places.when(
            data: (list) => list.isEmpty
                ? const _Empty(
                    title: 'ไม่พบสถานที่',
                    detail: 'ลองเปลี่ยนประเภทหรือคำค้นหา',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _PlaceCard(
                      place: list[i],
                      picked: _isPicked(list[i]),
                      onTap: () => _toggle(list[i]),
                    ),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            // Say what the server said. A generic "check your connection"
            // hid a 400 here once already.
            error: (error, __) => _Empty(
              title: 'โหลดสถานที่ไม่สำเร็จ',
              detail: error is ApiException
                  ? error.message
                  : 'ตรวจการเชื่อมต่อแล้วลองใหม่',
            ),
          ),
        ),
      ],
    );
  }

  // ---------- step 2: details ----------

  Widget _detailsStep() {
    if (_picked.isEmpty) {
      return const _Empty(
        title: 'ยังไม่มีสถานที่ที่เลือก',
        detail: 'กดย้อนกลับเพื่อเลือกสถานที่ที่ต้องการเพิ่ม',
        icon: Icons.close,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        const Text(
          'รายละเอียดเพิ่มสถานที่',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        // The sheet is opened from one day, and the design shows no day
        // anywhere — say it, so nobody adds five stops to the wrong day.
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'เพิ่มลงวันที่ ${widget.dayNumber}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final place in _picked) ...[
          _DraftCard(
            place: place,
            draft: _drafts[place.id]!,
            expanded: _expandedId == place.id,
            onToggle: () => setState(
              () => _expandedId = _expandedId == place.id ? null : place.id,
            ),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ---------- saving ----------

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final api = await ref.read(plunoApiProvider.future);
      // Routing is left until the whole batch is in, so the legs are
      // calculated once against the final order rather than after each stop.
      for (final place in _picked) {
        final draft = _drafts[place.id]!;
        await api.itinerary.addItem(
          widget.dayId,
          placeId: place.id,
          startTime: draft.time,
          category: draft.category,
          costAmount: draft.cost,
          costCurrency: draft.cost == null ? null : draft.currency,
          notes: draft.notes,
          calculateTravelSegments: false,
        );
      }
      await api.itinerary.retryTravelSegments(widget.tripId);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (failure) {
      _fail('เพิ่มสถานที่ไม่สำเร็จ: ${failure.message}');
    } catch (error) {
      _fail('เพิ่มสถานที่ไม่สำเร็จ: $error');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The per-place form on step 2, and the values it will send.
class _StopDraft {
  _StopDraft({
    required this.category,
    required this.notesController,
    required this.costController,
    required this.timeOfDay,
  });

  factory _StopDraft.forPlace(Place place) => _StopDraft(
        // The server derives this from the place anyway; pre-filling it means
        // the dropdown never opens on a blank.
        category: place.category?.asActivityCategory ?? ActivityCategory.other,
        notesController: TextEditingController(),
        costController: TextEditingController(text: '0'),
        timeOfDay: const TimeOfDay(hour: 10, minute: 30),
      );

  ActivityCategory category;
  TimeOfDay timeOfDay;
  String currency = 'THB';
  final TextEditingController notesController;
  final TextEditingController costController;

  /// `HH:mm`, the shape the itinerary API stores.
  String get time => '${timeOfDay.hour.toString().padLeft(2, '0')}:'
      '${timeOfDay.minute.toString().padLeft(2, '0')}';

  /// Null rather than zero, so an untouched field does not write a ฿0 line.
  double? get cost {
    final parsed =
        double.tryParse(costController.text.trim().replaceAll(',', ''));
    return parsed != null && parsed > 0 ? parsed : null;
  }

  String? get notes {
    final text = notesController.text.trim();
    return text.isEmpty ? null : text;
  }

  void dispose() {
    notesController.dispose();
    costController.dispose();
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
      child: Row(
        children: [
          const SizedBox(width: 34),
          const Expanded(
            child: Text(
              'แนะนำสถานที่',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Tooltip(
            message: 'ปิด',
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDEDED),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.close, size: 19, color: Color(0xFF6B6B6B)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.selected,
    required this.onSelect,
    required this.onOpenSearch,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'ค้นหา',
          child: GestureDetector(
            onTap: onOpenSearch,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1614),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, size: 20, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final label in placeCategoryByLabel.keys) ...[
                  _Chip(
                    label: label,
                    active: label == selected,
                    onTap: () => onSelect(label),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? _chipActive : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active
                ? _chipActiveText.withValues(alpha: 0.45)
                : AppColors.chipBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? _chipActiveText : AppColors.foreground,
            fontSize: 13,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmit,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmit,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'ค้นหาชื่อที่ ย่าน หรือประเภท',
                hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Tooltip(
            message: 'ค้นหา',
            child: GestureDetector(
              onTap: () => onSubmit(controller.text),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1614),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward,
                    size: 18, color: Colors.white),
              ),
            ),
          ),
          Tooltip(
            message: 'ปิดการค้นหา',
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.picked,
    required this.onTap,
  });

  final Place place;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: picked ? _sheetOrange : AppColors.line,
          width: picked ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.32,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if ((place.imageUrl ?? '').isEmpty)
                  const ColoredBox(
                    color: Color(0xFFEFEFEC),
                    child: Icon(Icons.image_outlined,
                        size: 26, color: AppColors.muted),
                  )
                else
                  CoverImage(source: place.imageUrl!, fit: BoxFit.cover),
                Positioned(
                  left: 7,
                  bottom: 7,
                  child: _Badge(
                    icon: Icons.star,
                    label: place.rating == null
                        ? '—'
                        : place.rating!.toStringAsFixed(1),
                  ),
                ),
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: _Badge(
                    icon: Icons.local_offer_outlined,
                    label: placeCategoryLabel(place.category),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 30,
                  child: Text(
                    place.address ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: picked ? _sheetOrange : Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: picked
                            ? _sheetOrange
                            : _sheetOrange.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          picked ? Icons.check : Icons.add,
                          size: 15,
                          color: picked ? Colors.white : _sheetOrange,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          picked ? 'เพิ่มแล้ว' : 'เพิ่มแผน',
                          style: TextStyle(
                            color: picked ? Colors.white : _sheetOrange,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.detail,
    this.icon = Icons.search_off,
  });

  final String title;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFEDEDED),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.place,
    required this.draft,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
  });

  final Place place;
  final _StopDraft draft;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: (place.imageUrl ?? '').isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFEFEFEC),
                          child: Icon(Icons.place_outlined,
                              size: 20, color: AppColors.muted),
                        )
                      : CoverImage(source: place.imageUrl!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((place.address ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        place.address!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: expanded ? 'ย่อรายละเอียด' : 'แก้ไขรายละเอียด',
                child: GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2F2F0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      expanded ? Icons.expand_less : Icons.edit_outlined,
                      size: 17,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (expanded) _form(context),
      ],
    );
  }

  Widget _form(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('เวลา'),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: draft.timeOfDay,
              );
              if (picked != null) {
                draft.timeOfDay = picked;
                onChanged();
              }
            },
            child: _FieldBox(
              child: Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 17, color: AppColors.foreground),
                  const SizedBox(width: 9),
                  Text(
                    // The plan itself prints "10:30 AM"; TimeOfDay.format
                    // would follow the device's 24-hour setting instead.
                    clockLabel(draft.time),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('ประเภท'),
          _FieldBox(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ActivityCategory>(
                value: draft.category,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  for (final entry in categoryLabels.entries)
                    DropdownMenuItem(
                        value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  draft.category = value;
                  onChanged();
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('ค่าใช้จ่าย (ต่อคน)'),
          Row(
            children: [
              Expanded(
                child: _FieldBox(
                  child: TextField(
                    controller: draft.costController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '0',
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _FieldBox(
                width: 96,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: draft.currency,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'THB', child: Text('THB')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'LAK', child: Text('LAK')),
                      DropdownMenuItem(value: 'VND', child: Text('VND')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      draft.currency = value;
                      onChanged();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _FieldLabel('เพิ่มโน้ต'),
          _FieldBox(
            child: TextField(
              controller: draft.notesController,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'เช่น ต้องไปถึงก่อนเวลาเปิด',
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: child,
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.note,
    required this.count,
    required this.onClear,
    required this.leftLabel,
    required this.onLeft,
    required this.rightLabel,
    required this.rightColor,
    required this.onRight,
    required this.busy,
  });

  final String note;
  final int count;
  final VoidCallback? onClear;
  final String leftLabel;
  final VoidCallback? onLeft;
  final String rightLabel;
  final Color rightColor;
  final VoidCallback? onRight;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final empty = count == 0;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      // Bottom insets belong in the bar's own padding — a SafeArea around it
      // lifts the panel off the edge and shows the page beneath.
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: empty ? const Color(0xFFF5F5F3) : const Color(0xFFFFF4EE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: empty
                    ? AppColors.line
                    : _sheetOrange.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: empty ? const Color(0xFFDDDDDA) : _sheetOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: empty ? AppColors.muted : AppColors.foreground,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClear,
                  child: Text(
                    'ล้างที่เลือก',
                    style: TextStyle(
                      color: onClear == null
                          ? AppColors.muted
                          : AppColors.foreground,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onLeft,
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.chipBorder),
                    ),
                    child: Text(
                      leftLabel,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onRight,
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: onRight == null
                          ? const Color(0xFFE3E3E0)
                          : rightColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            rightLabel,
                            style: TextStyle(
                              color: onRight == null
                                  ? AppColors.muted
                                  : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
