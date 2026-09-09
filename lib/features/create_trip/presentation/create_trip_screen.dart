import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
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
  String _budgetTier = '';
  int _travelers = 1;
  int _children = 0;
  bool _perPerson = false;
  bool _aiShown = false;
  bool _isSaving = false;
  final List<String> _selectedVibes = <String>[];

  bool get _isEditing => widget.trip != null;
  bool get _canCreate => _destinationController.text.trim().isNotEmpty;

  double get _budget => double.tryParse(_budgetController.text.trim()) ?? 0;
  double get _displayBudget => _perPerson ? _budget * _travelers : _budget;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    _titleController = TextEditingController(text: trip?.title ?? '');
    _destinationController =
        TextEditingController(text: trip?.destination ?? '');
    _budgetController = TextEditingController(
      text: trip == null ? '0' : trip.budget.round().toString(),
    );
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
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 92),
                      children: [
                        _CreateTripHeader(
                          destinationController: _destinationController,
                          startDate: _startDate,
                          endDate: _endDate,
                          travelers: _travelers,
                          children: _children,
                          onBack: _close,
                          onDestinationTap: _showDestinationSearch,
                          onPickDate: () => _pickDate(isStart: true),
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
                              _ThaiSectionTitle(title: 'สไตล์การเที่ยว'),
                              _ChoiceWrap(
                                items: const [
                                  ['ทะเล', Icons.beach_access_outlined],
                                  ['ภูเขา', Icons.terrain_outlined],
                                  ['ธรรมชาติ', Icons.eco_outlined],
                                  ['คาเฟ่', Icons.coffee_outlined],
                                  [
                                    'เข้าถึงท้องถิ่น',
                                    Icons.storefront_outlined
                                  ],
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
                              _PaceGrid(
                                selected: _budgetTier,
                                onTap: (tier, amount) =>
                                    _setBudgetTier(tier, amount),
                              ),
                              const SizedBox(height: 22),
                              const _ThaiSectionTitle(title: 'การเดินทาง'),
                              _ChoiceWrap(
                                items: const [
                                  ['เครื่องบิน', Icons.flight_outlined],
                                  ['รถส่วนตัว', Icons.directions_car_outlined],
                                  ['เช่ารถขับ', Icons.car_rental_outlined],
                                  ['มอเตอร์ไซค์', Icons.two_wheeler_outlined],
                                  [
                                    'รถสาธารณะท้องถิ่น',
                                    Icons.directions_bus_outlined
                                  ],
                                  [
                                    'แบบประหยัด',
                                    Icons.directions_walk_outlined
                                  ],
                                ],
                                selected: [_transport],
                                onTap: (value) =>
                                    setState(() => _transport = value),
                                showMore: true,
                              ),
                              const SizedBox(height: 24),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: _PageIndicator(),
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
                      child: SafeArea(
                        top: false,
                        child: _BottomActionBar(
                          enabled: _canCreate && !_isSaving,
                          saving: _isSaving,
                          isEditing: _isEditing,
                          onCancel: _close,
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

  void _setBudgetTier(String tier, String amount) {
    setState(() {
      _budgetTier = tier;
      _budgetController.text = amount;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final initialStart = _startDate != null && !_startDate!.isBefore(firstDate)
        ? _startDate!
        : firstDate;
    final initialEnd = _endDate != null && _endDate!.isAfter(initialStart)
        ? _endDate!
        : initialStart.add(const Duration(days: 7));
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      firstDate: firstDate,
      lastDate: DateTime(now.year + 3),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  secondary: AppColors.secondary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
      _durationController.text =
          picked.end.difference(picked.start).inDays.toString();
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
              budget: _displayBudget,
              duration: int.parse(_durationController.text.trim()),
              description: description,
            )
          : existing.copyWith(
              title: title,
              destination: destination,
              coverImage: _coverImageController.text.trim(),
              budget: _displayBudget,
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
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
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
                      backgroundColor: const Color(0xFF2D7757),
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
                        TextButton(
                          onPressed: () => ref
                              .read(recentDestinationsProvider.notifier)
                              .clear(),
                          child: const Text(
                            'ล้าง',
                            style: TextStyle(
                              color: Color(0xFFA5A5A1),
                              fontSize: 12,
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
    return Container(
      height: 118,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 42,
        20,
        22,
      ),
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
  final int travelers;
  final int children;
  final VoidCallback onBack;
  final VoidCallback onDestinationTap;
  final VoidCallback onPickDate;
  final VoidCallback onGuestTap;

  @override
  Widget build(BuildContext context) {
    final dateText = startDate == null || endDate == null
        ? 'Date'
        : '${_fmtDate(startDate)} - ${_fmtDate(endDate)}';
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
                  label: travelers + children == 1
                      ? '1 Guest'
                      : '${travelers + children} Guests',
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
  });
  final List<List<Object>> items;
  final List<String> selected;
  final ValueChanged<String> onTap;
  final bool showMore;

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
            icon: item[1] as IconData,
            active: active,
            onTap: () => onTap(label),
          );
        }),
        if (showMore)
          _OutlineChip(
            label: '+ เพิ่ม',
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

class _PaceGrid extends StatelessWidget {
  const _PaceGrid({required this.selected, required this.onTap});
  final String selected;
  final void Function(String tier, String amount) onTap;

  static const items = [
    ['Slow Life', '3 - 4 สถานที่/วัน', '4', '4000'],
    ['Chill', '5 - 6 สถานที่/วัน', '6', '6000'],
    ['Balance', '8 สถานที่/วัน', '8', '8000'],
    ['Active', '9 - 11 สถานที่/วัน', '10', '10000'],
    ['Hardcore', '12+ สถานที่/วัน', '12', '12000'],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) {
          final active = selected == item[2];
          return InkWell(
            onTap: () => onTap(item[2], item[3]),
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
                  Text(item[0],
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(item[1],
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

class _PageIndicator extends StatelessWidget {
  const _PageIndicator();
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 25,
          child: Divider(thickness: 6, color: Color(0xFFFFAA96)),
        ),
        SizedBox(width: 6),
        CircleAvatar(radius: 3, backgroundColor: Color(0xFFE8E3DB)),
        SizedBox(width: 7),
        Text('1 จาก 2',
            style: TextStyle(fontSize: 9, color: Color(0xFF8D8983))),
      ],
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.enabled,
    required this.saving,
    required this.isEditing,
    required this.onCancel,
    required this.onTap,
  });

  final bool enabled;
  final bool saving;
  final bool isEditing;
  final VoidCallback onCancel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFCF9),
        border: Border(top: BorderSide(color: Color(0xFFE8DDBF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: saving ? null : onCancel,
              borderRadius: BorderRadius.circular(99),
              child: const SizedBox(
                height: 46,
                child: Center(
                  child: Text(
                    'ข้ามไปก่อน',
                    style: TextStyle(
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
                              isEditing ? 'บันทึก' : 'ถัดไป',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
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

String _fmtDate(DateTime? date) {
  if (date == null) return '--';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}
