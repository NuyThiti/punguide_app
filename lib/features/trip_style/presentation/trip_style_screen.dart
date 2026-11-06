import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../create_trip/domain/plan_labels.dart';
import '../../paigun/presentation/providers/paigun_providers.dart';
import '../../paigun/presentation/widgets/filter_sheet_parts.dart';
import '../domain/trip_style_preference.dart';
import 'providers/trip_style_providers.dart';
import 'widgets/trip_style_foot.dart';
import 'widgets/trip_style_header.dart';

/// สไตล์เที่ยวของฉัน — the last question of the launch sequence.
///
/// Asked once, after Location Access and before Home, and answered into
/// preferences rather than the account because no endpoint holds it yet. From
/// then on the answer rides along on every ไปกัน request as `styles` and
/// `constraints`, which is the whole reason for asking.
///
/// ข้ามไปก่อน is an answer too — it saves an empty preference, so the page
/// does not reappear on the next run.
class TripStyleScreen extends ConsumerStatefulWidget {
  const TripStyleScreen({super.key, this.then});

  /// Where to go once answered. Defaults to Home, which is where the launch
  /// sequence ends.
  final String? then;

  /// The order the design lays the style chips out in, which is neither the
  /// order [styleByLabel] declares them nor the order the ตัวกรอง sheet uses.
  static const styleOrder = <String>[
    'ทะเล',
    'ภูเขา',
    'ธรรมชาติ',
    'คาเฟ่',
    'เข้าถึงท้องถิ่น',
    'วัฒนธรรม',
    'อาหาร',
    'ไนท์ไลฟ์',
    'ช้อปปิ้ง',
    'ผจญภัย',
  ];

  /// Six chips, of which only four have an enum — อิสลาม and มังสวิรัติ are
  /// dietary and travel as free text. See [constraintByLabel].
  static const constraintOrder = <String>[
    'มีผู้สูงอายุ',
    'เดินเยอะไม่ได้',
    'ผู้ใช้รถเข็น',
    'อิสลาม',
    'มังสวิรัติ',
    'มีเด็กเล็ก',
  ];

  @override
  ConsumerState<TripStyleScreen> createState() => _TripStyleScreenState();
}

class _TripStyleScreenState extends ConsumerState<TripStyleScreen> {
  /// Starts from whatever was answered last time, so reopening the page shows
  /// the chips already in force rather than a blank sheet.
  late TripStylePreference _draft =
      ref.read(tripStyleProvider) ?? TripStylePreference.skipped;

  /// Chips the traveller typed themselves, kept apart from the design's own so
  /// the two lists below stay in the order the comp draws them.
  late List<String> _customStyles = _extra(
    _draft.styles,
    TripStyleScreen.styleOrder,
  );
  late List<String> _customConstraints = _extra(
    _draft.constraints,
    TripStyleScreen.constraintOrder,
  );

  static List<String> _extra(List<String> chosen, List<String> known) =>
      chosen.where((label) => !known.contains(label)).toList();

