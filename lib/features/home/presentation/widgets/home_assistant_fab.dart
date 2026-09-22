import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/widgets/app_bottom_nav.dart';

/// The assistant button that floats over the Home feed (Figma 2281-47115).
///
/// White rather than tinted: the glyph carries its own coral-to-green
/// gradient, so a coloured ground would fight it.
class HomeAssistantFab extends StatelessWidget {
  const HomeAssistantFab({super.key, required this.onTap});

  final VoidCallback onTap;

  static const double size = 56;

  /// Clears the nav bar, and the bump the create button sits in.
  static double bottomOffsetOf(BuildContext context) =>
      AppBottomNav.heightOf(context) + 12;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'ผู้ช่วย PunGuide',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SvgPicture.asset(
            'assets/icons/ai_assistant.svg',
            width: 26,
            height: 29,
          ),
        ),
      ),
    );
  }
}
