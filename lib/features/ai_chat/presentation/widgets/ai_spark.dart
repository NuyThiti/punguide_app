import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The assistant's mark: a square stood on its corner, washed in the spark
/// gradient.
///
/// One widget for both places the design uses it — the 28px avatar beside an
/// assistant bubble, and the soft 120px lantern the empty state hangs over its
/// greeting. [blur] is what separates them: at zero the diamond has an edge,
/// and at the empty state's radius it is only colour.
class AiSpark extends StatelessWidget {
  const AiSpark({super.key, required this.size, this.blur = 0});

  final double size;

  /// Sigma of the blur laid over the diamond. The empty state uses a sixth of
  /// [size], which is enough to lose the corners entirely.
  final double blur;

  @override
  Widget build(BuildContext context) {
    // The rotation pushes the corners out past the square, so the box has to
    // be the diagonal or the tips clip.
    final box = size * 1.42;

    Widget diamond = Center(
      child: Transform.rotate(
        angle: 45 * 3.1415926535 / 180,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.16),
            gradient: const LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [
                AppColors.aiSparkEnd,
                AppColors.aiSparkMid,
                AppColors.aiSparkStart,
              ],
            ),
          ),
        ),
      ),
    );

    if (blur > 0) {
      diamond = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: diamond,
      );
    }

    return SizedBox(width: box, height: box, child: diamond);
  }
}
