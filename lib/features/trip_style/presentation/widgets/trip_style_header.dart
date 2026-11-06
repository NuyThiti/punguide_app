import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';

/// The band across the top of สไตล์เที่ยวของฉัน: the illustration, the way
/// back, and how far through the launch sequence the traveller is.
class TripStyleHeader extends StatelessWidget {
  const TripStyleHeader({
    super.key,
    required this.onBack,
    required this.step,
    required this.stepCount,
  });

  /// The design calls for its own forest-and-temple artwork, which has not
  /// been handed over. Home's photo stands in so the band is not a flat
  /// rectangle — swap the asset when the real one arrives.
  static const String coverAsset = 'assets/images/home_hero.jpg';

  final VoidCallback onBack;

  /// Which question this is, counting from one.
  final int step;

  /// How many the launch sequence asks in total. Driven by the real flow
  /// rather than the five marks the comp happens to show, which belong to a
  /// longer onboarding than the app has.
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: topInset + 100,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CoverImage(
            source: coverAsset,
            fit: BoxFit.cover,
            alignment: Alignment(0, -0.45),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, topInset + 10, 18, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackButton(onTap: onBack),
                const Spacer(),
                _StepDots(step: step, stepCount: stepCount),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'ย้อนกลับ',
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.screen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.chevron_left, size: 26),
        ),
      ),
    );
  }
}

/// Dots for the questions behind, a pill for the one on screen, and a pale
/// dot for each one still to come.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.stepCount});

  final int step;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= stepCount; i++) ...[
            if (i > 1) const SizedBox(width: 6),
            Container(
              width: i == step ? 26 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= step
                    ? AppColors.filterAction
                    : AppColors.filterActionSoft,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
