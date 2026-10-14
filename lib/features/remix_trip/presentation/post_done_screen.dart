import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

/// Why this page is showing — each reads the same layout with its own
/// subtitle.
enum PostDoneReason {
  /// Straight out of the composer, this post's own first publish.
  published('บันทึกโพสต์เรียบร้อยแล้ว'),

  /// A remix just copied someone else's plan into one of the traveller's own.
  remix('Remix ลงทริปของคุณสำเร็จแล้ว');

  const PostDoneReason(this.subtitle);

  final String subtitle;
}

/// "PunGuide Done!" — the page a post or a remix lands on right after it
/// succeeds, before handing the traveller off to what it just created.
/// Figma 2616-46598.
class PostDoneScreen extends StatelessWidget {
  const PostDoneScreen({
    super.key,
    required this.tripId,
    this.reason = PostDoneReason.published,
  });

  /// The trip the post or remix just created — "ดูทริปของฉัน" opens it for
  /// editing.
  final String tripId;

  final PostDoneReason reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const _DoneHero(),
              const SizedBox(height: 28),
              const Text(
                'PunGuide Done!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                reason.subtitle,
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const Spacer(flex: 4),
              const _ShareRow(),
              const Spacer(flex: 3),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.postDraftBg,
                          foregroundColor: AppColors.foreground,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26)),
                        ),
                        child: const Text(
                          'อยู่ต่อ',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: () => context.goNamed(
                          AppRoute.tripDetail.name,
                          params: {'tripId': tripId},
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.postShare,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26)),
                        ),
                        child: const Text(
                          'ดูทริปของฉัน',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The traveller illustration — pins, a dashed route and a hot air balloon
/// behind the pair reading their map.
class _DoneHero extends StatelessWidget {
  const _DoneHero();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/post_done_hero.png',
      width: 280,
    );
  }
}

/// คัดลอกลิงก์ / LINE / PDF / อื่น ๆ — one row, four equal slots.
class _ShareRow extends StatelessWidget {
  const _ShareRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ShareAction(
          label: 'คัดลอกลิงก์',
          background: AppColors.postDraftBg,
          icon: SvgPicture.asset(
            'assets/icons/share_copy_link.svg',
            width: 19,
            height: 22,
          ),
          onTap: () => _todo(context, 'คัดลอกลิงก์ยังไม่เปิดใช้งาน'),
        ),
        _ShareAction(
          label: 'LINE',
          // The mark already carries its own green circle — no background
          // of our own behind it.
          icon: Image.asset(
            'assets/images/share_line.png',
            width: 56,
            height: 56,
          ),
          onTap: () => _todo(context, 'แชร์ผ่าน LINE ยังไม่เปิดใช้งาน'),
        ),
        _ShareAction(
          label: 'PDF',
          background: const Color(0xFFE2402F),
          // Stand-in until the real PDF mark is dropped in — see the share
          // icons tracked for this screen.
          icon: const Icon(Icons.picture_as_pdf,
              size: 20, color: Colors.white),
          onTap: () => _todo(context, 'ส่งออก PDF ยังไม่เปิดใช้งาน'),
        ),
        _ShareAction(
          label: 'อื่น ๆ',
          background: AppColors.postDraftBg,
          icon: const Icon(Icons.more_horiz,
              size: 22, color: AppColors.foreground),
          onTap: () => _todo(context, 'ช่องทางอื่นยังไม่เปิดใช้งาน'),
        ),
      ],
    );
  }

  static void _todo(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ShareAction extends StatelessWidget {
  const _ShareAction({
    required this.label,
    this.background,
    required this.icon,
    required this.onTap,
  });

  final String label;

  /// Null when [icon] is already a full badge of its own (the LINE mark
  /// carries its own circle) — a second circle behind it would double up.
  final Color? background;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: background ?? Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(child: icon),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: AppColors.foreground, fontSize: 12),
        ),
      ],
    );
  }
}
