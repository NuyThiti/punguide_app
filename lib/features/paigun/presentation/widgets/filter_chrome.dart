import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';

/// The cap of every filter step: the illustration, the way back, and how far
/// through the wizard the traveller is.
///
/// Short on purpose — the questions below it are long, and the artwork is
/// scenery rather than a hero. The back button is a solid white disc here, not
/// ไปกัน's translucent one, because it sits on the pale top of the image.
class FilterHero extends StatelessWidget {
  const FilterHero({
    super.key,
    required this.step,
    required this.total,
    required this.onBack,
    this.coverImage = coverAsset,
  });

  /// The same photo Home, ไปกัน and Location Access put behind their heroes.
  static const String coverAsset = 'assets/images/home_hero.jpg';

  /// 0-based.
  final int step;
  final int total;
  final VoidCallback onBack;
  final String coverImage;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: topInset + 116,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CoverImage(
            source: coverImage,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackDisc(onTap: onBack),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(top: 13),
                  child: FilterStepDots(step: step, total: total),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A dot per question: filled for one already answered, a stretched pill for
/// the one on screen, and pale for one still ahead.
class FilterStepDots extends StatelessWidget {
  const FilterStepDots({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == step ? 34 : 9,
            height: 9,
            decoration: BoxDecoration(
              color:
                  i <= step ? AppColors.filterAction : AppColors.filterStepIdle,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ],
    );
  }
}

class _BackDisc extends StatelessWidget {
  const _BackDisc({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.chevron_left,
          size: 26,
          color: AppColors.foreground,
        ),
      ),
    );
  }
}

/// The step's question, set large over the answers.
class FilterStepTitle extends StatelessWidget {
  const FilterStepTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.foreground,
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
    );
  }
}

/// A small bold heading over a group of chips — จำนวนวันยอดนิยม, ตั้งงบเอง,
/// เงื่อนไข / ข้อจำกัด.
class FilterGroupLabel extends StatelessWidget {
  const FilterGroupLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.foreground,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// The rounded chip every answer on this wizard is made of: outlined while
/// untouched, peach once chosen.
class FilterAnswerChip extends StatelessWidget {
  const FilterAnswerChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  /// "+ เพิ่ม", which wears the coral outline whether or not anything is
  /// selected.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final foreground = active || outlined
        ? AppColors.filterSelectedText
        : AppColors.foreground;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: active ? AppColors.filterSelected : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active
                ? AppColors.filterSelected
                : outlined
                    ? AppColors.filterSelectedText
                    : AppColors.chipBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The panel pinned to the bottom of every step: what has been chosen so far,
/// the way to undo it, and the way on.
class FilterActionBar extends StatelessWidget {
  const FilterActionBar({
    super.key,
    required this.summary,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onClear,
    required this.onSkip,
  });

  /// What this step has collected, read back in the design's own words. Null
  /// while the step is untouched, which also hides ล้างที่เลือก.
  final String? summary;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onClear;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    // The inset belongs in the panel's own padding: a SafeArea around it would
    // lift the white sheet off the bottom edge and leave a strip of the page
    // showing beneath.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 10 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (summary != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onClear,
                  child: const Text(
                    'ล้างที่เลือก',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          GestureDetector(
            onTap: onPrimary,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.filterAction,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                primaryLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.muted,
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text(
              'ข้ามไปก่อน',
              style: TextStyle(
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
