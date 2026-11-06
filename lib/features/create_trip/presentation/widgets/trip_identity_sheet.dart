import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../trips/presentation/itinerary_display.dart';
import '../../domain/plan_labels.dart';
import '../create_trip_screen.dart';

/// The sheet's body, for tests to scope to.
const tripIdentitySheetKey = Key('trip-identity-sheet');
const tripIdentityTitleKey = Key('trip-identity-title');
const tripIdentityDestinationKey = Key('trip-identity-destination');
const tripIdentityDatesKey = Key('trip-identity-dates');
const tripIdentityGuestsKey = Key('trip-identity-guests');
const tripIdentitySaveKey = Key('trip-identity-save');
const tripIdentityStylesKey = Key('trip-identity-styles');
const tripIdentityPaceKey = Key('trip-identity-pace');
const tripIdentityConstraintsKey = Key('trip-identity-constraints');

/// "แก้ไขข้อมูลทริป": the trip's name, destination, dates and party — the
/// facts the create page asks for first, in the same panel and through the
/// same pickers — then its สไตล์การเที่ยว, ความเข้มข้น and เงื่อนไข /
/// ข้อจำกัด, as the create page's two steps draw them. Saves with one `PATCH /trips/:id` of only what changed, and
/// returns true once it has.
Future<bool?> showTripIdentitySheet(BuildContext context, ApiTrip trip) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => TripIdentitySheet(trip: trip),
  );
}

class TripIdentitySheet extends ConsumerStatefulWidget {
  const TripIdentitySheet({super.key, required this.trip});

  final ApiTrip trip;

  @override
  ConsumerState<TripIdentitySheet> createState() => _TripIdentitySheetState();
}

class _TripIdentitySheetState extends ConsumerState<TripIdentitySheet> {
  late final TextEditingController _title;
  late String _destination;

  /// Set only once the traveller picks a destination here; the trip's own
  /// place stands until then.
  DestinationPlace? _place;
  DateTime? _start;
  DateTime? _end;
  late int _nights;
  late int _adults;

  /// The API keeps one head count, so a trip reopens with everyone counted
  /// as an adult.
  int _children = 0;

  /// The style chips on, as labels: the enum ones by their Thai name, then
  /// any typed-in ones, which have no enum and go up as `customStyles`.
  late final List<String> _styles;

  /// Typed-in styles the trip came with, kept as chips so they can be
  /// switched off like the rest.
  late final List<String> _customStyles;

  /// เงื่อนไข / ข้อจำกัด on, as labels — the same split as the styles: enum
  /// ones by name, the rest go up as `customConstraints`.
  late final List<String> _constraints;

  /// Constraint chips beyond the design's six, typed in elsewhere.
  late final List<String> _extraConstraints;
  bool _constraintsChanged = false;

