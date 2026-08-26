import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/cover_image_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../trips/domain/models/trip.dart';
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

  String? _selectedCoverImage;
  DateTime? _startDate;
  DateTime? _endDate;
  String _transport = 'flight';
  String _budgetTier = '';
  String _privacy = 'public';
  String _currency = 'USD';
  int _travelers = 2;
  bool _perPerson = false;
  bool _aiShown = false;
  bool _isSaving = false;
  final List<String> _selectedVibes = <String>[];
  final List<_TripDayDraft> _days = <_TripDayDraft>[];
  final List<_PlaceDraft> _places = <_PlaceDraft>[];
  String? _openDayId;
  String? _editingActivityId;

  bool get _isEditing => widget.trip != null;
  bool get _canCreate => _destinationController.text.trim().isNotEmpty;

  double get _budget => double.tryParse(_budgetController.text.trim()) ?? 0;
  double get _displayBudget => _perPerson ? _budget * _travelers : _budget;
  int get _duration => int.tryParse(_durationController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    _titleController = TextEditingController(text: trip?.title ?? '');
    _destinationController = TextEditingController(text: trip?.destination ?? '');
    _budgetController = TextEditingController(
      text: trip == null ? '0' : trip.budget.round().toString(),
    );
    _durationController = TextEditingController(
      text: trip == null ? '7' : trip.duration.toString(),
    );
    _descriptionController = TextEditingController(text: trip?.description ?? '');
    _selectedCoverImage = trip?.coverImage;
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
      backgroundColor: AppColors.background,
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final framed = constraints.maxWidth > 430;
            return Container(
              width: constraints.maxWidth < 430 ? constraints.maxWidth : 430,
              height: framed && constraints.maxHeight > 932
                  ? 932
                  : constraints.maxHeight,
              color: AppColors.screen,
              child: Form(
                key: _formKey,
                child: Stack(
                  children: [
                    ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 118),
                      children: [
                        _HeroWithSheetCap(
                          destination: _destinationController.text.trim(),
                          startDate: _startDate,
                          endDate: _endDate,
                          duration: _duration,
                          coverImage: _selectedCoverImage,
                          onBack: _close,
                          onChangeCover: _pickCoverImage,
                        ),
                        Container(
                          color: AppColors.screen,
                          child: Column(
                            children: [
                              _SheetSection(
                                topPadding: 0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionLabel('Where to?'),
                                    _DestinationCard(
                                      controller: _destinationController,
                                      onPresetSelected: _setDestination,
                                    ),
                                  ],
                                ),
                              ),
                              _SheetSection(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionLabel('When?'),
                                    _DateCard(
                                      startDate: _startDate,
                                      endDate: _endDate,
                                      duration: _startDate != null &&
                                              _endDate != null
                                          ? _duration
                                          : 0,
                                      onPickStart: () =>
                                          _pickDate(isStart: true),
                                      onPickEnd: () =>
                                          _pickDate(isStart: false),
                                    ),
                                  ],
                                ),
                              ),
                              _SheetSection(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionLabel("What's the vibe?"),
                                    _VibeCard(
                                      selected: _selectedVibes,
                                      onToggle: _toggleVibe,
                                    ),
                                  ],
                                ),
                              ),
                              _SheetSection(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionLabel('Getting there'),
                                    _TransportCard(
                                      active: _transport,
                                      onSelected: (value) {
                                        setState(() => _transport = value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              _SheetSection(
                                child: _ItineraryBuilder(
                                  days: _days,
                                  openDayId: _openDayId,
                                  editingActivityId: _editingActivityId,
                                  onAddDay: _addDay,
                                  onToggleDay: _toggleDay,
                                  onRemoveDay: _removeDay,
                                  onUpdateDay: _updateDay,
                                  onAddActivity: _addActivity,
                                  onEditActivity: _editActivity,
                                  onUpdateActivity: _updateActivity,
                                  onRemoveActivity: _removeActivity,
                                ),
                              ),
                              _SheetSection(
                                child: _PlacesBuilder(
                                  destination:
                                      _destinationController.text.trim(),
                                  places: _places,
                                  onAddPlace: _addPlace,
                                  onRemovePlace: _removePlace,
                                ),
                              ),
                              _SheetSection(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionLabel('Budget'),
                                    _BudgetCard(
                                      activeTier: _budgetTier,
                                      controller: _budgetController,
                                      currency: _currency,
                                      displayBudget: _displayBudget,
                                      rawBudget: _budget,
                                      travelers: _travelers,
                                      perPerson: _perPerson,
                                      onTierSelected: _setBudgetTier,
                                      onCurrencyChanged: (value) {
                                        setState(() => _currency = value);
                                      },
                                      onTravelerChanged: (value) {
                                        setState(() => _travelers = value);
                                      },
                                      onPerPersonChanged: (value) {
                                        setState(() => _perPerson = value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              _SheetSection(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionLabel('Who can see this?'),
                                    _PrivacyCard(
                                      active: _privacy,
                                      onSelected: (value) {
                                        setState(() => _privacy = value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              _SheetSection(
                                hasBorder: false,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionLabel('AI Trip Planner'),
                                    _AiPlannerCard(
                                      destination:
                                          _destinationController.text.trim(),
                                      shown: _aiShown,
                                      onGenerate: () {
                                        if (_destinationController.text
                                            .trim()
                                            .isEmpty) {
                                          return;
                                        }
                                        setState(() => _aiShown = true);
                                      },
                                    ),
                                  ],
                                ),
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

  void _setDestination(String destination) {
    _destinationController.text = destination;
  }

  Future<void> _pickCoverImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (image == null) return;

      final savedPath = await persistCoverImage(image);
      if (!mounted) return;
      setState(() {
        _selectedCoverImage = savedPath;
        _coverImageController.text = savedPath;
      });
    } catch (error) {
      _showError('Could not open your photos. Please try again.');
    }
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

  String _draftId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _addDay() {
    final day = _TripDayDraft(
      id: _draftId(),
      dayNumber: _days.length + 1,
      title: 'New Day',
    );
    setState(() {
      _days.add(day);
      _openDayId = day.id;
    });
  }

  void _toggleDay(String id) {
    setState(() => _openDayId = _openDayId == id ? null : id);
  }

  void _removeDay(String id) {
    setState(() {
      _days.removeWhere((day) => day.id == id);
      for (var index = 0; index < _days.length; index++) {
        _days[index] = _days[index].copyWith(dayNumber: index + 1);
      }
      if (_openDayId == id) _openDayId = null;
    });
  }

  void _updateDay(String id, String title) {
    setState(() {
      final index = _days.indexWhere((day) => day.id == id);
      if (index != -1) _days[index] = _days[index].copyWith(title: title);
    });
  }

  void _addActivity(String dayId) {
    final activity = _TripActivityDraft(
      id: _draftId(),
      time: '9:00 AM',
      title: '',
      location: '',
      type: 'activity',
    );
    setState(() {
      final index = _days.indexWhere((day) => day.id == dayId);
      if (index == -1) return;
      _days[index] = _days[index].copyWith(
        activities: [..._days[index].activities, activity],
      );
      _editingActivityId = activity.id;
    });
  }

  void _editActivity(String id) {
    setState(() {
      _editingActivityId = _editingActivityId == id ? null : id;
    });
  }

  void _updateActivity(
    String dayId,
    String activityId, {
    String? time,
    String? title,
    String? location,
    String? type,
  }) {
    setState(() {
      final dayIndex = _days.indexWhere((day) => day.id == dayId);
      if (dayIndex == -1) return;
      final activities = [..._days[dayIndex].activities];
      final activityIndex =
          activities.indexWhere((activity) => activity.id == activityId);
      if (activityIndex == -1) return;
      activities[activityIndex] = activities[activityIndex].copyWith(
        time: time,
        title: title,
        location: location,
        type: type,
      );
      _days[dayIndex] = _days[dayIndex].copyWith(activities: activities);
    });
  }

  void _removeActivity(String dayId, String activityId) {
    setState(() {
      final dayIndex = _days.indexWhere((day) => day.id == dayId);
      if (dayIndex == -1) return;
      _days[dayIndex] = _days[dayIndex].copyWith(
        activities: _days[dayIndex]
            .activities
            .where((activity) => activity.id != activityId)
            .toList(),
      );
      if (_editingActivityId == activityId) _editingActivityId = null;
    });
  }

  void _addPlace() {
    setState(() {
      _places.add(
        _PlaceDraft(
          id: _draftId(),
          name: 'New place',
          type: 'Recommended',
        ),
      );
    });
  }

  void _removePlace(String id) {
    setState(() => _places.removeWhere((place) => place.id == id));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final initialStart =
        _startDate != null && !_startDate!.isBefore(firstDate)
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

class _HeroCover extends StatelessWidget {
  const _HeroCover({
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.coverImage,
    required this.onBack,
    required this.onChangeCover,
  });

  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final int duration;
  final String? coverImage;
  final VoidCallback onBack;
  final VoidCallback onChangeCover;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChangeCover,
      child: SizedBox(
        height: 280,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverImage == null)
              const _EmptyCover()
            else
              CoverImage(source: coverImage!, fit: BoxFit.cover),
            if (coverImage != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.26),
                      Colors.transparent,
                      Colors.black.withOpacity(0.58),
                    ],
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GlassButton(icon: Icons.chevron_left, onTap: onBack),
                    if (coverImage != null)
                      GestureDetector(
                        onTap: onChangeCover,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.image_outlined,
                                  size: 15, color: AppColors.foreground),
                              const SizedBox(width: 6),
                              const Text(
                                'Change',
                                style: TextStyle(
                                  color: AppColors.foreground,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: destination.isEmpty
                  ? Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 15, color: Colors.white.withOpacity(0.78)),
                        const SizedBox(width: 6),
                        Text(
                          'Choose a destination below',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.82),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEW TRIP',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destination,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (startDate != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  color: Colors.white.withOpacity(0.84),
                                  size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${_fmtDate(startDate)}'
                                '${endDate == null ? '' : ' -> ${_fmtDate(endDate)}'}'
                                '${duration <= 0 ? '' : ' · ${duration}n'}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.88),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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

class _HeroWithSheetCap extends StatelessWidget {
  const _HeroWithSheetCap({
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.coverImage,
    required this.onBack,
    required this.onChangeCover,
  });

  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final int duration;
  final String? coverImage;
  final VoidCallback onBack;
  final VoidCallback onChangeCover;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroCover(
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            coverImage: coverImage,
            onBack: onBack,
            onChangeCover: onChangeCover,
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SheetCap(),
          ),
        ],
      ),
    );
  }
}

class _SheetCap extends StatelessWidget {
  const _SheetCap();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _EmptyCover extends StatelessWidget {
  const _EmptyCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC8DFCA), Color(0xFFB4CEC4), Color(0xFFC2D5CE)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.photo_camera_outlined,
                      color: AppColors.primary, size: 25),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Add Cover Photo',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tap to choose a photo',
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.70),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A7D50).withOpacity(0.14)
      ..strokeWidth = 0.7;
    for (double x = 0; x <= size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({
    required this.child,
    this.topPadding = 0,
    this.hasBorder = true,
  });

  final Widget child;
  final double topPadding;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.screen,
        border: hasBorder
            ? const Border(bottom: BorderSide(color: AppColors.line))
            : null,
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF6A6A6A),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.padding, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.controller,
    required this.onPresetSelected,
  });

  final TextEditingController controller;
  final ValueChanged<String> onPresetSelected;

  static const _presets = [
    ['🏝️', 'Maldives'],
    ['🏔️', 'Swiss Alps'],
    ['⛩️', 'Kyoto'],
    ['🏛️', 'Santorini'],
    ['🌺', 'Bali'],
    ['🗼', 'Paris'],
    ['🗽', 'New York'],
    ['🍋', 'Amalfi'],
  ];

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _IconBubble(icon: Icons.location_on, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search destination...',
                      isDense: true,
                    ),
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Destination is required';
                      }
                      return null;
                    },
                  ),
                ),
                if (controller.text.trim().isNotEmpty)
                  GestureDetector(
                    onTap: () => controller.clear(),
                    child: const Icon(Icons.close,
                        size: 17, color: Color(0xFFC0C0C0)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((item) {
                final emoji = item[0];
                final label = item[1];
                final active = controller.text.trim() == label;
                return _NeutralPill(
                  label: '$emoji $label',
                  active: active,
                  onTap: () => onPresetSelected(label),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final int duration;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DateBox(
                  label: 'From',
                  value: _fmtDate(startDate),
                  active: startDate != null,
                  onTap: onPickStart,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.foreground,
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: Colors.white, size: 18),
                ),
              ),
              Expanded(
                child: _DateBox(
                  label: 'To',
                  value: _fmtDate(endDate),
                  active: endDate != null,
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
          if (duration > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '$duration night${duration == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.06) : const Color(0xFFF8F7F5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? AppColors.primary : Colors.black.withOpacity(0.08),
            width: 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFA0A0A0),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: active ? AppColors.foreground : const Color(0xFFC8C8C8),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VibeCard extends StatelessWidget {
  const _VibeCard({required this.selected, required this.onToggle});

  final List<String> selected;
  final ValueChanged<String> onToggle;

  static const List<List<Object>> _vibes = [
    ['Beach', Icons.beach_access, Color(0xFF0288D1)],
    ['Hiking', Icons.hiking, Color(0xFF2E7D32)],
    ['Food Tour', Icons.ramen_dining, AppColors.accent],
    ['Culture', Icons.account_balance, Color(0xFF8B6BAE)],
    ['Shopping', Icons.shopping_bag_outlined, Color(0xFFE91E8C)],
    ['Nightlife', Icons.nightlife, Color(0xFF1565C0)],
    ['Arts', Icons.theater_comedy_outlined, Color(0xFF9B59B6)],
    ['Adventure', Icons.paragliding, AppColors.accent],
    ['Wellness', Icons.spa_outlined, Color(0xFF2A9E64)],
    ['Photography', Icons.photo_camera_outlined, Color(0xFF5B8DD9)],
    ['Surfing', Icons.surfing, Color(0xFF0097A7)],
    ['Wildlife', Icons.pets, Color(0xFF795548)],
  ];

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: _vibes.map((item) {
          final label = item[0] as String;
          final icon = item[1] as IconData;
          final color = item[2] as Color;
          final active = selected.contains(label);
          return _VibePill(
            label: label,
            icon: icon,
            active: active,
            color: color,
            onTap: () => onToggle(label),
          );
        }).toList(),
      ),
    );
  }
}

class _VibePill extends StatelessWidget {
  const _VibePill({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? color.withOpacity(0.50)
                : const Color(0xFFE9E6E2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 5),
              Icon(Icons.check_circle, size: 13, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransportCard extends StatelessWidget {
  const _TransportCard({required this.active, required this.onSelected});

  final String active;
  final ValueChanged<String> onSelected;

  static const List<List<Object>> _items = [
    ['flight', Icons.flight, 'Flight', Color(0xFF5B9BD5)],
    ['train', Icons.train, 'Train', Color(0xFF5B8DD9)],
    ['bus', Icons.directions_bus, 'Bus', AppColors.accent],
    ['car', Icons.directions_car, 'Drive', AppColors.primary],
    ['boat', Icons.directions_boat, 'Boat', Color(0xFF0097A7)],
    ['moto', Icons.motorcycle, 'Moto', AppColors.accent],
    ['bike', Icons.directions_bike, 'Bicycle', Color(0xFF2E7D32)],
    ['walk', Icons.directions_walk, 'Walking', Color(0xFF795548)],
  ];

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        children: [
          _TransportRow(
            items: _items.sublist(0, 4),
            active: active,
            onSelected: onSelected,
          ),
          const SizedBox(height: 8),
          _TransportRow(
            items: _items.sublist(4),
            active: active,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({
    required this.items,
    required this.active,
    required this.onSelected,
  });

  final List<List<Object>> items;
  final String active;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        final key = item[0] as String;
        final icon = item[1] as IconData;
        final label = item[2] as String;
        final color = item[3] as Color;
        final selected = active == key;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _IconChoice(
              icon: icon,
              label: label,
              color: color,
              selected: selected,
              onTap: () => onSelected(key),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TripDayDraft {
  const _TripDayDraft({
    required this.id,
    required this.dayNumber,
    required this.title,
    this.activities = const <_TripActivityDraft>[],
  });

  final String id;
  final int dayNumber;
  final String title;
  final List<_TripActivityDraft> activities;

  _TripDayDraft copyWith({
    int? dayNumber,
    String? title,
    List<_TripActivityDraft>? activities,
  }) {
    return _TripDayDraft(
      id: id,
      dayNumber: dayNumber ?? this.dayNumber,
      title: title ?? this.title,
      activities: activities ?? this.activities,
    );
  }
}

class _TripActivityDraft {
  const _TripActivityDraft({
    required this.id,
    required this.time,
    required this.title,
    required this.location,
    required this.type,
  });

  final String id;
  final String time;
  final String title;
  final String location;
  final String type;

  _TripActivityDraft copyWith({
    String? time,
    String? title,
    String? location,
    String? type,
  }) {
    return _TripActivityDraft(
      id: id,
      time: time ?? this.time,
      title: title ?? this.title,
      location: location ?? this.location,
      type: type ?? this.type,
    );
  }
}

class _PlaceDraft {
  const _PlaceDraft({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;
  final String type;
}

class _ItineraryBuilder extends StatelessWidget {
  const _ItineraryBuilder({
    required this.days,
    required this.openDayId,
    required this.editingActivityId,
    required this.onAddDay,
    required this.onToggleDay,
    required this.onRemoveDay,
    required this.onUpdateDay,
    required this.onAddActivity,
    required this.onEditActivity,
    required this.onUpdateActivity,
    required this.onRemoveActivity,
  });

  final List<_TripDayDraft> days;
  final String? openDayId;
  final String? editingActivityId;
  final VoidCallback onAddDay;
  final ValueChanged<String> onToggleDay;
  final ValueChanged<String> onRemoveDay;
  final void Function(String id, String title) onUpdateDay;
  final ValueChanged<String> onAddActivity;
  final ValueChanged<String> onEditActivity;
  final void Function(
    String dayId,
    String activityId, {
    String? time,
    String? title,
    String? location,
    String? type,
  }) onUpdateActivity;
  final void Function(String dayId, String activityId) onRemoveActivity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('Day by day')),
            _OutlineActionButton(
              icon: Icons.add,
              label: 'Add Day',
              onTap: onAddDay,
            ),
          ],
        ),
        if (days.isEmpty)
          GestureDetector(
            onTap: onAddDay,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.045),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.28),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Plan your itinerary',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap to add your first day',
                    style: TextStyle(
                      color: Color(0xFFA0A0A0),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...days.map((day) {
            final isOpen = day.id == openDayId;
            return _DayCard(
              day: day,
              isOpen: isOpen,
              editingActivityId: editingActivityId,
              onToggle: () => onToggleDay(day.id),
              onRemove: () => onRemoveDay(day.id),
              onUpdateTitle: (title) => onUpdateDay(day.id, title),
              onAddActivity: () => onAddActivity(day.id),
              onEditActivity: onEditActivity,
              onUpdateActivity: (
                activityId, {
                time,
                title,
                location,
                type,
              }) =>
                  onUpdateActivity(
                day.id,
                activityId,
                time: time,
                title: title,
                location: location,
                type: type,
              ),
              onRemoveActivity: (activityId) =>
                  onRemoveActivity(day.id, activityId),
            );
          }),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.isOpen,
    required this.editingActivityId,
    required this.onToggle,
    required this.onRemove,
    required this.onUpdateTitle,
    required this.onAddActivity,
    required this.onEditActivity,
    required this.onUpdateActivity,
    required this.onRemoveActivity,
  });

  final _TripDayDraft day;
  final bool isOpen;
  final String? editingActivityId;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final ValueChanged<String> onUpdateTitle;
  final VoidCallback onAddActivity;
  final ValueChanged<String> onEditActivity;
  final void Function(
    String activityId, {
    String? time,
    String? title,
    String? location,
    String? type,
  }) onUpdateActivity;
  final ValueChanged<String> onRemoveActivity;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isOpen
                            ? AppColors.primary
                            : const Color(0xFFF3F2F1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.dayNumber}',
                        style: TextStyle(
                          color:
                              isOpen ? Colors.white : const Color(0xFF8A8A8A),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAY ${day.dayNumber}',
                            style: const TextStyle(
                              color: Color(0xFFA0A0A0),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                          if (isOpen)
                            TextFormField(
                              initialValue: day.title,
                              onChanged: onUpdateTitle,
                              onTap: () {},
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.only(top: 4),
                              ),
                              style: const TextStyle(
                                color: AppColors.foreground,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                day.title.isEmpty ? 'Untitled Day' : day.title,
                                style: const TextStyle(
                                  color: AppColors.foreground,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (day.activities.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${day.activities.length} stop${day.activities.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4183D).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 15,
                          color: Color(0xFFD4183D),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFFA0A0A0),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: isOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                children: [
                  const Divider(height: 1, color: AppColors.line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      children: [
                        ...day.activities.asMap().entries.map((entry) {
                          final activity = entry.value;
                          return _ActivityRow(
                            activity: activity,
                            drawLine: entry.key < day.activities.length - 1,
                            editing: editingActivityId == activity.id,
                            onEdit: () => onEditActivity(activity.id),
                            onUpdate: ({
                              time,
                              title,
                              location,
                              type,
                            }) =>
                                onUpdateActivity(
                              activity.id,
                              time: time,
                              title: title,
                              location: location,
                              type: type,
                            ),
                            onRemove: () =>
                                onRemoveActivity(activity.id),
                          );
                        }),
                        _DashedActionButton(
                          icon: Icons.add,
                          label: 'Add activity',
                          onTap: onAddActivity,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityStyle {
  const _ActivityStyle(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;
}

const Map<String, _ActivityStyle> _activityStyles = {
  'activity': _ActivityStyle(Icons.terrain, 'Activity', AppColors.primary),
  'food': _ActivityStyle(Icons.restaurant, 'Dining', AppColors.accent),
  'transport':
      _ActivityStyle(Icons.directions_bus, 'Transport', Color(0xFF6B7FD4)),
  'hotel': _ActivityStyle(Icons.apartment, 'Stay', Color(0xFF5B9BD5)),
  'photo': _ActivityStyle(Icons.photo_camera_outlined, 'Photo', Color(0xFF9B59B6)),
  'coffee': _ActivityStyle(Icons.local_cafe_outlined, 'Café', Color(0xFF8B6B4A)),
};

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activity,
    required this.drawLine,
    required this.editing,
    required this.onEdit,
    required this.onUpdate,
    required this.onRemove,
  });

  final _TripActivityDraft activity;
  final bool drawLine;
  final bool editing;
  final VoidCallback onEdit;
  final void Function({
    String? time,
    String? title,
    String? location,
    String? type,
  }) onUpdate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final style = _activityStyles[activity.type] ?? _activityStyles['activity']!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Column(
            children: [
              editing
                  ? TextFormField(
                      initialValue: activity.time,
                      onChanged: (value) => onUpdate(time: value),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.only(bottom: 6),
                      ),
                      style: const TextStyle(
                        color: Color(0xFFA0A0A0),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        activity.time,
                        style: const TextStyle(
                          color: Color(0xFFA0A0A0),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: style.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: style.color.withOpacity(0.18),
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              if (drawLine)
                Container(
                  width: 1.5,
                  height: 72,
                  margin: const EdgeInsets.only(top: 5),
                  color: const Color(0xFFEDE9E4),
                ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onEdit,
            child: Container(
              margin: const EdgeInsets.only(left: 8, bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: editing
                      ? style.color.withOpacity(0.35)
                      : Colors.black.withOpacity(0.04),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: style.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(style.icon, size: 16, color: style.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: editing
                            ? Column(
                                children: [
                                  TextFormField(
                                    initialValue: activity.title,
                                    onChanged: (value) =>
                                        onUpdate(title: value),
                                    decoration: const InputDecoration(
                                      hintText: 'Activity title...',
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.foreground,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 12,
                                        color: Color(0xFFC0C0C0),
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: activity.location,
                                          onChanged: (value) =>
                                              onUpdate(location: value),
                                          decoration: const InputDecoration(
                                            hintText: 'Location...',
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.only(top: 3),
                                          ),
                                          style: const TextStyle(
                                            color: Color(0xFFA0A0A0),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity.title.isEmpty
                                        ? 'Tap to edit activity...'
                                        : activity.title,
                                    style: TextStyle(
                                      color: activity.title.isEmpty
                                          ? const Color(0xFFC0C0C0)
                                          : AppColors.foreground,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (activity.location.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 12,
                                            color: Color(0xFFC0C0C0),
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              activity.location,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFFA0A0A0),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: style.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          style.label,
                          style: TextStyle(
                            color: style.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4183D).withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Color(0xFFD4183D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (editing) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _activityStyles.entries.map((entry) {
                          final active = activity.type == entry.key;
                          final option = entry.value;
                          return GestureDetector(
                            onTap: () => onUpdate(type: entry.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? option.color
                                    : option.color.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: option.color.withOpacity(
                                    active ? 1 : 0.24,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    option.icon,
                                    size: 11,
                                    color:
                                        active ? Colors.white : option.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    option.label,
                                    style: TextStyle(
                                      color:
                                          active ? Colors.white : option.color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlacesBuilder extends StatelessWidget {
  const _PlacesBuilder({
    required this.destination,
    required this.places,
    required this.onAddPlace,
    required this.onRemovePlace,
  });

  final String destination;
  final List<_PlaceDraft> places;
  final VoidCallback onAddPlace;
  final ValueChanged<String> onRemovePlace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Map'),
        _MapPreview(destination: destination),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: _SectionLabel('Recommended spots')),
            _OutlineActionButton(
              icon: Icons.add,
              label: 'Add Place',
              onTap: onAddPlace,
            ),
          ],
        ),
        if (places.isEmpty)
          GestureDetector(
            onTap: onAddPlace,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.045),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.28),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_location_alt_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add recommended spots',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hotels, restaurants, attractions…',
                    style: TextStyle(
                      color: Color(0xFFA0A0A0),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: places.map((place) {
              return Container(
                width: 178,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.foreground,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            place.type,
                            style: const TextStyle(
                              color: Color(0xFFA0A0A0),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onRemovePlace(place.id),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFFC0C0C0),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC8DFCA), Color(0xFFB4CEC4), Color(0xFFC2D5CE)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned.fill(child: CustomPaint(painter: _MapRoadPainter())),
          const Positioned(left: 78, top: 58, child: _MapPin(primary: true)),
          const Positioned(left: 220, top: 86, child: _MapPin()),
          const Positioned(right: 92, top: 40, child: _MapPin()),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primary,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    destination.isEmpty ? 'Your destination' : destination,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Open Map',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
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

class _MapPin extends StatelessWidget {
  const _MapPin({this.primary = false});

  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = primary ? AppColors.primary : AppColors.accent;
    return Container(
      width: primary ? 20 : 14,
      height: primary ? 20 : 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.24),
            spreadRadius: primary ? 5 : 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: primary
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _MapRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final broadRoad = Paint()
      ..color = Colors.white.withOpacity(0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final slimRoad = Paint()
      ..color = Colors.white.withOpacity(0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final first = Path()
      ..moveTo(-10, size.height * 0.48)
      ..quadraticBezierTo(
        size.width * 0.23,
        size.height * 0.32,
        size.width * 0.52,
        size.height * 0.47,
      )
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.58,
        size.width + 10,
        size.height * 0.45,
      );
    final second = Path()
      ..moveTo(-10, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.84,
        size.width * 0.48,
        size.height * 0.63,
      )
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.48,
        size.width + 10,
        size.height * 0.76,
      );
    canvas.drawPath(first, broadRoad);
    canvas.drawPath(second, slimRoad);

    final verticalRoad = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(size.width * 0.40, -10),
      Offset(size.width * 0.38, size.height + 10),
      verticalRoad,
    );
    canvas.drawLine(
      Offset(size.width * 0.73, -10),
      Offset(size.width * 0.70, size.height + 10),
      verticalRoad,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.primary.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedActionButton extends StatelessWidget {
  const _DashedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _ItineraryDashedBorderPainter(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItineraryDashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(18),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + 6),
          paint,
        );
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant _ItineraryDashedBorderPainter oldDelegate,
  ) =>
      false;
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.activeTier,
    required this.controller,
    required this.currency,
    required this.displayBudget,
    required this.rawBudget,
    required this.travelers,
    required this.perPerson,
    required this.onTierSelected,
    required this.onCurrencyChanged,
    required this.onTravelerChanged,
    required this.onPerPersonChanged,
  });

  final String activeTier;
  final TextEditingController controller;
  final String currency;
  final double displayBudget;
  final double rawBudget;
  final int travelers;
  final bool perPerson;
  final void Function(String tier, String amount) onTierSelected;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<int> onTravelerChanged;
  final ValueChanged<bool> onPerPersonChanged;

  static const _tiers = [
    ['economy', '🎒', 'Economy', 'Under \$1k', '900', Color(0xFF2A9E64)],
    ['comfort', '🏨', 'Comfort', '\$1k-\$3k', '1500', Color(0xFF5B9BD5)],
    ['premium', '✈️', 'Premium', '\$3k-\$8k', '4500', Color(0xFF5B8DD9)],
    ['luxury', '💎', 'Luxury', '\$8k+', '9000', AppColors.accent],
  ];

  static const _currencies = ['USD', 'EUR', 'GBP', 'THB', 'JPY', 'SGD'];

  @override
  Widget build(BuildContext context) {
    final categories = _BudgetCategory.defaults();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F6B45), AppColors.primary, AppColors.secondary],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          perPerson
                              ? 'PER PERSON ESTIMATED BUDGET'
                              : 'TOTAL ESTIMATED BUDGET',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${_currencySymbol(currency)}${_formatNumber(displayBudget.round())}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              height: 1.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (perPerson && travelers > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${_currencySymbol(currency)}${_formatNumber(rawBudget.round())} x $travelers travelers',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.62),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    initialValue: currency,
                    onSelected: onCurrencyChanged,
                    itemBuilder: (context) => _currencies
                        .map((value) => PopupMenuItem(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(
                            currency,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (rawBudget > 0) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Row(
                    children: categories.map((category) {
                      return Expanded(
                        flex: category.flex,
                        child: Container(height: 6, color: category.color),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => onPerPersonChanged(!perPerson),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: perPerson
                            ? Colors.white.withOpacity(0.25)
                            : Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white.withOpacity(0.20)),
                      ),
                      child: Row(
                        children: [
                          if (perPerson) ...[
                            const Icon(Icons.check,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 5),
                          ],
                          const Text(
                            'Per person',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _TinyRoundButton(
                        icon: Icons.remove,
                        onTap: () =>
                            onTravelerChanged(
                              (travelers - 1).clamp(1, 20).toInt(),
                            ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$travelers ${travelers == 1 ? 'person' : 'people'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _TinyRoundButton(
                        icon: Icons.add,
                        onTap: () =>
                            onTravelerChanged(
                              (travelers + 1).clamp(1, 20).toInt(),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        _SoftCard(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 10),
                child: Text(
                  'QUICK PRESET',
                  style: TextStyle(
                    color: Color(0xFFA0A0A0),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              Row(
                children: _tiers.map((item) {
                  final key = item[0] as String;
                  final emoji = item[1] as String;
                  final label = item[2] as String;
                  final sub = item[3] as String;
                  final amount = item[4] as String;
                  final color = item[5] as Color;
                  final active = activeTier == key;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _BudgetTierButton(
                        emoji: emoji,
                        label: label,
                        sub: sub,
                        color: color,
                        active: active,
                        onTap: () => onTierSelected(key, amount),
                      ),
                    ),
                  );
                }).toList(),
              ),
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5FAF7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_money,
                        size: 16, color: AppColors.primary),
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Custom amount',
                        ),
                        style: const TextStyle(
                          color: AppColors.foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        validator: (value) {
                          if (value == null || double.tryParse(value) == null) {
                            return 'Budget must be numeric';
                          }
                          return null;
                        },
                      ),
                    ),
                    Text(
                      currency,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _BudgetBreakdownCard(
          categories: categories,
          total: rawBudget,
          currency: currency,
          margin: const EdgeInsets.only(top: 12),
        ),
        const _BudgetHintCard(),
      ],
    );
  }
}

class _BudgetBreakdownCard extends StatefulWidget {
  const _BudgetBreakdownCard({
    required this.categories,
    required this.total,
    required this.currency,
    this.margin,
  });

  final List<_BudgetCategory> categories;
  final double total;
  final String currency;
  final EdgeInsetsGeometry? margin;

  @override
  State<_BudgetBreakdownCard> createState() => _BudgetBreakdownCardState();
}

class _BudgetBreakdownCardState extends State<_BudgetBreakdownCard> {
  late String? _expandedKey;
  late Map<String, List<_BudgetLocationEntry>> _entriesByCategory;

  @override
  void initState() {
    super.initState();
    _expandedKey =
        widget.categories.isEmpty ? null : widget.categories.first.key;
    _entriesByCategory = {
      for (final category in widget.categories)
        category.key: <_BudgetLocationEntry>[],
    };
  }

  @override
  void didUpdateWidget(covariant _BudgetBreakdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final category in widget.categories) {
      _entriesByCategory.putIfAbsent(
        category.key,
        () => <_BudgetLocationEntry>[],
      );
    }
    if (_expandedKey == null && widget.categories.isNotEmpty) {
      _expandedKey = widget.categories.first.key;
    }
  }

  bool get _hasCustomEntries =>
      _entriesByCategory.values.any((entries) => entries.isNotEmpty);

  int get _customTotal {
    return _entriesByCategory.values
        .expand((entries) => entries)
        .fold<int>(0, (sum, entry) => sum + (int.tryParse(entry.price) ?? 0));
  }

  int _categoryTotal(String key) {
    return (_entriesByCategory[key] ?? <_BudgetLocationEntry>[])
        .fold<int>(0, (sum, entry) => sum + (int.tryParse(entry.price) ?? 0));
  }

  void _toggleCategory(String key) {
    setState(() => _expandedKey = _expandedKey == key ? null : key);
  }

  void _addEntry(String key) {
    setState(() {
      _expandedKey = key;
      _entriesByCategory[key]!.add(
        _BudgetLocationEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
        ),
      );
    });
  }

  void _removeEntry(String key, String id) {
    setState(() {
      _entriesByCategory[key]!.removeWhere((entry) => entry.id == id);
    });
  }

  void _updateEntry(
    String key,
    String id, {
    String? name,
    String? price,
  }) {
    setState(() {
      final entries = _entriesByCategory[key]!;
      final index = entries.indexWhere((entry) => entry.id == id);
      if (index == -1) return;
      entries[index] = entries[index].copyWith(name: name, price: price);
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTotal =
        _hasCustomEntries ? _customTotal.toDouble() : widget.total;
    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Text(
              'Breakdown by Category',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 17,
                height: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ...widget.categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final entries =
                _entriesByCategory[category.key] ?? <_BudgetLocationEntry>[];
            final customAmount = _categoryTotal(category.key);
            final amount = entries.isNotEmpty
                ? customAmount.toDouble()
                : widget.total > 0
                    ? widget.total * category.percent
                    : 0.0;
            return Column(
              children: [
                _BudgetCategoryRow(
                  category: category,
                  amount: amount,
                  total: effectiveTotal,
                  currency: widget.currency,
                  entries: entries,
                  isExpanded: _expandedKey == category.key,
                  onToggle: () => _toggleCategory(category.key),
                  onAddEntry: () => _addEntry(category.key),
                  onRemoveEntry: (id) => _removeEntry(category.key, id),
                  onUpdateEntry: (id, {name, price}) => _updateEntry(
                    category.key,
                    id,
                    name: name,
                    price: price,
                  ),
                ),
                if (index < widget.categories.length - 1)
                  const Divider(
                    height: 1,
                    color: Color(0xFFF0EDE9),
                    indent: 18,
                    endIndent: 18,
                  ),
              ],
            );
          }).toList(),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F7F5),
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                const Icon(Icons.attach_money,
                    size: 23, color: AppColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  effectiveTotal > 0
                      ? '${_currencySymbol(widget.currency)}${_formatNumber(effectiveTotal.round())}'
                      : '${_currencySymbol(widget.currency)}0',
                  style: TextStyle(
                    color: effectiveTotal > 0
                        ? AppColors.foreground
                        : const Color(0xFFC0C0C0),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
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

class _BudgetHintCard extends StatelessWidget {
  const _BudgetHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF4D8BD), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('💡', style: TextStyle(fontSize: 18, height: 1.2)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap a preset to auto-fill all categories, then adjust individual amounts to fit your plan.',
              style: TextStyle(
                color: Color(0xFF906B3D),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCategory {
  const _BudgetCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.percent,
    required this.flex,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final double percent;
  final int flex;

  static List<_BudgetCategory> defaults() {
    return const [
      _BudgetCategory(
        key: 'accommodation',
        label: 'Accommodation',
        icon: Icons.apartment,
        color: Color(0xFF5B9BD5),
        bgColor: Color(0xFFEFF6FF),
        percent: 0.30,
        flex: 30,
      ),
      _BudgetCategory(
        key: 'food',
        label: 'Food & Dining',
        icon: Icons.restaurant_menu,
        color: AppColors.accent,
        bgColor: Color(0xFFFFF4EC),
        percent: 0.20,
        flex: 20,
      ),
      _BudgetCategory(
        key: 'activities',
        label: 'Activities',
        icon: Icons.forest,
        color: AppColors.primary,
        bgColor: Color(0xFFEAF7EF),
        percent: 0.18,
        flex: 18,
      ),
      _BudgetCategory(
        key: 'transport',
        label: 'Transport',
        icon: Icons.airport_shuttle,
        color: Color(0xFF6B7FD4),
        bgColor: Color(0xFFF0F2FF),
        percent: 0.17,
        flex: 17,
      ),
      _BudgetCategory(
        key: 'shopping',
        label: 'Shopping',
        icon: Icons.local_mall,
        color: Color(0xFFE91E8C),
        bgColor: Color(0xFFFFEAF5),
        percent: 0.10,
        flex: 10,
      ),
      _BudgetCategory(
        key: 'health',
        label: 'Health & Misc',
        icon: Icons.favorite_border,
        color: Color(0xFF9B59B6),
        bgColor: Color(0xFFF8ECFB),
        percent: 0.05,
        flex: 5,
      ),
    ];
  }
}

class _BudgetCategoryRow extends StatelessWidget {
  const _BudgetCategoryRow({
    required this.category,
    required this.amount,
    required this.total,
    required this.currency,
    required this.entries,
    required this.isExpanded,
    required this.onToggle,
    required this.onAddEntry,
    required this.onRemoveEntry,
    required this.onUpdateEntry,
  });

  final _BudgetCategory category;
  final double amount;
  final double total;
  final String currency;
  final List<_BudgetLocationEntry> entries;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAddEntry;
  final ValueChanged<String> onRemoveEntry;
  final void Function(String id, {String? name, String? price}) onUpdateEntry;

  @override
  Widget build(BuildContext context) {
    final hasAmount = total > 0 && amount > 0;
    final progress =
        hasAmount ? category.percent.clamp(0.0, 1.0).toDouble() : 0.0;

    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: category.bgColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(category.icon, color: category.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.foreground,
                                fontSize: 15,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (entries.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: category.bgColor,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${entries.length} item${entries.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: category.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            hasAmount
                                ? '${_currencySymbol(currency)}${_formatNumber(amount.round())}'
                                : '${_currencySymbol(currency)}--',
                            style: TextStyle(
                              color: hasAmount
                                  ? AppColors.foreground
                                  : const Color(0xFFC0C0C0),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 19,
                              color: Color(0xFFA0A0A0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: progress,
                          color: category.color,
                          backgroundColor: const Color(0xFFF0EDE9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(74, 0, 18, 14),
            child: Column(
              children: [
                ...entries.map((entry) {
                  return _BudgetLocationEntryCard(
                    category: category,
                    entry: entry,
                    onRemove: () => onRemoveEntry(entry.id),
                    onNameChanged: (value) =>
                        onUpdateEntry(entry.id, name: value),
                    onPriceChanged: (value) =>
                        onUpdateEntry(entry.id, price: value),
                  );
                }).toList(),
                _AddLocationButton(category: category, onTap: onAddEntry),
              ],
            ),
          ),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }
}

class _BudgetLocationEntry {
  const _BudgetLocationEntry({
    required this.id,
    this.name = '',
    this.price = '',
  });

  final String id;
  final String name;
  final String price;

  _BudgetLocationEntry copyWith({String? name, String? price}) {
    return _BudgetLocationEntry(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }
}

class _BudgetLocationEntryCard extends StatelessWidget {
  const _BudgetLocationEntryCard({
    required this.category,
    required this.entry,
    required this.onRemove,
    required this.onNameChanged,
    required this.onPriceChanged,
  });

  final _BudgetCategory category;
  final _BudgetLocationEntry entry;
  final VoidCallback onRemove;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onPriceChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: category.color.withOpacity(0.16), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 10),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    color: category.color, size: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: entry.name,
                    onChanged: onNameChanged,
                    decoration: const InputDecoration(
                      hintText: 'Location name...',
                      hintStyle: TextStyle(
                        color: Color(0xFF8A8A8A),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE8EF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFFE94F64),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: category.color.withOpacity(0.10)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
            child: Row(
              children: [
                Icon(Icons.attach_money, color: category.color, size: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: entry.price,
                    onChanged: onPriceChanged,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: Color(0xFFC8C8C8),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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

class _AddLocationButton extends StatelessWidget {
  const _AddLocationButton({required this.category, required this.onTap});

  final _BudgetCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: category.color.withOpacity(0.24),
          radius: 20,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFDFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.add, color: category.color, size: 20),
              const SizedBox(width: 12),
              Text(
                'Add location',
                style: TextStyle(
                  color: category.color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      const dash = 5.0;
      const gap = 4.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _BudgetTierButton extends StatelessWidget {
  const _BudgetTierButton({
    required this.emoji,
    required this.label,
    required this.sub,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final String sub;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: active ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : color.withOpacity(0.16),
            width: 1.4,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFF5A5A5A),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white70 : const Color(0xFFA0A0A0),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.active, required this.onSelected});

  final String active;
  final ValueChanged<String> onSelected;

  static const _items = [
    ['public', Icons.public, 'Public', 'Anyone can see', AppColors.primary],
    ['friends', Icons.group, 'Friends', 'Only followers', Color(0xFF5B9BD5)],
    ['private', Icons.lock, 'Private', 'Only you', Color(0xFF5B8DD9)],
  ];

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: _items.map((item) {
          final key = item[0] as String;
          final icon = item[1] as IconData;
          final label = item[2] as String;
          final sub = item[3] as String;
          final color = item[4] as Color;
          final selected = active == key;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => onSelected(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: selected ? color : color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? color : color.withOpacity(0.14),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(icon, color: selected ? Colors.white : color),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.white : AppColors.foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white70 : AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AiPlannerCard extends StatelessWidget {
  const _AiPlannerCard({
    required this.destination,
    required this.shown,
    required this.onGenerate,
  });

  final String destination;
  final bool shown;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final tips = destination.isEmpty
        ? const <String>[]
        : const <String>[
            'Book sunrise tours early',
            'Reserve restaurants 2 weeks ahead',
            'Download offline maps before you go',
          ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A2E1A),
            Color(0xFF1A5C38),
            AppColors.primary,
            AppColors.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2E1A).withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.auto_awesome,
                                color: Color(0xFFFFD700), size: 15),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'AI Suggestions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        destination.isEmpty
                            ? 'Add a destination to get personalized ideas'
                            : 'Generate smart tips for $destination',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    gradient: RadialGradient(
                      center: const Alignment(-0.4, -0.4),
                      colors: [
                        Colors.white.withOpacity(0.25),
                        AppColors.primary.withOpacity(0.10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: GestureDetector(
              onTap: destination.isEmpty ? null : onGenerate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt,
                        color: Color(0xFFFFD700), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      shown ? 'Regenerate Ideas' : 'Generate AI Ideas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (shown && tips.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.10)),
                ),
              ),
              child: Column(
                children: tips.map((tip) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tips_and_updates_outlined,
                            color: Color(0xFFFFD700), size: 17),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.enabled,
    required this.saving,
    required this.isEditing,
    required this.onTap,
  });

  final bool enabled;
  final bool saving;
  final bool isEditing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                )
              : null,
          color: enabled ? null : Colors.black.withOpacity(0.08),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.40),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (saving)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                isEditing ? Icons.check : Icons.auto_awesome,
                color: enabled ? const Color(0xFFFFD700) : Colors.black26,
                size: 18,
              ),
            const SizedBox(width: 10),
            Text(
              isEditing ? 'Save Trip' : 'Create Trip',
              style: TextStyle(
                color: enabled ? Colors.white : const Color(0xFFB0B0C0),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.screen,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: saving ? null : onCancel,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE8E4DF),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: enabled
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        )
                      : null,
                  color: enabled ? null : Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.40),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
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
                            Icon(
                              isEditing ? Icons.check : Icons.auto_awesome,
                              color: enabled
                                  ? const Color(0xFFFFD700)
                                  : const Color(0xFFC0C0C0),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Save Trip' : 'Create Trip',
                              style: TextStyle(
                                color: enabled
                                    ? Colors.white
                                    : const Color(0xFFC0C0C0),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
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

class _NeutralPill extends StatelessWidget {
  const _NeutralPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFFF6F6F4),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active ? AppColors.primary : const Color(0xFFE6E3DE),
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF5A5A5A),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ColorPill extends StatelessWidget {
  const _ColorPill({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : const Color(0xFFFAFAF8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color.withOpacity(0.35) : const Color(0xFFEFECE8),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 5),
              Icon(Icons.check, size: 12, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 62,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.14) : const Color(0xFFFAFAF8),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? color.withOpacity(0.35) : const Color(0xFFEFECE8),
            width: 1.6,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.foreground : const Color(0xFF6A6A6A),
                fontSize: 11,
                height: 1.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyRoundButton extends StatelessWidget {
  const _TinyRoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 13),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.foreground, size: 24),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 20),
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

String _currencySymbol(String currency) {
  if (currency == 'JPY') return '¥';
  if (currency == 'EUR') return '€';
  if (currency == 'GBP') return '£';
  if (currency == 'THB') return '฿';
  if (currency == 'SGD') return 'S\$';
  return '\$';
}

String _formatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final fromEnd = text.length - i;
    buffer.write(text[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
