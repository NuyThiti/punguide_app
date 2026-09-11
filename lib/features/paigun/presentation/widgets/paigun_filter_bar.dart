import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/paigun_providers.dart';

/// ทั้งหมด / Near Me / Top PunGuide, the chip in force filled dark.
class PaigunFilterBar extends StatelessWidget {
  const PaigunFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final PaigunFilter selected;
  final ValueChanged<PaigunFilter> onSelected;

  static const _icons = <PaigunFilter, IconData>{
    PaigunFilter.nearMe: Icons.near_me_outlined,
    PaigunFilter.topPunGuide: Icons.shuffle,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: PaigunFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = PaigunFilter.values[index];
          return _FilterChip(
            label: filter.label,
            icon: _icons[filter],
            active: filter == selected,
            onTap: () => onSelected(filter),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Near Me" / "Top PunGuide" heading over a wall of cards.
class PaigunSectionHeader extends StatelessWidget {
  const PaigunSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
