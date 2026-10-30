import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../trips/presentation/itinerary_display.dart';
import 'location_picker_sheet.dart';

/// One day the new stop can be filed under.
class AddPlaceDay {
  const AddPlaceDay({
    required this.id,
    required this.number,
    required this.label,
  });

  final String id;
  final int number;

  /// "Sat, 20 Aug", or empty on a trip whose dates are still open.
  final String label;

  String get menuLabel => label.isEmpty ? 'วันที่ $number' : label;
}

/// What the traveller did with the sheet.
enum AddPlaceOutcome {
  cancelled,

  /// A stop was added, so the caller reloads the trip.
  added,

  /// An existing stop was saved, so the caller reloads the trip.
  updated,

  /// They asked for the place explorer instead. The caller opens it — sheets
  /// stacked on sheets leave the traveller with two scrims to dismiss.
  explore,
}

/// เพิ่มสถานที่ — the manual way to put a stop in the plan, for when the
/// traveller already knows where they are going.
Future<AddPlaceOutcome> showAddPlaceSheet(
  BuildContext context, {
  required String tripId,
  required List<AddPlaceDay> days,
  required String initialDayId,
  Activity? editing,
}) async {
  final outcome = await showModalBottomSheet<AddPlaceOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // The design keeps the plan visible above the sheet.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder: (_) => AddPlaceSheet(
      tripId: tripId,
      days: days,
      initialDayId: initialDayId,
      editing: editing,
    ),
  );
  return outcome ?? AddPlaceOutcome.cancelled;
}

class AddPlaceSheet extends ConsumerStatefulWidget {
  const AddPlaceSheet({
    super.key,
    required this.tripId,
    required this.days,
    required this.initialDayId,
    this.editing,
  });

  final String tripId;
  final List<AddPlaceDay> days;
  final String initialDayId;

  /// The stop being edited. Null means the sheet adds a new one; set, the same
  /// form opens filled in and saves with `PATCH /items/:id`.
  final Activity? editing;

  @override
  ConsumerState<AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends ConsumerState<AddPlaceSheet> {
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();

  late String _dayId;
  TimeOfDay? _time;
  ActivityCategory? _category;
  String _currency = 'THB';
  final List<XFile> _photos = <XFile>[];
  bool _saving = false;

  /// Where the stop happens — one of our `places`, kept apart from the
  /// activity name. The server titles a stop `customName ?? place.name`, so
  /// both can be set: "ทานอาหารเช้า" at "ร้านโจ๊กสามย่าน".
  String? _placeId;
  String? _placeName;

  /// What edit mode opened with, so only real changes go up.
  String? _initialPlaceId;
  String _initialName = '';

  @override
  void initState() {
    super.initState();
    _dayId = widget.initialDayId;
    final stop = widget.editing;
    if (stop != null) {
      final location = stop.location;
      _placeId = location?.placeId;
      _placeName = location?.name;
      _initialPlaceId = _placeId;
      // The response has no customName: a title equal to the place's name
      // means the stop is just the place, so the name field starts empty
      // rather than repeating the location underneath it.
      _initialName =
          location != null && stop.title == location.name ? '' : stop.title;
      _nameController.text = _initialName;
      _time = _parseTime(stop.time);
      _category = stop.category;
      if (stop.cost > 0) _costController.text = _trimCost(stop.cost);
      _notesController.text = stop.notes ?? '';
    }
    _nameController.addListener(_refresh);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _nameController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _isEditing => widget.editing != null;

  static TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _trimCost(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);

  /// A stop needs a name or a place — the server takes either, and rejects a
  /// stop with neither. Everything else on the form is optional.
  bool get _canAdd =>
      (_nameController.text.trim().isNotEmpty || _placeId != null) && !_saving;

  Future<void> _pickLocation() async {
    final name = _nameController.text.trim();
    final picked = await showLocationPicker(
      context,
      // The name is often the place ("วัดเชียงทอง"), so start the search there.
      initial: _placeId != null ? null : (name.isEmpty ? null : name),
      hasPlace: _placeId != null,
    );
    if (picked == null || !mounted) return;
    if (identical(picked, clearedLocation) || picked.id.isEmpty) {
      _clearLocation();
      return;
    }
    setState(() {
      _placeId = picked.id;
      _placeName = picked.name;
    });
  }

  void _clearLocation() => setState(() {
        _placeId = null;
        _placeName = null;
      });

  double? get _cost {
    final parsed =
        double.tryParse(_costController.text.trim().replaceAll(',', ''));
    return parsed != null && parsed > 0 ? parsed : null;
  }

  String? get _startTime {
    final time = _time;
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _addPhotos() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;
    setState(() => _photos.addAll(picked));
  }

  /// Replaces one image in place, which is what a pencil on a thumbnail means.
  Future<void> _replacePhoto(int index) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _photos[index] = picked);
  }

