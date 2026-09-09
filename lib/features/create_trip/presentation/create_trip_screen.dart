import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../trips/domain/models/trip.dart';
import 'providers/destination_search_providers.dart';
import '../../trips/presentation/providers/trip_providers.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key, this.trip});

  final Trip? trip;

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _destinationController;
  late final TextEditingController _budgetController;
  late final TextEditingController _durationController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _coverImageController;

  DateTime? _startDate;
  DateTime? _endDate;
  String _transport = 'flight';

  /// Step one: how many stops a day the traveller wants.
  String _paceTier = '';

  /// Step two.
  String _budgetTier = '';
  String _lodging = '';
  final List<String> _constraints = <String>[];

  /// 0 until the traveller picks something. Kept beside the dates because
  /// "จำนวนคืน" sets a length with no dates attached.
  int _nights = 0;

  int _travelers = 1;
  int _children = 0;
  bool _aiShown = false;
  bool _isSaving = false;

  /// 0 = preferences, 1 = budget and constraints. The header and the mode
  /// switch stay put; only the body and the action bar change.
  int _step = 0;

  final List<String> _selectedVibes = <String>[];
  final _scrollController = ScrollController();

  bool get _isEditing => widget.trip != null;
  bool get _canCreate => _destinationController.text.trim().isNotEmpty;

  /// The midpoint of each bracket, in THB per person per day.
  static const _budgetTierAmounts = <String, double>{
    'economy': 800,
    'comfort': 3000,
    'premium': 7500,
    'luxury': 12000,
  };

  /// What "ระบุเอง" holds wins over the bracket, so a traveller can pick a
  /// tier for the feel of it and then be exact.
  double get _perPersonPerDay {
    final typed =
        double.tryParse(_budgetController.text.trim().replaceAll(',', ''));
    if (typed != null && typed > 0) return typed;
    return _budgetTierAmounts[_budgetTier] ?? 0;
  }

  int get _days {
    final parsed = int.tryParse(_durationController.text.trim()) ?? 0;
    return parsed > 0 ? parsed : 1;
  }

  /// The trip total the API stores. The section is headed "งบต่อคน / วัน", so
  /// the figure on screen has to be multiplied back up by heads and days.
  double get _displayBudget =>
      _perPersonPerDay * (_travelers + _children) * _days;

  /// Leaving step two untouched must not wipe the budget off a trip being
  /// edited, so the stored total stands until something is actually chosen.
  double get _budgetToSave {
    final computed = _displayBudget;
    return computed > 0 ? computed : (widget.trip?.budget ?? 0);
  }

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    _titleController = TextEditingController(text: trip?.title ?? '');
    _destinationController =
        TextEditingController(text: trip?.destination ?? '');
    // Empty, not '0': this is the "ระบุเอง" box, and a seeded zero hid its ฿
    // hint. An existing trip's stored total is a whole-trip figure, which does
    // not belong in a per-person-per-day field either.
    _budgetController = TextEditingController();
    _durationController = TextEditingController(
      text: trip == null ? '7' : trip.duration.toString(),
    );
    _descriptionController =
        TextEditingController(text: trip?.description ?? '');
    _coverImageController = TextEditingController(
      text: trip?.coverImage ?? AppConstants.defaultCoverImage,
    );
    _destinationController.addListener(_syncGeneratedFields);
    _budgetController.addListener(_refresh);
  }

  @override
  void dispose() {
    _destinationController.removeListener(_syncGeneratedFields);
    _budgetController.removeListener(_refresh);
    _scrollController.dispose();
    _titleController.dispose();
    _destinationController.dispose();
    _budgetController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    _coverImageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF9),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final framed = constraints.maxWidth > 430;
            return Container(
              width: constraints.maxWidth < 430 ? constraints.maxWidth : 430,
              height: framed && constraints.maxHeight > 900
                  ? 900
                  : constraints.maxHeight,
              color: const Color(0xFFFDFCF9),
              child: Form(
                key: _formKey,
                child: Stack(
                  children: [
                    ListView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      // Clears the pinned action bar, which is now taller by
                      // the home-indicator inset it absorbs.
                      padding: EdgeInsets.only(
                        bottom: 92 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        _CreateTripHeader(
                          destinationController: _destinationController,
                          startDate: _startDate,
                          endDate: _endDate,
                          nights: _nights,
                          travelers: _travelers,
                          children: _children,
                          onBack: _close,
                          onDestinationTap: _showDestinationSearch,
                          onPickDate: _showDatesDialog,
                          onGuestTap: _showGuestSheet,
                        ),
                        _CreateModeSwitch(
                          aiSelected: _aiShown,
                          onChanged: (value) =>
                              setState(() => _aiShown = value),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...(_step == 0
                                  ? _preferenceStep()
                                  : _budgetStep()),
                              const SizedBox(height: 24),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _PageIndicator(step: _step),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      // No SafeArea here — the bar takes the inset into its own
                      // padding, so its background reaches the screen edge
                      // instead of floating above a strip of scrolled content.
                      child: Builder(
                        builder: (context) => _step == 0
                            ? _BottomActionBar(
                                enabled: _canCreate && !_isSaving,
                                saving: false,
                                secondaryLabel: 'ข้ามไปก่อน',
                                primaryLabel: 'ถัดไป',
                                onSecondary: _close,
                                onTap: () => _goToStep(1),
                              )
                            : _BottomActionBar(
                                enabled: _canCreate && !_isSaving,
                                saving: _isSaving,
                                secondaryLabel: 'ย้อนกลับ',
                                primaryLabel:
                                    _isEditing ? 'บันทึก' : 'สร้างแผน',
                                showArrow: true,
                                onSecondary: () => _goToStep(0),
                                onTap: _submit,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Step one: how the traveller likes to travel.
  List<Widget> _preferenceStep() {
    return [
      const _ThaiSectionTitle(title: 'สไตล์การเที่ยว'),
      _ChoiceWrap(
        items: const [
          ['ทะเล', Icons.beach_access_outlined],
          ['ภูเขา', Icons.terrain_outlined],
          ['ธรรมชาติ', Icons.eco_outlined],
          ['คาเฟ่', Icons.coffee_outlined],
          ['เข้าถึงท้องถิ่น', Icons.storefront_outlined],
          ['วัฒนธรรม', Icons.museum_outlined],
          ['อาหาร', Icons.restaurant_outlined],
          ['ไนท์ไลฟ์', Icons.local_bar_outlined],
          ['ช้อปปิ้ง', Icons.shopping_bag_outlined],
          ['ผจญภัย', Icons.hiking_outlined],
        ],
        selected: _selectedVibes,
        onTap: _toggleVibe,
        showMore: true,
      ),
      const SizedBox(height: 22),
      const _ThaiSectionTitle(
        title: 'ความเข้มข้นของทริป',
        subtitle: '*จำนวนจุดท่องเที่ยว / วัน',
      ),
      _TierGrid(
        items: const [
          ['4', 'Slow Life', '3 - 4 สถานที่/วัน'],
          ['6', 'Chill', '5 - 6 สถานที่/วัน'],
          ['8', 'Balance', '8 สถานที่/วัน'],
          ['10', 'Active', '9 - 11 สถานที่/วัน'],
          ['12', 'Hardcore', '12+ สถานที่/วัน'],
        ],
        selected: _paceTier,
        onTap: _setPace,
      ),
      const SizedBox(height: 22),
      const _ThaiSectionTitle(title: 'การเดินทาง'),
      _ChoiceWrap(
        items: const [
          ['เครื่องบิน', Icons.flight_outlined],
          ['รถส่วนตัว', Icons.directions_car_outlined],
          ['เช่ารถขับ', Icons.car_rental_outlined],
          ['มอเตอร์ไซค์', Icons.two_wheeler_outlined],
          ['รถสาธารณะท้องถิ่น', Icons.directions_bus_outlined],
          ['แบบประหยัด', Icons.directions_walk_outlined],
        ],
        selected: [_transport],
        onTap: (value) => setState(() => _transport = value),
        showMore: true,
      ),
    ];
  }

  /// Step two: what it may cost, where they are sleeping, and what the plan
  /// has to work around.
  List<Widget> _budgetStep() {
    return [
      const _ThaiSectionTitle(
        title: 'งบต่อคน / วัน',
        subtitle: '* ยังไม่รวมค่าที่พัก',
      ),
      _TierGrid(
        items: const [
          ['economy', 'Economy', '<1,000฿'],
          ['comfort', 'Comfort', '฿1,000 - ฿5,000'],
          ['premium', 'Premium', '฿5,000 - ฿10,000'],
          ['luxury', 'Luxury', '฿10,000+'],
        ],
        selected: _budgetTier,
        onTap: _setBudgetTier,
      ),
      const SizedBox(height: 10),
      _CustomBudgetCard(controller: _budgetController),
      const SizedBox(height: 22),
      const _ThaiSectionTitle(title: 'ที่พัก / โรงแรม'),
      _LodgingChoice(selected: _lodging, onTap: _setLodging),
      const SizedBox(height: 22),
      const _ThaiSectionTitle(title: 'เงื่อนไข / ข้อจำกัด'),
      _ChoiceWrap(
        items: const [
          ['มีผู้สูงอายุ'],
          ['ผู้ใช้รถเข็น'],
          ['อิสลาม'],
          ['มังสวิรัติ'],
          ['เดินเยอะไม่ได้'],
          ['มีเด็กเล็ก'],
        ],
        selected: _constraints,
        onTap: _toggleConstraint,
        showMore: true,
        moreLabel: '+ เพิ่มเติม',
      ),
    ];
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _syncGeneratedFields() {
    final destination = _destinationController.text.trim();
    if (!_isEditing) {
      _titleController.text = destination.isEmpty ? '' : '$destination Trip';
      _descriptionController.text = destination.isEmpty
          ? ''
          : 'A personalized Pluno plan for $destination with saved places, budget notes, and flexible daily ideas.';
    }
    setState(() {});
  }

  void _toggleVibe(String vibe) {
    setState(() {
      if (_selectedVibes.contains(vibe)) {
        _selectedVibes.remove(vibe);
      } else {
        _selectedVibes.add(vibe);
      }
    });
  }

  void _setPace(String tier) => setState(() => _paceTier = tier);

  /// Picking a bracket clears anything typed under "ระบุเอง", otherwise the
  /// old figure would silently keep overriding the tier just chosen.
  void _setBudgetTier(String tier) {
    setState(() {
      _budgetTier = tier;
      _budgetController.clear();
    });
  }

  void _setLodging(String value) => setState(() => _lodging = value);

  void _toggleConstraint(String label) {
    setState(() {
      if (!_constraints.remove(label)) _constraints.add(label);
    });
  }

  /// No destination guard here: `_canCreate` already disables the button that
  /// calls this, the same way it gates submitting.
  void _goToStep(int step) {
    setState(() => _step = step);
    // The two steps are one scroll view, so without this the traveller lands
    // partway down the next step.
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _showDatesDialog() async {
    final picked = await showModalBottomSheet<_TripDates>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _TripDatesSheet(
        start: _startDate,
        end: _endDate,
        nights: _nights,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
      _nights = picked.nights;
      // A single day is zero nights but still one day of budget.
      _durationController.text = picked.nights.toString();
    });
  }

  Future<void> _showDestinationSearch() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _DestinationSearchPage()),
    );
    if (selected != null && mounted) {
      _destinationController.text = selected;
    }
  }

  Future<void> _showGuestSheet() async {
    final result = await showModalBottomSheet<(int, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) => _GuestPickerSheet(
        initialAdults: _travelers,
        initialChildren: _children,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _travelers = result.$1;
        _children = result.$2;
      });
    }
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    context.goNamed(AppRoute.home.name);
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_canCreate) {
      _showError('Please add a destination before creating your trip.');
      _formKey.currentState?.validate();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showError('Please check the trip details and try again.');
      return;
    }

    setState(() => _isSaving = true);
    final actions = ref.read(tripActionsProvider);
    final existing = widget.trip;
    final now = DateTime.now();
    final destination = _destinationController.text.trim();
    final title = _titleController.text.trim().isEmpty
        ? '$destination Trip'
        : _titleController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? 'A personalized Pluno plan for $destination with saved places, budget notes, and flexible daily ideas.'
        : _descriptionController.text.trim();

    Trip trip;
    try {
      trip = existing == null
          ? await actions.createTrip(
              title: title,
              destination: destination,
              coverImage: _coverImageController.text.trim(),
              budget: _budgetToSave,
              duration: int.parse(_durationController.text.trim()),
              description: description,
            )
          : existing.copyWith(
              title: title,
              destination: destination,
              coverImage: _coverImageController.text.trim(),
              budget: _budgetToSave,
              duration: int.parse(_durationController.text.trim()),
              description: description,
              updatedAt: now,
              isSaved: true,
            );

      if (existing != null) {
        await actions.saveTrip(trip);
      }
    } catch (error, stackTrace) {
      debugPrint('Trip submit failed while saving: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showError('Could not create trip: $error');
      return;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (!mounted) return;

    try {
      context.goNamed(AppRoute.home.name);
    } catch (error, stackTrace) {
      debugPrint('Trip submit failed while navigating: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showError('Trip was saved, but could not open home: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _GuestPickerSheet extends StatefulWidget {
  const _GuestPickerSheet({
    required this.initialAdults,
    required this.initialChildren,
  });

  final int initialAdults;
  final int initialChildren;

  @override
  State<_GuestPickerSheet> createState() => _GuestPickerSheetState();
}

class _GuestPickerSheetState extends State<_GuestPickerSheet> {
  late int _adults;
  late int _children;

  @override
  void initState() {
    super.initState();
    _adults = widget.initialAdults;
    _children = widget.initialChildren;
  }

  @override
  Widget build(BuildContext context) {
    // The inset lives in the padding, not in a SafeArea around the sheet:
    // wrapping the outside lifts the white panel clear of the bottom edge and
    // leaves a strip of the dimmed page showing beneath it.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(28, 24, 28, 26 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFD),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GuestCountRow(
            title: 'ผู้ใหญ่',
            subtitle: 'อายุ 18 ปีขึ้นไป',
            value: _adults,
            canDecrease: _adults > 1,
            onDecrease: () => setState(() => _adults--),
            onIncrease: () => setState(() => _adults++),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: Color(0xFFE8D8B6)),
          ),
          _GuestCountRow(
            title: 'เด็ก',
            subtitle: 'อายุ 0-17 ปี',
            value: _children,
            canDecrease: _children > 0,
            onDecrease: () => setState(() => _children--),
            onIncrease: () => setState(() => _children++),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    foregroundColor: const Color(0xFF202020),
                    side: const BorderSide(
                      color: Color(0xFFE5D2A5),
                      width: 1.5,
                    ),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop((_adults, _children)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    backgroundColor: const Color(0xFFFF765E),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('ยืนยัน'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuestCountRow extends StatelessWidget {
  const _GuestCountRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.canDecrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String title;
  final String subtitle;
  final int value;
  final bool canDecrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF191919),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF89918D),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        _GuestStepperButton(
          icon: Icons.remove,
          enabled: canDecrease,
          onTap: onDecrease,
        ),
        SizedBox(
          width: 54,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1E1E1E),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _GuestStepperButton(
          icon: Icons.add,
          enabled: true,
          onTap: onIncrease,
        ),
      ],
    );
  }
}

class _GuestStepperButton extends StatelessWidget {
  const _GuestStepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: CircleBorder(
        side: BorderSide(
          color: enabled ? const Color(0xFFE5D2A5) : const Color(0xFFEAE6DC),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            size: 24,
            color: enabled ? const Color(0xFF202020) : const Color(0xFFBEBEB8),
          ),
        ),
      ),
    );
  }
}

/// What the date dialog hands back: either an exact range, or a night count
/// with no dates attached.
class _TripDates {
  const _TripDates({this.start, this.end, required this.nights});

  final DateTime? start;
  final DateTime? end;
  final int nights;
}

const _thaiMonths = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

/// Sunday first, matching the grid.
const _thaiWeekdays = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

const _pickerPrimary = Color(0xFFFF765E);

/// The primary at rest behind a disabled confirm, matching the action bar.
const _pickerPrimaryMuted = Color(0xFFFFC9BD);

/// The band drawn under the days between the two endpoints.
const _pickerRangeBand = Color(0xFFFFEDE8);
const _pickerOutline = Color(0xFFE5D2A5);

/// "ระบุวันที่ / จำนวนคืน" — pick the exact days, or just say how many
/// nights. Shown as a bottom sheet, like the guest picker.
class _TripDatesSheet extends StatefulWidget {
  const _TripDatesSheet({this.start, this.end, this.nights = 0});

  final DateTime? start;
  final DateTime? end;
  final int nights;

  @override
  State<_TripDatesSheet> createState() => _TripDatesSheetState();
}

class _TripDatesSheetState extends State<_TripDatesSheet> {
  late bool _byDate;
  late DateTime _month;
  late DateTime? _start;
  late DateTime? _end;
  late int _nights;

  /// Midnight today: everything before it is unpickable.
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _start = widget.start;
    _end = widget.end;
    _nights = widget.nights > 0 ? widget.nights : 1;
    // Reopening on a chosen range should show it, not this month.
    _byDate = widget.start != null || widget.nights == 0;
    _month = DateTime(
      (_start ?? _today).year,
      (_start ?? _today).month,
    );
  }

  bool get _canConfirm => _byDate ? _start != null : _nights > 0;

  void _shiftMonth(int by) {
    final next = DateTime(_month.year, _month.month + by);
    // Nothing to pick in a month that has already gone.
    if (next.isBefore(DateTime(_today.year, _today.month))) return;
    setState(() => _month = next);
  }

  void _pick(DateTime day) {
    setState(() {
      // A third tap starts a new range rather than extending the old one.
      if (_start == null || _end != null || day.isBefore(_start!)) {
        _start = day;
        _end = null;
      } else {
        _end = day;
      }
    });
  }

  void _confirm() {
    if (!_canConfirm) return;
    if (_byDate) {
      final start = _start!;
      final end = _end ?? start;
      Navigator.of(context).pop(
        _TripDates(
          start: start,
          end: end,
          nights: end.difference(start).inDays,
        ),
      );
      return;
    }
    // Nights only: the traveller has not committed to dates yet.
    Navigator.of(context).pop(_TripDates(nights: _nights));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Never taller than the screen: a long month plus a large text scale
      // would otherwise push the buttons off the bottom.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      // The inset goes in the padding, not a SafeArea around the sheet.
      padding: EdgeInsets.fromLTRB(
        16,
        18,
        16,
        18 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeToggle(
            byDate: _byDate,
            onChanged: (value) => setState(() => _byDate = value),
          ),
          const SizedBox(height: 18),
          Flexible(
            child: SingleChildScrollView(
              child: _byDate ? _calendar() : _nightsPicker(),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: const Color(0xFF202020),
                    side: const BorderSide(color: _pickerOutline, width: 1.5),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton(
                  onPressed: _canConfirm ? _confirm : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: _pickerPrimary,
                    disabledBackgroundColor: _pickerPrimaryMuted,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('ยืนยัน'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendar() {
    final firstOfMonth = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // DateTime.sunday is 7; the grid starts on Sunday.
    final leading = firstOfMonth.weekday % 7;
    final atFirstMonth =
        _month.year == _today.year && _month.month == _today.month;

    return Column(
      children: [
        Row(
          children: [
            _MonthArrow(
              icon: Icons.chevron_left,
              enabled: !atFirstMonth,
              onTap: () => _shiftMonth(-1),
            ),
            Expanded(
              child: Text(
                // Thai dates are written in the Buddhist era.
                '${_thaiMonths[_month.month - 1]} ${_month.year + 543}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1B1B),
                ),
              ),
            ),
            _MonthArrow(
              icon: Icons.chevron_right,
              enabled: true,
              onTap: () => _shiftMonth(1),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final label in _thaiWeekdays)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E8B84),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.05,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              _DayCell(
                date: DateTime(_month.year, _month.month, day),
                start: _start,
                end: _end,
                today: _today,
                onTap: _pick,
              ),
          ],
        ),
      ],
    );
  }

  Widget _nightsPicker() {
    return Column(
      children: [
        const SizedBox(height: 14),
        const Text(
          'เลือกจำนวนคืนที่ต้องการพัก',
          style: TextStyle(fontSize: 15, color: Color(0xFF9C988F)),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GuestStepperButton(
              icon: Icons.remove,
              enabled: _nights > 1,
              onTap: () => setState(() => _nights--),
            ),
            SizedBox(
              width: 130,
              child: Text(
                '$_nights คืน',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _pickerPrimary,
                ),
              ),
            ),
            _GuestStepperButton(
              icon: Icons.add,
              enabled: true,
              onTap: () => setState(() => _nights++),
            ),
          ],
        ),
        const SizedBox(height: 26),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.byDate, required this.onChanged});

  final bool byDate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _pickerOutline, width: 1.5),
      ),
      child: Row(
        children: [
          _ModeToggleHalf(
            label: 'ระบุวันที่',
            active: byDate,
            onTap: () => onChanged(true),
          ),
          _ModeToggleHalf(
            label: 'จำนวนคืน',
            active: !byDate,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ModeToggleHalf extends StatelessWidget {
  const _ModeToggleHalf({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _pickerPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : const Color(0xFF1F1F1F),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      iconSize: 26,
      color: const Color(0xFF1B1B1B),
      disabledColor: const Color(0xFFD3D0C9),
      splashRadius: 22,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.start,
    required this.end,
    required this.today,
    required this.onTap,
  });

  final DateTime date;
  final DateTime? start;
  final DateTime? end;
  final DateTime today;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final past = date.isBefore(today);
    final isStart = start != null && _sameDay(date, start!);
    final isEnd = end != null && _sameDay(date, end!);
    final inRange = start != null &&
        end != null &&
        date.isAfter(start!) &&
        date.isBefore(end!);

    return Stack(
      children: [
        // The connecting band sits behind the endpoints so a range reads as one
        // run rather than two circles.
        if (inRange || (isStart && end != null) || isEnd)
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                height: 38,
                margin: EdgeInsets.only(
                  left: isStart && end != null ? 14 : 0,
                  right: isEnd ? 14 : 0,
                ),
                color: _pickerRangeBand,
              ),
            ),
          ),
        Positioned.fill(
          child: Center(
            child: GestureDetector(
              onTap: past ? null : () => onTap(date),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isStart || isEnd ? _pickerPrimary : Colors.transparent,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 17,
                    color: isStart || isEnd
                        ? Colors.white
                        : past
                            ? const Color(0xFFC7C4BD)
                            : const Color(0xFF1B1B1B),
                    fontWeight:
                        isStart || isEnd ? FontWeight.w800 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DestinationSearchPage extends ConsumerStatefulWidget {
  const _DestinationSearchPage();

  @override
  ConsumerState<_DestinationSearchPage> createState() =>
      _DestinationSearchPageState();
}

class _DestinationSearchPageState
    extends ConsumerState<_DestinationSearchPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Hands [value] back to the create-plan form, remembering it on the way.
  void _select(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    ref.read(recentDestinationsProvider.notifier).record(trimmed);
    // The autocomplete session ends with the picker: popping drops the last
    // listener on `placesSessionProvider`, which auto-disposes.
    Navigator.of(context).pop(trimmed);
  }

  /// Enter accepts what was typed even when the type-ahead found nothing —
  /// the API knows cities, and a traveller may be heading somewhere vaguer.
  void _submitTyped() {
    final typed = _searchController.text.trim();
    if (typed.isNotEmpty) _select(typed);
  }

  @override
  Widget build(BuildContext context) {
    // Watched, not read: `placesSessionProvider` auto-disposes, so without a
    // listener holding it open every lookup would mint a fresh token — which
    // is the per-keystroke billing the session exists to avoid.
    ref.watch(placesSessionProvider);

    final query = ref.watch(destinationQueryProvider).trim();
    final searching = query.length >= minDestinationQueryLength;
    final suggestions = ref.watch(destinationSuggestionsProvider);
    final recents = ref.watch(recentDestinationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _SearchHeader(
              controller: _searchController,
              loading: searching && suggestions.isLoading,
              onChanged: (value) =>
                  ref.read(destinationQueryProvider.notifier).state = value,
              onSubmit: _submitTyped,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                children: [
                  if (recents.isNotEmpty) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'ค้นล่าสุด',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => ref
                              .read(recentDestinationsProvider.notifier)
                              .clear(),
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Text(
                              'ล้าง',
                              style: TextStyle(
                                color: Color(0xFFA5A5A1),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: recents.map((label) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              onPressed: () => _select(label),
                              avatar: const Icon(Icons.history,
                                  size: 14, color: Color(0xFF8C928E)),
                              label: Text(label),
                              labelStyle: const TextStyle(
                                color: Color(0xFF4F5652),
                                fontSize: 11,
                              ),
                              side: const BorderSide(color: Color(0xFFE0E0DB)),
                              backgroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(color: Color(0xFFE5DCC8)),
                    ),
                  ],
                  Text(
                    searching ? 'ผลการค้นหา' : 'Search Trend มาแรง',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (searching) ..._results(suggestions) else ..._trending(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _results(AsyncValue<List<DestinationOption>> suggestions) {
    // Checked before the value: an `AsyncError` carries the last good results
    // along with it, and rows answering an older query would be worse than
    // saying the lookup failed.
    if (suggestions.hasError) {
      return [
        _PickerNotice(
          icon: Icons.cloud_off_outlined,
          message: 'ค้นหาจุดหมายไม่สำเร็จ',
          actionLabel: 'ลองอีกครั้ง',
          onAction: () => ref.invalidate(destinationSuggestionsProvider),
        ),
      ];
    }

    // A rebuild carries the last results into the new `AsyncLoading`, so the
    // list keeps what it had rather than blinking between keystrokes. Only the
    // first search of a session has nothing to show.
    final options = suggestions.valueOrNull;
    if (options == null || (options.isEmpty && suggestions.isLoading)) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      ];
    }

    if (options.isEmpty) {
      return [
        // Not a dead end: what was typed is still usable as a destination.
        _PickerNotice(
          icon: Icons.travel_explore_outlined,
          message: 'ไม่พบจุดหมายที่ค้นหา',
          actionLabel: 'ใช้ "${_searchController.text.trim()}"',
          onAction: _submitTyped,
        ),
      ];
    }

    return options
        .map((option) => _DestinationResultTile(
              primary: option.label,
              secondary: option.sublabel,
              onTap: () => _select(option.value),
            ))
        .toList();
  }

  List<Widget> _trending() {
    final trending = ref.watch(trendingDestinationsProvider);
    if (trending.isEmpty) {
      return const [
        _PickerNotice(
          icon: Icons.explore_outlined,
          message: 'พิมพ์ชื่อเมืองหรือประเทศเพื่อค้นหา',
        ),
      ];
    }

    return trending
        .map((option) => _DestinationResultTile(
              primary: option.label,
              secondary: option.sublabel,
              onTap: () => _select(option.value),
            ))
        .toList();
  }
}

/// The picker's hero bar: back, then the search pill.
class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.loading,
    required this.onChanged,
    required this.onSubmit,
    required this.onBack,
  });

  final TextEditingController controller;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // The hero runs behind the status bar, so its height has to include that
    // inset as well: at a fixed 118 the padding below the notch exceeded the
    // box and collapsed the search pill to nothing on any device with one.
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      height: topInset + 118,
      padding: EdgeInsets.fromLTRB(20, topInset + 42, 20, 22),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        image: DecorationImage(
          image: AssetImage('assets/images/home_hero.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Row(
        children: [
          _RoundSearchButton(
            icon: Icons.chevron_left,
            backgroundColor: Colors.white,
            iconColor: const Color(0xFF2E7055),
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 52,
              padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0xFFE4D2A8), width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: Color(0xFFFF765E)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.search,
                      onChanged: onChanged,
                      onSubmitted: (_) => onSubmit(),
                      decoration: const InputDecoration(
                        hintText: 'ค้นหาชื่อที่ ย่าน หรือประเทศ',
                        hintStyle: TextStyle(
                          color: Color(0xFF908F8A),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  // Same footprint as the button it replaces, so the pill does
                  // not resize on every keystroke.
                  if (loading)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFFFF765E),
                          ),
                        ),
                      ),
                    )
                  else
                    _RoundSearchButton(
                      icon: Icons.chevron_right,
                      backgroundColor: const Color(0xFF090909),
                      iconColor: Colors.white,
                      onTap: onSubmit,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An empty, offline or hint state for the picker list.
class _PickerNotice extends StatelessWidget {
  const _PickerNotice({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          // An icon rather than an emoji: this build ships no emoji font, so a
          // glyph here would render as a tofu box.
          Icon(icon, size: 34, color: const Color(0xFFB9BDB8)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8D928F)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  color: Color(0xFFFF765E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundSearchButton extends StatelessWidget {
  const _RoundSearchButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: iconColor, size: 27),
        ),
      ),
    );
  }
}

class _DestinationResultTile extends StatelessWidget {
  const _DestinationResultTile({
    required this.primary,
    required this.secondary,
    required this.onTap,
  });

  final String primary;
  final String secondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.location_on,
                color: Color(0xFF2D7757),
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    primary,
                    style: const TextStyle(
                      color: Color(0xFF181818),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (secondary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondary,
                      style: const TextStyle(
                        color: Color(0xFF8E8E8A),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTripHeader extends StatelessWidget {
  const _CreateTripHeader({
    required this.destinationController,
    required this.startDate,
    required this.endDate,
    required this.nights,
    required this.travelers,
    required this.children,
    required this.onBack,
    required this.onDestinationTap,
    required this.onPickDate,
    required this.onGuestTap,
  });

  final TextEditingController destinationController;
  final DateTime? startDate;
  final DateTime? endDate;
  final int nights;
  final int travelers;
  final int children;
  final VoidCallback onBack;
  final VoidCallback onDestinationTap;
  final VoidCallback onPickDate;
  final VoidCallback onGuestTap;

  @override
  Widget build(BuildContext context) {
    final dateText = startDate != null && endDate != null
        ? '${_fmtDate(startDate)} - ${_fmtDate(endDate)}'
        : nights > 0
            ? '$nights คืน'
            : 'Date';
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        16,
        20,
      ),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/home_hero.jpg'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left,
                      size: 22, color: Color(0xFF315B4B)),
                ),
              ),
              const Expanded(
                child: Text(
                  'สร้างทริปของคุณ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
                  ),
                ),
              ),
              const SizedBox(width: 30),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF668078).withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                _HeaderInput(
                  icon: Icons.location_on_outlined,
                  child: TextFormField(
                    controller: destinationController,
                    readOnly: true,
                    onTap: onDestinationTap,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Destination is required'
                        : null,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Destination',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _HeaderInput(
                  icon: Icons.calendar_month_outlined,
                  label: dateText,
                  onTap: onPickDate,
                ),
                const SizedBox(height: 10),
                _HeaderInput(
                  icon: Icons.group_outlined,
                  label: children == 0
                      ? 'ผู้ใหญ่, $travelers คน'
                      : 'ผู้ใหญ่ $travelers, เด็ก $children คน',
                  onTap: onGuestTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderInput extends StatelessWidget {
  const _HeaderInput({
    required this.icon,
    this.label,
    this.child,
    this.onTap,
  });

  final IconData icon;
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              const SizedBox(width: 15),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEEE7),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: const Color(0xFFFF7D63)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: child ??
                    Text(
                      label!,
                      style: const TextStyle(
                        color: Color(0xFF8C8C8C),
                        fontSize: 14,
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateModeSwitch extends StatelessWidget {
  const _CreateModeSwitch({required this.aiSelected, required this.onChanged});

  final bool aiSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE5),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: 'AI จัดแผนให้',
            selected: aiSelected,
            onTap: () => onChanged(true),
          ),
          _ModeButton(
            label: 'สร้างด้วยตัวเอง',
            selected: !aiSelected,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF7D63) : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF8B8B84),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThaiSectionTitle extends StatelessWidget {
  const _ThaiSectionTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          if (subtitle != null)
            Text(subtitle!,
                style: const TextStyle(fontSize: 9, color: Color(0xFF8D8D87))),
        ],
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.items,
    required this.selected,
    required this.onTap,
    required this.showMore,
    this.moreLabel = '+ เพิ่ม',
  });

  /// `[label]`, or `[label, icon]`. The constraint chips carry no icon.
  final List<List<Object>> items;
  final List<String> selected;
  final ValueChanged<String> onTap;
  final bool showMore;
  final String moreLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 9,
      children: [
        ...items.map((item) {
          final label = item[0] as String;
          final active = selected.contains(label);
          return _OutlineChip(
            label: label,
            icon: item.length > 1 ? item[1] as IconData : null,
            active: active,
            onTap: () => onTap(label),
          );
        }),
        if (showMore)
          _OutlineChip(
            label: moreLabel,
            active: true,
            onTap: () {},
          ),
      ],
    );
  }
}

class _OutlineChip extends StatelessWidget {
  const _OutlineChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active ? const Color(0xFFFF7658) : const Color(0xFFE8D7B8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: active
                      ? const Color(0xFFFF7658)
                      : const Color(0xFFCAB37C)),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  color: active
                      ? const Color(0xFFFF7658)
                      : const Color(0xFF514D47),
                )),
          ],
        ),
      ),
    );
  }
}

/// The two-column card grid shared by "ความเข้มข้นของทริป" and "งบต่อคน / วัน".
class _TierGrid extends StatelessWidget {
  const _TierGrid({
    required this.items,
    required this.selected,
    required this.onTap,
  });

  /// `[key, title, subtitle]`.
  final List<List<String>> items;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) {
          final active = selected == item[0];
          return InkWell(
            onTap: () => onTap(item[0]),
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: width,
              // A minimum rather than a fixed height: the Thai subtitle wraps
              // to two lines in a tile this narrow, and at a larger text scale
              // so does the label.
              constraints: const BoxConstraints(minHeight: 67),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFFFF4EF) : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: active
                      ? const Color(0xFFFF7658)
                      : const Color(0xFFE8E1D5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item[1],
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(item[2],
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF85827D))),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

/// "ระบุเอง" — an exact figure, which overrides whichever bracket is selected.
class _CustomBudgetCard extends StatelessWidget {
  const _CustomBudgetCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 11, 15, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8E1D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ระบุเอง',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F2EC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: '฿',
                  hintStyle: TextStyle(color: Color(0xFF9A968E), fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "ที่พัก / โรงแรม": booked already, or still looking.
class _LodgingChoice extends StatelessWidget {
  const _LodgingChoice({required this.selected, required this.onTap});

  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _LodgingOption(
            icon: Icons.confirmation_number_outlined,
            title: 'จองแล้ว',
            subtitle: 'แนบไฟล์การจองหรือลิงก์',
            active: selected == 'booked',
            onTap: () => onTap('booked'),
          ),
          const SizedBox(height: 10),
          _LodgingOption(
            icon: Icons.search,
            title: 'ยังไม่จอง',
            subtitle: 'บอกสไตล์กับเกรดคร่าวๆ',
            active: selected == 'searching',
            onTap: () => onTap('searching'),
          ),
        ],
      ),
    );
  }
}

