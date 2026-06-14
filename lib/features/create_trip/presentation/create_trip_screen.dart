import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
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

  int? _coverIndex;
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

  bool get _isEditing => widget.trip != null;
  bool get _canCreate => _destinationController.text.trim().isNotEmpty;

  double get _budget => double.tryParse(_budgetController.text.trim()) ?? 0;
  double get _displayBudget => _perPerson ? _budget * _travelers : _budget;
  int get _duration => int.tryParse(_durationController.text.trim()) ?? 0;

  static const _coverImages = <String>[
    'https://images.unsplash.com/photo-1603477849227-705c424d1d80?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080',
    'https://images.unsplash.com/photo-1589182373726-e4f658ab50f0?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080',
    'https://images.unsplash.com/photo-1535262412227-85541e910204?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080',
    'https://images.unsplash.com/photo-1668428202528-bf3d5ed88560?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080',
  ];

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
    _coverImageController = TextEditingController(
      text: trip?.coverImage ?? AppConstants.defaultCoverImage,
    );
    _coverIndex = trip == null ? null : 0;
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
      backgroundColor: AppColors.softScreen,
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final framed = constraints.maxWidth > 430;
            return Container(
              width: constraints.maxWidth < 430 ? constraints.maxWidth : 430,
              height: framed && constraints.maxHeight > 932
                  ? 932
                  : constraints.maxHeight,
              color: AppColors.softScreen,
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
                          coverIndex: _coverIndex,
                          coverImages: _coverImages,
                          onBack: _close,
                          onChangeCover: _cycleCover,
                        ),
                        Container(
                          color: AppColors.softScreen,
                          child: Column(
                            children: [
                              _SheetSection(
                                topPadding: 4,
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

  void _cycleCover() {
    setState(() {
      _coverIndex = _coverIndex == null ? 0 : (_coverIndex! + 1) % _coverImages.length;
      _coverImageController.text = _coverImages[_coverIndex!];
    });
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
    required this.coverIndex,
    required this.coverImages,
    required this.onBack,
    required this.onChangeCover,
  });

  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final int duration;
  final int? coverIndex;
  final List<String> coverImages;
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
            if (coverIndex == null)
              const _EmptyCover()
            else
              Image.network(coverImages[coverIndex!], fit: BoxFit.cover),
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
                    if (coverIndex != null)
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
              bottom: 50,
              child: destination.isEmpty
                  ? Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 15, color: Colors.white.withOpacity(0.72)),
                        const SizedBox(width: 6),
                        Text(
                          'Choose a destination below',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.76),
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
            if (coverIndex != null)
              Positioned(
                right: 20,
                bottom: 54,
                child: Row(
                  children: List.generate(
                    coverImages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == coverIndex ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(left: 5),
                      decoration: BoxDecoration(
                        color: index == coverIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.42),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
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
    required this.coverIndex,
    required this.coverImages,
    required this.onBack,
    required this.onChangeCover,
  });

  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final int duration;
  final int? coverIndex;
  final List<String> coverImages;
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
            coverIndex: coverIndex,
            coverImages: coverImages,
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.softScreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SizedBox(height: 24),
    );
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
    this.topPadding = 20,
    this.hasBorder = true,
  });

  final Widget child;
  final double topPadding;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 20),
      decoration: BoxDecoration(
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
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
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
          GestureDetector(
            onTap: onPickStart,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.07)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Pick dates',
                    style: TextStyle(
                      color: AppColors.primary,
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

  static const _vibes = [
    ['Beach', '🏖️', Color(0xFF0288D1)],
    ['Hiking', '🥾', Color(0xFF2E7D32)],
    ['Food Tour', '🍜', AppColors.accent],
    ['Culture', '🏛️', Color(0xFF8B6BAE)],
    ['Shopping', '🛍️', Color(0xFFE91E8C)],
    ['Nightlife', '🌃', Color(0xFF1565C0)],
    ['Arts', '🎭', Color(0xFF9B59B6)],
    ['Adventure', '🪂', AppColors.accent],
    ['Wellness', '💆', Color(0xFF2A9E64)],
    ['Photography', '📸', Color(0xFF5B8DD9)],
    ['Surfing', '🏄', Color(0xFF0097A7)],
    ['Wildlife', '🦁', Color(0xFF795548)],
  ];

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _vibes.map((item) {
          final label = item[0] as String;
          final emoji = item[1] as String;
          final color = item[2] as Color;
          final active = selected.contains(label);
          return _ColorPill(
            label: '$emoji $label',
            active: active,
            color: color,
            onTap: () => onToggle(label),
          );
        }).toList(),
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
        color: AppColors.softScreen,
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
          color: active ? AppColors.foreground : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active ? AppColors.foreground : Colors.black.withOpacity(0.08),
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
          color: active ? color : color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : color.withOpacity(0.18),
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 5),
              const Icon(Icons.check, size: 12, color: Colors.white),
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
          color: selected ? color : color.withOpacity(0.055),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.18),
            width: 1.6,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : color, size: 21),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : color,
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
