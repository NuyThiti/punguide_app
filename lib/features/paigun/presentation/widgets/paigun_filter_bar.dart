import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/paigun_providers.dart';

/// ทั้งหมด / คู่มือ / แผนทริป / Top PunGuide, the chip in force filled dark,
/// with ตัวกรอง parked at the head of the row (Figma 2480-67909).
///
/// The wizard button rides in the same row rather than up in the header: it
/// narrows the very wall these chips do, and the header is now the location
/// and the search box.
class PaigunFilterBar extends StatelessWidget {
  const PaigunFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onTune,
    this.filterCount = 0,
  });

  final PaigunFilter selected;
  final ValueChanged<PaigunFilter> onSelected;

  /// Opens ตัวกรอง.
  final VoidCallback onTune;

  /// How many of the wizard's questions are currently narrowing the board.
  /// Zero hides the badge, so an unfiltered board looks untouched.
  final int filterCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Center(child: _TuneButton(count: filterCount, onTap: onTune)),
          for (final filter in PaigunFilter.values) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: filter.label,
              active: filter == selected,
              onTap: () => onSelected(filter),
            ),
          ],
        ],
      ),
    );
  }
}

/// The round ตัวกรอง control, badged with how many answers are in force.
class _TuneButton extends StatelessWidget {
  const _TuneButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'ตัวกรอง',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.chipBorder),
              ),
              child: const Icon(
                Icons.tune,
                size: 19,
                color: AppColors.foreground,
              ),
            ),
            if (count > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.filterAction,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : AppColors.foreground;

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.paigunControl : Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: active ? AppColors.paigunControl : AppColors.chipBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