  @override
  Widget build(BuildContext context) {
    return AppFrame(
      background: AppColors.screen,
      child: Column(
        children: [
          TripStyleHeader(
            onBack: _back,
            // Login, Location Access, then this.
            step: 3,
            stepCount: 3,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              physics: const BouncingScrollPhysics(),
              children: [
                const SizedBox(height: 14),
                const Text(
                  'สไตล์เที่ยวของฉัน',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _ChipWrap(
                  labels: [
                    ...TripStyleScreen.styleOrder,
                    ..._customStyles,
                  ],
                  chosen: _draft.styles,
                  glyph: _styleGlyph,
                  onTapped: (label) =>
                      setState(() => _draft = _draft.toggleStyle(label)),
                  onAddMore: () => _addChip(isStyle: true),
                ),
                const SizedBox(height: 26),
                const Text(
                  'เงื่อนไข / ข้อจำกัด',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _ChipWrap(
                  labels: [
                    ...TripStyleScreen.constraintOrder,
                    ..._customConstraints,
                  ],
                  chosen: _draft.constraints,
                  onTapped: (label) =>
                      setState(() => _draft = _draft.toggleConstraint(label)),
                  onAddMore: () => _addChip(isStyle: false),
                ),
              ],
            ),
          ),
          TripStyleFoot(
            chosenCount: _draft.count,
            onClear: () => setState(() => _draft = TripStylePreference.skipped),
            onContinue: () => _finish(_draft),
            // Waved away, not answered empty by accident — but stored all the
            // same, so the launch sequence stops asking.
            onSkip: () => _finish(TripStylePreference.skipped),
          ),
        ],
      ),
    );
  }

  /// One SVG per style, named for the wire value so the two cannot drift.
  ///
  /// A chip the traveller typed has no glyph by definition, and ผจญภัย has no
  /// asset either — the artwork handed over for it is the compass's outer ring
  /// with no needle, which reads as a plain circle. Same fallback the ตัวกรอง
  /// sheet uses.
  Widget? _styleGlyph(String label, Color color) {
    final style = styleByLabel[label];
    if (style == null) return null;
    if (style == TravelStyle.adventure) {
      return Icon(Icons.explore_outlined, size: 17, color: color);
    }
    return SvgPicture.asset(
      'assets/icons/styles/${style.wire}.svg',
      width: 17,
      height: 17,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  Future<void> _addChip({required bool isStyle}) async {
    final label = await showDialog<String>(
      context: context,
      builder: (_) => _AddChipDialog(isStyle: isStyle),
    );
    final trimmed = label?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;

    setState(() {
      if (isStyle) {
        if (!_customStyles.contains(trimmed) &&
            !TripStyleScreen.styleOrder.contains(trimmed)) {
          _customStyles = [..._customStyles, trimmed];
        }
        if (!_draft.styles.contains(trimmed)) {
          _draft = _draft.toggleStyle(trimmed);
        }
      } else {
        if (!_customConstraints.contains(trimmed) &&
            !TripStyleScreen.constraintOrder.contains(trimmed)) {
          _customConstraints = [..._customConstraints, trimmed];
        }
        if (!_draft.constraints.contains(trimmed)) {
          _draft = _draft.toggleConstraint(trimmed);
        }
      }
    });
  }

  Future<void> _finish(TripStylePreference preference) async {
    await ref.read(tripStyleProvider.notifier).save(preference);
    if (!mounted) return;

    // The board reads its filter from a provider seeded at startup, so this
    // run has to be told directly — same as the map picker does with the
    // origin it confirms.
    ref.read(tripFilterProvider.notifier).state =
        ref.read(tripFilterProvider).copyWith(
              styles: preference.styles,
              constraints: preference.constraints,
            );

    if (!mounted) return;
    context.go(widget.then ?? '/');
  }

  /// Reached as the last step of the launch sequence, where there is nothing
  /// to pop back to.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }
}

/// A row of chips plus the "+ เพิ่ม" that grows it.
class _ChipWrap extends StatelessWidget {
  const _ChipWrap({
    required this.labels,
    required this.chosen,
    required this.onTapped,
    required this.onAddMore,
    this.glyph,
  });

  final List<String> labels;
  final List<String> chosen;
  final ValueChanged<String> onTapped;
  final VoidCallback onAddMore;
  final Widget? Function(String label, Color color)? glyph;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final label in labels)
          FilterPillChip(
            label: label,
            selected: chosen.contains(label),
            onTap: () => onTapped(label),
            icon: glyph == null
                ? null
                : (color) => glyph!(label, color) ?? const SizedBox.shrink(),
          ),
        FilterPillChip(
          label: '+ เพิ่ม',
          selected: false,
          outlined: true,
          onTap: onAddMore,
        ),
      ],
    );
  }
}

/// "+ เพิ่ม" — a chip the traveller names themselves.
///
/// These have no enum behind them, which is exactly why they are kept: a
/// free-text answer rides up as `customStyles` / `customConstraints` rather
/// than being thrown away at the chip.
class _AddChipDialog extends StatefulWidget {
  const _AddChipDialog({required this.isStyle});

  final bool isStyle;

  @override
  State<_AddChipDialog> createState() => _AddChipDialogState();
}

class _AddChipDialogState extends State<_AddChipDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.screen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.isStyle ? 'เพิ่มสไตล์เที่ยว' : 'เพิ่มเงื่อนไข',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
        decoration: InputDecoration(
          hintText: widget.isStyle ? 'เช่น ดำน้ำ' : 'เช่น แพ้อาหารทะเล',
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('เพิ่ม'),
        ),
      ],
    );
  }
}
