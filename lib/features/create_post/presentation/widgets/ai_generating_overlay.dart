import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The step between picking "ให้ AI สร้างโพสจากรูป" on the photo-first
/// review screen and the composer actually filling in — covers the
/// composer while the assistant is still drafting, rather than leaving an
/// empty page to stare at. "ยกเลิก" hands straight to [onCancel], which
/// stops the generation the same way backing out of it already does.
class AiGeneratingOverlay extends StatelessWidget {
  const AiGeneratingOverlay({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEAFBF1),
                  Colors.white,
                  Color(0xFFF2EEFC),
                ],
              ),
            ),
          ),
          const _EdgeGradientBar(alignment: Alignment.topCenter),
          const _EdgeGradientBar(alignment: Alignment.bottomCenter),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  const _LoadingDots(),
                  const SizedBox(height: 22),
                  const Text(
                    'AI กำลังสร้างโพส',
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'กรุณารอสักครู่ เรากำลังสร้างโพสให้คุณ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 15),
                  ),
                  const Spacer(flex: 7),
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.black,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onCancel,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'ยกเลิก',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EdgeGradientBar extends StatelessWidget {
  const _EdgeGradientBar({required this.alignment});
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        height: 6,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppColors.postImportStart,
              AppColors.postImportMid,
              AppColors.postImportMid2,
              AppColors.postImportEnd,
            ],
          ),
        ),
      ),
    );
  }
}

/// Three dots that each take their turn swelling — a plain stand-in for a
/// "thinking" indicator, since there is no real progress fraction to show.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  static const _colors = [
    Color(0xFFFF7A59),
    Color(0xFFB07CF2),
    AppColors.postPurple,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _colors.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _Dot(color: _colors[i], phase: i / _colors.length, t: _controller.value),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.phase, required this.t});

  final Color color;
  final double phase;
  final double t;

  @override
  Widget build(BuildContext context) {
    final local = ((t - phase) % 1 + 1) % 1;
    final bump = (1 - (local - 0.5).abs() * 2).clamp(0.0, 1.0);
    return Transform.scale(
      scale: 0.65 + 0.45 * bump,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
