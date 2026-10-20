import 'package:flutter/material.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../create_post/presentation/widgets/composer_sheet.dart';
import '../../../create_trip/domain/plan_labels.dart';
import '../../domain/puntok_clip.dart';
import '../providers/puntok_clip_stills.dart';

/// What the Activity sheet hands back on ตกลง.
@immutable
class PuntokActivities {
  const PuntokActivities({this.styles = const [], this.custom = const []});

  final List<TravelStyle> styles;

  /// Typed under "+ เพิ่ม".
  final List<String> custom;

  bool get isEmpty => styles.isEmpty && custom.isEmpty;
}

/// "Activity" — the same chips the plan wizard and the post composer use,
/// so a clip's activities mean what a plan's do. Null when dismissed.
Future<PuntokActivities?> showPuntokActivitySheet(
  BuildContext context,
  PuntokActivities current,
) {
  return showModalBottomSheet<PuntokActivities>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => _ActivitySheet(current: current),
  );
}

class _ActivitySheet extends StatefulWidget {
  const _ActivitySheet({required this.current});

  final PuntokActivities current;

  @override
  State<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends State<_ActivitySheet> {
  late final List<TravelStyle> _styles = [...widget.current.styles];
  late final List<String> _custom = [...widget.current.custom];

  Future<void> _addCustom() async {
    final added = await showDialog<String>(
      context: context,
      builder: (_) => const _AddActivityDialog(),
    );
    final value = added?.trim() ?? '';
    if (value.isEmpty || _custom.contains(value) || !mounted) return;
    setState(() => _custom.add(value));
  }

  @override
  Widget build(BuildContext context) {
    return ComposerSheet(
      title: 'Activity',
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final entry in styleByLabel.entries)
                    _ActivityChip(
                      label: entry.key,
                      icon: styleIcon(entry.value),
                      selected: _styles.contains(entry.value),
                      onTap: () => setState(() {
                        _styles.contains(entry.value)
                            ? _styles.remove(entry.value)
                            : _styles.add(entry.value);
                      }),
                    ),
                  for (final label in _custom)
                    _ActivityChip(
                      label: label,
                      icon: Icons.local_activity_outlined,
                      selected: true,
                      onTap: () => setState(() => _custom.remove(label)),
                    ),
                  _ActivityChip(
                    label: 'เพิ่ม',
                    icon: Icons.add,
                    selected: false,
                    outlined: true,
                    onTap: _addCustom,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(
                PuntokActivities(styles: _styles, custom: _custom),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.postShare,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'ตกลง',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final bool selected;

  /// "+ เพิ่ม", which is an action rather than a choice.
  final bool outlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected || outlined;
    return Material(
      color: selected ? AppColors.postPurpleWell : AppColors.screen,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: outlined
                  ? AppColors.postPurple
                  : selected
                      ? AppColors.postPurpleWell
                      : AppColors.chipBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: accent ? AppColors.postPurple : AppColors.muted),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: accent ? AppColors.postPurple : AppColors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owns its controller so the field survives the dialog's exit animation.
class _AddActivityDialog extends StatefulWidget {
  const _AddActivityDialog();

  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มกิจกรรม'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(hintText: 'เช่น ดำน้ำ'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
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

/// Who sees the clip. Null when dismissed.
Future<PuntokVisibility?> showPuntokVisibilitySheet(
  BuildContext context,
  PuntokVisibility current,
) {
  return showModalBottomSheet<PuntokVisibility>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (sheetContext) => ComposerSheet(
      title: 'การมองเห็นโพส',
      onClose: () => Navigator.of(sheetContext).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in PuntokVisibility.values)
            ListTile(
              onTap: () => Navigator.of(sheetContext).pop(option),
              contentPadding: EdgeInsets.zero,
              leading: Icon(option.icon, size: 21, color: AppColors.foreground),
              title: Text(
                option.label,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: option == current
                  ? const Icon(Icons.check_circle,
                      size: 20, color: AppColors.postPurple)
                  : null,
            ),
        ],
      ),
    ),
  );
}

/// "Edit cover" — which of the picked clips fronts the post. Null when
/// dismissed.
Future<PuntokClip?> showPuntokCoverSheet(
  BuildContext context, {
  required List<PuntokClip> clips,
  required PuntokClip current,
}) {
  return showModalBottomSheet<PuntokClip>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (sheetContext) => ComposerSheet(
      title: 'เลือกปก',
      onClose: () => Navigator.of(sheetContext).pop(),
      child: SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: clips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final clip = clips[index];
            final chosen = clip == current;
            return Semantics(
              button: true,
              selected: chosen,
              label: 'ปกที่ ${index + 1}',
              child: GestureDetector(
                onTap: () => Navigator.of(sheetContext).pop(clip),
                child: Container(
                  width: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: chosen ? AppColors.postPurple : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: PuntokClipStill(clip: clip),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
