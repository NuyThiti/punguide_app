import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The round back disc every step of the flow opens with. Dark and
/// translucent, so it reads the same over the white steps and over footage.
class PuntokBackDisc extends StatelessWidget {
  const PuntokBackDisc({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'ย้อนกลับ',
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.chevron_left, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

/// Back disc on the left, the step's name centred over the whole width.
class PuntokStepHeader extends StatelessWidget {
  const PuntokStepHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Positioned(left: 16, child: PuntokBackDisc(onTap: onBack)),
        ],
      ),
    );
  }
}

/// The pinned pair at the foot of the editor and the composer: keep it for
/// later, or move on.
class PuntokActionBar extends StatelessWidget {
  const PuntokActionBar({
    super.key,
    required this.onSaveDraft,
    required this.primaryLabel,
    required this.onPrimary,
    required this.primaryColor,
    this.decorated = true,
  });

  final VoidCallback onSaveDraft;
  final String primaryLabel;

  /// Null greys the action out rather than hiding it.
  final VoidCallback? onPrimary;
  final Color primaryColor;

  /// Off inside the editor's sheet, which already supplies the white.
  final bool decorated;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: onSaveDraft,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.postDraftBg,
                foregroundColor: AppColors.foreground,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Save Draft',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.postPurpleSoft,
                disabledForegroundColor: AppColors.postPurple,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                primaryLabel,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );

    if (!decorated) return row;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: row,
    );
  }
}

/// A pill drawn with a dashed outline — the design's "add something here"
/// affordance for Activity and Tag Friend.
class DashedPill extends StatelessWidget {
  const DashedPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        painter: const _DashedRRectPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.postPurple),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB9B4AE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(12),
      ));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) => false;
}
