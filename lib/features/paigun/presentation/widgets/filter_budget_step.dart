import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/trip_filter.dart';
import 'filter_chrome.dart';

/// งบเที่ยวของฉัน — an exact figure, or one of the four brackets.
///
/// The figure wins when both are set, the same way ระบุเอง overrides a bracket
/// in the create wizard.
class FilterBudgetStep extends StatelessWidget {
  const FilterBudgetStep({
    super.key,
    required this.amount,
    required this.scope,
    required this.onScopeChanged,
    required this.tier,
    required this.onTierChanged,
  });

  /// Owned by the screen so the typed figure survives stepping away and back.
  final TextEditingController amount;
  final BudgetScope scope;
  final ValueChanged<BudgetScope> onScopeChanged;
  final BudgetTier? tier;
  final ValueChanged<BudgetTier> onTierChanged;

  /// The brackets, labelled as the design writes them rather than off
  /// [BudgetTier]'s own bounds — the copy rounds where the enum does not.
  static const brackets = <(BudgetTier, String, String)>[
    (BudgetTier.economy, 'Economy', '< 1,000฿'),
    (BudgetTier.comfort, 'Comfort', '฿1,001 - ฿5,000'),
    (BudgetTier.premium, 'Premium', '฿5,001 - ฿10,000'),
    (BudgetTier.luxury, 'Luxury', '฿11,000+'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FilterGroupLabel(label: 'ตั้งงบเอง'),
        const SizedBox(height: 12),
        _AmountField(
          controller: amount,
          scope: scope,
          onScopeChanged: onScopeChanged,
        ),
        const SizedBox(height: 18),
        for (final bracket in brackets) ...[
          _BracketCard(
            title: bracket.$2,
            subtitle: bracket.$3,
            active: tier == bracket.$1,
            onTap: () => onTierChanged(bracket.$1),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.scope,
    required this.onScopeChanged,
  });

  final TextEditingController controller;
  final BudgetScope scope;
  final ValueChanged<BudgetScope> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        children: [
          const Text(
            '฿',
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 18,
              ),
              decoration: const InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: AppColors.postFieldHint,
                  fontSize: 18,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          _ScopeMenu(scope: scope, onChanged: onScopeChanged),
        ],
      ),
    );
  }
}

/// ต่อคน / รวมทุกคน — what the figure beside it means.
class _ScopeMenu extends StatelessWidget {
  const _ScopeMenu({required this.scope, required this.onChanged});

  final BudgetScope scope;
  final ValueChanged<BudgetScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BudgetScope>(
      onSelected: onChanged,
      initialValue: scope,
      tooltip: 'ขอบเขตของงบ',
      offset: const Offset(0, 46),
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      itemBuilder: (context) => [
        for (final option in BudgetScope.values)
          PopupMenuItem<BudgetScope>(
            value: option,
            height: 46,
            padding: EdgeInsets.zero,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: option == scope
                    ? AppColors.filterSelected
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                option.label,
                style: TextStyle(
                  color: option == scope
                      ? AppColors.filterSelectedText
                      : AppColors.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              scope.label,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: AppColors.foreground,
            ),
          ],
        ),
      ),
    );
  }
}

class _BracketCard extends StatelessWidget {
  const _BracketCard({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        active ? AppColors.filterSelectedText : AppColors.foreground;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: BoxDecoration(
          color: active ? AppColors.filterSelected : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.filterSelected : AppColors.chipBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: foreground,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: active ? AppColors.filterSelectedText : AppColors.muted,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