class _LodgingOption extends StatelessWidget {
  const _LodgingOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF4EF) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active ? const Color(0xFFFF7658) : const Color(0xFFEDE7DB),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F3EC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color:
                    active ? const Color(0xFFFF7658) : const Color(0xFFB3AB99),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF8D8A83))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.step});

  /// 0-based. A step reached is a dash; one still ahead is a dot.
  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i <= step)
            const SizedBox(
              width: 25,
              child: Divider(thickness: 6, color: Color(0xFFFFAA96)),
            )
          else
            const CircleAvatar(radius: 3, backgroundColor: Color(0xFFE8E3DB)),
          SizedBox(width: i <= step ? 6 : 7),
        ],
        Text('${step + 1} จาก 2',
            style: const TextStyle(fontSize: 9, color: Color(0xFF8D8983))),
      ],
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.enabled,
    required this.saving,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondary,
    required this.onTap,
    this.showArrow = false,
  });

  final bool enabled;
  final bool saving;
  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback onSecondary;
  final VoidCallback onTap;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFCF9),
        border: Border(top: BorderSide(color: Color(0xFFE8DDBF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: saving ? null : onSecondary,
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 46,
                child: Center(
                  child: Text(
                    secondaryLabel,
                    style: const TextStyle(
                      color: Color(0xFF96948D),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: enabled ? onTap : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 46,
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0xFFFF7D63)
                      : const Color(0xFFFFC9BD),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Center(
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              primaryLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (showArrow) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white70),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
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

/// dd/MM/yyyy, as the header reads it back.
String _fmtDate(DateTime? date) {
  if (date == null) return '--';
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}
