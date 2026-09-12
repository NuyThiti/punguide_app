import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'filter_chrome.dart';

/// จำนวนคน — two counters, each with the shortcut chips beside the sizes
/// people actually travel in.
class FilterPeopleStep extends StatelessWidget {
  const FilterPeopleStep({
    super.key,
    required this.adults,
    required this.children,
    required this.onAdultsChanged,
    required this.onChildrenChanged,
  });

  final int adults;
  final int children;
  final ValueChanged<int> onAdultsChanged;
  final ValueChanged<int> onChildrenChanged;

  /// The counts the chips offer. Past five the steps get coarse — nobody taps
  /// "+" seventeen times.
  static const presets = <int>[1, 2, 3, 4, 5, 10, 15, 20, 30];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CountGroup(
          title: 'ผู้ใหญ่',
          subtitle: 'อายุ 18 ปีขึ้นไป',
          value: adults,
          // Once there is a group at all it has at least one adult in it;
          // clearing the step is what the action bar's ล้างที่เลือก is for.
          minimum: 0,
          onChanged: onAdultsChanged,
        ),
        const SizedBox(height: 26),
        _CountGroup(
          title: 'เด็ก',
          subtitle: 'อายุ 0-17 ปี',
          value: children,
          minimum: 0,
          onChanged: onChildrenChanged,
        ),
      ],
    );
  }
}

class _CountGroup extends StatelessWidget {
  const _CountGroup({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.minimum,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int value;
  final int minimum;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            _StepperButton(
              icon: Icons.remove,
              filled: false,
              enabled: value > minimum,
              onTap: () => onChanged(value - 1),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: value > 0 ? AppColors.foreground : AppColors.muted,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _StepperButton(
              icon: Icons.add,
              filled: true,
              enabled: true,
              onTap: () => onChanged(value + 1),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: AppColors.filterDivider),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final preset in FilterPeopleStep.presets)
              FilterAnswerChip(
                label: '$preset คน',
                active: value == preset,
                // Tapping the count already showing puts the counter back to
                // nothing, so a chip can be undone where it was made.
                onTap: () => onChanged(value == preset ? 0 : preset),
              ),
          ],
        ),
      ],
    );
  }
}

/// − is an outlined disc, + a solid dark one, as the design pairs them.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled
          ? (enabled ? AppColors.paigunControl : AppColors.postActionIdle)
          : Colors.white,
      shape: CircleBorder(
        side: filled
            ? BorderSide.none
            : BorderSide(
                color: enabled ? AppColors.chipBorder : AppColors.line,
              ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: filled
                ? Colors.white
                : enabled
                    ? AppColors.foreground
                    : const Color(0xFFC9C4BC),
          ),
        ),
      ),
    );
  }
}