  Future<void> _submit() async {
    if (!_canAdd) return;
    if (_isEditing) return _save();
    setState(() => _saving = true);
    // Held because the snackbar below is shown after this sheet has gone.
    final messenger = ScaffoldMessenger.of(context);
    final String activityId;
    try {
      final api = await ref.read(plunoApiProvider.future);
      final name = _nameController.text.trim();
      final created = await api.itinerary.addItem(
        _dayId,
        customName: name.isEmpty ? null : name,
        placeId: _placeId,
        startTime: _startTime,
        category: _category,
        costAmount: _cost,
        costCurrency: _cost == null ? null : _currency,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        // Legs are recalculated once at the end rather than per write.
        calculateTravelSegments: false,
      );
      activityId = created.activity.id;
    } on ApiException catch (failure) {
      _fail('เพิ่มสถานที่ไม่สำเร็จ: ${failure.message}');
      return;
    } catch (error) {
      _fail('เพิ่มสถานที่ไม่สำเร็จ: $error');
      return;
    }

    // The stop exists from here on. Anything that fails below is follow-up
    // work, and saying "เพิ่มสถานที่ไม่สำเร็จ" for it would be a lie that
    // also invites a second tap — and a duplicate stop.
    final problem = await _afterWrite(activityId);

    if (!mounted) return;
    Navigator.of(context).pop(AddPlaceOutcome.added);
    if (problem != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  /// Pushes the picked photos at the stop the server just made. Returns a
  /// message when they did not make it, or null when there was nothing to
  /// send or it all went up.
  Future<String?> _uploadPhotos(String activityId) async {
    if (_photos.isEmpty) return null;
    try {
      final api = await ref.read(plunoApiProvider.future);
      for (final photo in _photos) {
        await api.media.upload(
          widget.tripId,
          filePath: photo.path,
          activityId: activityId,
        );
      }
      return null;
    } catch (error) {
      debugPrint('Stop photo upload failed: $error');
      return 'บันทึกสถานที่แล้ว แต่อัปโหลดรูปไม่สำเร็จ';
    }
  }

  /// Uploads the photos and asks the server to re-measure the legs, reporting
  /// only what the traveller can act on. Returns null when all was well.
  Future<String?> _afterWrite(String activityId) async {
    String? problem;
    final api = await ref.read(plunoApiProvider.future);

    problem = await _uploadPhotos(activityId);

    try {
      await api.itinerary.retryTravelSegments(widget.tripId);
    } catch (error) {
      // The legs are re-measured on later writes too, and a missing one shows
      // as a blank leg rather than wrong information — not worth a message.
      debugPrint('Leg re-measure failed: $error');
    }
    return problem;
  }

  /// Edit mode: send only what changed. A field the traveller emptied is a
  /// `Patch.clear()`, not a missing key — a missing key means "leave it".
  Future<void> _save() async {
    final stop = widget.editing!;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    String? photoProblem;
    try {
      final api = await ref.read(plunoApiProvider.future);
      final name = _nameController.text.trim();
      final notes = _notesController.text.trim();
      final oldNotes = (stop.notes ?? '').trim();
      final cost = _cost;

      await api.itinerary.updateItem(
        stop.id,
        customName: name == _initialName
            ? null
            : (name.isEmpty ? const Patch.clear() : Patch.value(name)),
        // Clearing both is a 400; [_canAdd] keeps one of them set.
        placeId: _placeId == _initialPlaceId
            ? null
            : (_placeId == null ? const Patch.clear() : Patch.value(_placeId!)),
        startTime: _startTime == stop.time
            ? null
            : (_startTime == null
                ? const Patch.clear()
                : Patch.value(_startTime!)),
        category: _category == null || _category == stop.category
            ? null
            : Patch.value(_category!),
        costAmount: (cost ?? 0) == stop.cost ? null : (cost ?? 0),
        costCurrency: (cost ?? 0) == stop.cost ? null : _currency,
        notes: notes == oldNotes
            ? null
            : (notes.isEmpty ? const Patch.clear() : Patch.value(notes)),
        // The time can reorder nothing, but a renamed or re-placed stop can
        // move its legs — let the server re-measure on this one write.
      );

      // Moved to another day: it joins the end of that day. Done before the
      // photos because it is something the traveller asked for, not a
      // courtesy — a failure here is worth stopping on.
      if (_dayId != widget.initialDayId) {
        await api.itinerary.assignItem(stop.id, tripDayId: _dayId);
      }

      photoProblem = await _uploadPhotos(stop.id);

      if (!mounted) return;
      Navigator.of(context).pop(AddPlaceOutcome.updated);
      if (photoProblem != null) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(photoProblem)));
      }
      return;
    } on ApiException catch (failure) {
      _fail(failure.isUnauthorized
          ? 'เข้าสู่ระบบก่อนแก้ไขสถานที่'
          : 'บันทึกไม่สำเร็จ: ${failure.message}');
    } catch (error) {
      _fail('บันทึกไม่สำเร็จ: $error');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isEditing) ...[
                    _ExploreBanner(
                      onTap: () =>
                          Navigator.of(context).pop(AddPlaceOutcome.explore),
                    ),
                    const SizedBox(height: 18),
                  ],
                  _PhotoPicker(
                    photos: _photos,
                    onAdd: _addPhotos,
                    onReplace: _replacePhoto,
                  ),
                  const SizedBox(height: 18),
                  ..._fields(),
                ],
              ),
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isEditing ? 'แก้ไขสถานที่' : 'เพิ่มสถานที่',
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(AddPlaceOutcome.cancelled),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFF1EFEC),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.close, size: 19, color: Color(0xFF6C6862)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _fields() {
    return [
      const _FieldLabel('ชื่อกิจกรรม'),
      _FieldBox(
        child: Row(
          children: [
            const Icon(Icons.edit_note, size: 20, color: AppColors.muted),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'เช่น ทานอาหารเช้า, ชมพระอาทิตย์ตก',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _locationField(),
      const SizedBox(height: 14),
      // The design pairs these two, and the pair still fits a phone.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _dayField()),
          const SizedBox(width: 12),
          Expanded(child: _timeField()),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _categoryField()),
          const SizedBox(width: 12),
          Expanded(child: _costField()),
        ],
      ),
      const SizedBox(height: 14),
      const _FieldLabel('เพิ่มโน้ต'),
      Container(
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: TextField(
          controller: _notesController,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: 'เช่น ออกก่อนเวลา ~5 นาที',
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    ];
  }

  Widget _locationField() {
    final name = _placeName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('สถานที่ (ไม่บังคับ)'),
        GestureDetector(
          key: const ValueKey('stop-location-field'),
          onTap: _pickLocation,
          behavior: HitTestBehavior.opaque,
          child: _FieldBox(
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: name == null ? AppColors.muted : AppColors.brandOrange,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    name ?? 'เลือกสถานที่',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          name == null ? AppColors.muted : AppColors.foreground,
                    ),
                  ),
                ),
                if (name == null)
                  const Icon(Icons.chevron_right,
                      size: 20, color: AppColors.muted)
                else
                  Tooltip(
                    message: 'เอาสถานที่ออก',
                    child: GestureDetector(
                      onTap: _clearLocation,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child:
                            Icon(Icons.close, size: 18, color: AppColors.muted),
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

  Widget _dayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('วัน'),
        _FieldBox(
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dayId,
                    isExpanded: true,
                    isDense: true,
                    icon: const SizedBox.shrink(),
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    items: [
                      for (final day in widget.days)
                        DropdownMenuItem(
                          value: day.id,
                          child: Text(
                            day.menuLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    // Editing may move the stop too: that is a separate
                    // assign call after the PATCH, since a stop's day is not
                    // one of its fields.
                    onChanged: (value) {
                      if (value != null) setState(() => _dayId = value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeField() {
    final time = _startTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('เวลา'),
        GestureDetector(
          onTap: _pickTime,
          child: _FieldBox(
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    // The plan prints "08:30 AM"; TimeOfDay.format would
                    // follow the device's 24-hour setting instead.
                    time == null ? 'เวลา' : clockLabel(time),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          time == null ? AppColors.muted : AppColors.foreground,
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

  Widget _categoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('ประเภท'),
        _FieldBox(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ActivityCategory>(
              value: _category,
              isExpanded: true,
              isDense: true,
              hint: const Text(
                'ประเภทการเที่ยว',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              items: [
                for (final entry in categoryLabels.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _costField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('ค่าใช้จ่าย (ต่อคน)'),
        _FieldBox(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _costController,
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
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currency,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'THB', child: Text('THB')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'LAK', child: Text('LAK')),
                    DropdownMenuItem(value: 'VND', child: Text('VND')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _currency = value);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(AddPlaceOutcome.cancelled),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: AppColors.foreground,
                side: const BorderSide(color: AppColors.chipBorder, width: 1.5),
                shape: const StadiumBorder(),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: const Text('ยกเลิก'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: FilledButton(
              onPressed: _canAdd ? _submit : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.brandOrange,
                disabledBackgroundColor: const Color(0xFFE4E1DC),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF9E9A94),
                shape: const StadiumBorder(),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(_isEditing ? 'บันทึก' : 'เพิ่มสถานที่'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The nudge across the top of the sheet, matching the one on the plan.
class _ExploreBanner extends StatelessWidget {
  const _ExploreBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.brandOrange,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.explore_outlined,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'ยังไม่รู้จะไปไหน? สำรวจสถานที่แนะนำ',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: AppColors.brandOrange,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'สำรวจ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 17, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The cover image and its thumbnails. On a phone this sits above the fields
/// rather than beside them, which is the one place the layout departs from the
/// desktop frame.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photos,
    required this.onAdd,
    required this.onReplace,
  });

  final List<XFile> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onReplace;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return _empty();

    // Three tiles at most: the cover and two thumbnails, with the overflow
    // counted on the last one.
    final thumbs = photos.length > 3 ? photos.sublist(1, 3) : photos.skip(1);
    final hidden = photos.length > 3 ? photos.length - 3 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.18,
          child: _tile(photos.first, onTap: () => onReplace(0), radius: 16),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (index, photo) in thumbs.indexed) ...[
              SizedBox(
                width: 84,
                height: 84,
                child: _tile(
                  photo,
                  onTap: () => onReplace(index + 1),
                  radius: 12,
                  badge: hidden > 0 && index == thumbs.length - 1
                      ? '+$hidden'
                      : null,
                ),
              ),
              const SizedBox(width: 10),
            ],
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F2EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile(
    XFile photo, {
    required VoidCallback onTap,
    required double radius,
    String? badge,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(photo.path), fit: BoxFit.cover),
          if (badge != null)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onAdd,
          child: CustomPaint(
            painter: _DashedBox(),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 44, color: Color(0xFFD8B9A6)),
                  SizedBox(height: 10),
                  Text(
                    'เพิ่มรูป',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F2EF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.image_outlined, color: Color(0xFFCFCBC5)),
        ),
      ],
    );
  }
}

/// The design's dashed edge around the empty photo well.
class _DashedBox extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE6C9B4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(16),
      ));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + 6),
          paint,
        );
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  const _FieldBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
