import 'package:flutter/material.dart';

import 'filter_chrome.dart';

/// สไตล์เที่ยวของฉัน — the same two chip walls the create wizard collects a
/// brief with, asked here as a filter instead.
///
/// The labels are shared with `plan_labels.dart`, so a chip tapped here names
/// the same [TravelStyle] the feed's tags were written from.
class FilterStyleStep extends StatelessWidget {
  const FilterStyleStep({
    super.key,
    required this.styles,
    required this.constraints,
    required this.onStyleTapped,
    required this.onConstraintTapped,
    this.onAddMore,
  });

  final List<String> styles;
  final List<String> constraints;
  final ValueChanged<String> onStyleTapped;
  final ValueChanged<String> onConstraintTapped;

  /// "+ เพิ่ม". The design shows the chip but defines nothing behind it, so it
  /// is inert until that flow exists — same as the create wizard's.
  final VoidCallback? onAddMore;

  /// Icons match the create wizard's chips one for one, so the same style
  /// reads the same on both screens.
  static const styleChips = <(String, IconData)>[
    ('ทะเล', Icons.beach_access_outlined),
    ('ภูเขา', Icons.terrain_outlined),
    ('ธรรมชาติ', Icons.eco_outlined),
    ('คาเฟ่', Icons.coffee_outlined),
    ('เข้าถึงท้องถิ่น', Icons.storefront_outlined),
    ('วัฒนธรรม', Icons.museum_outlined),
    ('อาหาร', Icons.restaurant_outlined),
    ('ไนท์ไลฟ์', Icons.local_bar_outlined),
    ('ช้อปปิ้ง', Icons.shopping_bag_outlined),
    ('ผจญภัย', Icons.hiking_outlined),
  ];

  /// No icons on these, as the design draws them.
  static const constraintChips = <String>[
    'มีผู้สูงอายุ',
    'เดินเยอะไม่ได้',
    'ผู้ใช้รถเข็น',
    'อิสลาม',
    'มังสวิรัติ',
    'มีเด็กเล็ก',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final chip in styleChips)
              FilterAnswerChip(
                label: chip.$1,
                icon: chip.$2,
                active: styles.contains(chip.$1),
                onTap: () => onStyleTapped(chip.$1),
              ),
            _AddChip(onTap: onAddMore),
          ],
        ),
        const SizedBox(height: 26),
        const FilterGroupLabel(label: 'เงื่อนไข / ข้อจำกัด'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final label in constraintChips)
              FilterAnswerChip(
                label: label,
                active: constraints.contains(label),
                onTap: () => onConstraintTapped(label),
              ),
            _AddChip(onTap: onAddMore),
          ],
        ),
      ],
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilterAnswerChip(
      label: '+ เพิ่ม',
      active: false,
      outlined: true,
      onTap: onTap ?? () {},
    );
  }
}
