import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The spot/page row pinned above the bottom action bar: one numbered circle
/// per spot — "① ② ③" — the current one filled in the composer's own purple,
/// plus the manage icon that opens the reorder sheet.
///
/// Only ever shown once there is more than one spot to page between; a single
/// spot has nothing to paginate.
class TripSpotPagination extends StatelessWidget {
  const TripSpotPagination({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.onSelect,
    required this.onManage,
  });

  final int count;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _SpotDot(
                    number: i + 1,
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _ManageButton(onTap: onManage),
      ],
    );
  }
}

class _SpotDot extends StatelessWidget {
  const _SpotDot({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.postPurple : AppColors.postPurpleSoft,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: selected ? Colors.white : AppColors.postPurple,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens "จัดเรียงลำดับหัวข้อ" — the reorder/delete sheet.
class _ManageButton extends StatelessWidget {
  const _ManageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'จัดเรียงลำดับหัวข้อ',
      child: Material(
        color: AppColors.postPurpleSoft,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 32,
            height: 32,
            child: Icon(Icons.reorder, size: 18, color: AppColors.postPurple),
          ),
        ),
      ),
    );
  }
}