  /// `TripIntensity` wire value, or '' for none.
  late String _pace;
  bool _stylesChanged = false;
  bool _datesChanged = false;
  bool _guestsChanged = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    _title = TextEditingController(text: trip.title)
      ..addListener(() => setState(() {}));
    _destination = trip.destination;
    _start = trip.schedule.startDate;
    _end = trip.schedule.endDate;
    _nights = _start == null ? (trip.schedule.durationNights ?? 0) : 0;
    _adults = (trip.guestCount ?? 1).clamp(1, 99);
    final brief = trip.brief;
    _customStyles = List.of(brief?.customStyles ?? const <String>[]);
    _styles = [
      ...?brief?.styles.map(styleLabel).whereType<String>(),
      ..._customStyles,
    ];
    _pace = brief?.intensity?.wire ?? '';
    final customConstraints = brief?.customConstraints ?? const <String>[];
    _extraConstraints = customConstraints
        .where((label) => !tripConstraintChips.contains(label))
        .toList();
    _constraints = [
      ...?brief?.constraints.map(constraintLabel).whereType<String>(),
      ...customConstraints,
    ];
  }

  void _toggleConstraint(String label) => setState(() {
        _constraints.contains(label)
            ? _constraints.remove(label)
            : _constraints.add(label);
        _constraintsChanged = true;
      });

  void _toggleStyle(String label) => setState(() {
        _styles.contains(label) ? _styles.remove(label) : _styles.add(label);
        _stylesChanged = true;
      });

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving &&
      _title.text.trim().isNotEmpty &&
      _destination.trim().isNotEmpty;

  String get _datesLabel {
    final start = _start;
    final end = _end;
    if (start != null && end != null) {
      return '${slashDate(start)} - ${slashDate(end)}';
    }
    return _nights > 0 ? '$_nights คืน' : 'ยังไม่ระบุวันที่';
  }

  String get _guestsLabel => _children == 0
      ? 'ผู้ใหญ่, $_adults คน'
      : 'ผู้ใหญ่ $_adults, เด็ก $_children คน';

  Future<void> _pickDestination() async {
    final picked = await pickTripDestination(context);
    if (picked == null || !mounted) return;
    setState(() {
      _destination = picked.value;
      _place = picked.place;
    });
  }

  Future<void> _pickDates() async {
    final picked =
        await pickTripDates(context, start: _start, end: _end, nights: _nights);
    if (picked == null || !mounted) return;
    setState(() {
      _start = picked.start;
      _end = picked.end;
      _nights = picked.nights;
      _datesChanged = true;
    });
  }

  Future<void> _pickGuests() async {
    final picked =
        await pickTripGuests(context, adults: _adults, children: _children);
    if (picked == null || !mounted) return;
    setState(() {
      _adults = picked.$1;
      _children = picked.$2;
      _guestsChanged = true;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final trip = widget.trip;
    final title = _title.text.trim();
    final destinationChanged = _destination != trip.destination;
    final start = _start;
    final end = _end;
    // A length with no dates goes up as durations, which the server only
    // reads on a trip without dates.
    final byLength = _datesChanged && start == null && _nights > 0;
    final pace = TripIntensity.from(_pace);
    final paceChanged = pace != trip.brief?.intensity;

    setState(() => _saving = true);
    try {
      final api = await ref.read(plunoApiProvider.future);
      await api.trips.update(
        trip.id,
        title: title == trip.title ? null : title,
        destination: destinationChanged ? _destination : null,
        destinationPlace: destinationChanged ? _place : null,
        startDate: _datesChanged ? start : null,
        // A single day picked is a range of one.
        endDate: _datesChanged && start != null ? (end ?? start) : null,
        durationDays: byLength ? _nights + 1 : null,
        durationNights: byLength ? _nights : null,
        guestCount: _guestsChanged ? _adults + _children : null,
        // The brief merges per key, and each list replaces its own whole —
        // so both go up together, [] clearing one the traveller emptied.
        travelStyles: _stylesChanged
            ? _styles
                .map((label) => styleByLabel[label])
                .whereType<TravelStyle>()
                .toList()
            : null,
        customStyles: _stylesChanged
            ? _styles
                .where((label) => !styleByLabel.containsKey(label))
                .toList()
            : null,
        pace: paceChanged ? pace : null,
        constraints: _constraintsChanged
            ? _constraints
                .map((label) => constraintByLabel[label])
                .whereType<TripConstraint>()
                .toList()
            : null,
        customConstraints: _constraintsChanged
            ? _constraints
                .where((label) => !constraintByLabel.containsKey(label))
                .toList()
            : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiException
              ? 'บันทึกไม่สำเร็จ: ${error.message}'
              : 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keeps the save button above the keyboard while the name is typed.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        key: tripIdentitySheetKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'แก้ไขข้อมูลทริป',
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'ปิด',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The create page's header: its photo, its green panel, its rows.
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      image: const DecorationImage(
                        image: AssetImage('assets/images/home_hero.jpg'),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF668078).withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        children: [
                          TripHeaderInput(
                            key: tripIdentityTitleKey,
                            iconData: Icons.edit_outlined,
                            child: TextField(
                              controller: _title,
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'ชื่อทริป',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TripHeaderInput(
                            key: tripIdentityDestinationKey,
                            icon: 'assets/icons/field_location.svg',
                            label: _destination.isEmpty
                                ? 'Destination'
                                : _destination,
                            filled: _destination.isNotEmpty,
                            onTap: _pickDestination,
                          ),
                          const SizedBox(height: 10),
                          TripHeaderInput(
                            key: tripIdentityDatesKey,
                            icon: 'assets/icons/field_calendar.svg',
                            label: _datesLabel,
                            filled: _start != null || _nights > 0,
                            onTap: _pickDates,
                          ),
                          const SizedBox(height: 10),
                          TripHeaderInput(
                            key: tripIdentityGuestsKey,
                            icon: 'assets/icons/field_guests.svg',
                            label: _guestsLabel,
                            filled: true,
                            onTap: _pickGuests,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Step one of the create page, the two parts PATCH can write. Its
                  // การเดินทาง chips are not here: the API takes no transport on an
                  // edit.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TripSectionTitle(title: 'สไตล์การเที่ยว'),
                        TripChoiceWrap(
                          key: tripIdentityStylesKey,
                          items: [
                            for (final entry in styleByLabel.entries)
                              [entry.key, styleIcon(entry.value)],
                            for (final custom in _customStyles) [custom],
                          ],
                          selected: _styles,
                          onTap: _toggleStyle,
                        ),
                        const SizedBox(height: 22),
                        const TripSectionTitle(
                          title: 'ความเข้มข้นของทริป',
                          subtitle: '*จำนวนจุดท่องเที่ยว / วัน',
                        ),
                        TripTierGrid(
                          key: tripIdentityPaceKey,
                          items: tripPaceTiers,
                          selected: _pace,
                          onTap: (wire) => setState(() => _pace = wire),
                        ),
                        const SizedBox(height: 22),
                        const TripSectionTitle(title: 'เงื่อนไข / ข้อจำกัด'),
                        TripChoiceWrap(
                          key: tripIdentityConstraintsKey,
                          items: [
                            for (final label in tripConstraintChips) [label],
                            for (final label in _extraConstraints) [label],
                          ],
                          selected: _constraints,
                          onTap: _toggleConstraint,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: FilledButton(
              key: tripIdentitySaveKey,
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandOrange,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'บันทึก',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
