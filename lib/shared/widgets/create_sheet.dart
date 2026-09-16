import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';

/// What the traveller picked in the create sheet.
enum CreateAction {
  /// Share a trip you already took, as a guide.
  punGuide,

  /// Plan a new trip by hand.
  ownPlan,

  /// A community post.
  post,

  /// A short clip for the Puntok feed.
  puntok,
}

/// The sheet behind the nav bar's Create button, from Figma node 1539-8068.
///
/// Returns the chosen action, or null when dismissed — the caller routes, so
/// the sheet stays a pure picker.
Future<CreateAction?> showCreateSheet(BuildContext context) {
  return showModalBottomSheet<CreateAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => const CreateSheet(),
  );
}

class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // A large text scale must not push ตกลง off the bottom.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        18 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          const SizedBox(height: 20),
          const Text(
            'Create',
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 26),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FeaturedOption(
                    icon: 'assets/icons/create_punguide.svg',
                    title: 'PunGuide',
                    subtitle: 'แบ่งปันประสบการณ์ทริปของคุณ',
                    onTap: () =>
                         Navigator.of(context).pop(CreateAction.post),
                  ),
                  const SizedBox(height: 14),
                  _PlainOption(
                    icon: 'assets/icons/create_plan.svg',
                    title: 'สร้างแพลนเอง',
                    subtitle: 'สร้างแพลนทริปของคุณเอง',
                    onTap: () =>
                        Navigator.of(context).pop(CreateAction.ownPlan),
                  ),
                  const SizedBox(height: 14),
                  // _PlainOption(
                  //   icon: 'assets/icons/create_post.svg',
                  //   title: 'Post',
                  //   subtitle: 'สร้างโพส อัปเดตสเตตัส และพูดคุยกับคอมมูนิตี้',
                  //   onTap: () => Navigator.of(context).pop(CreateAction.post),
                  // ),
                  const SizedBox(height: 14),
                  _PlainOption(
                    icon: 'assets/icons/create_puntok.svg',
                    title: 'Puntok',
                    subtitle: 'สร้างคลิปสั้นจากทริป ลงฟีด Puntok',
                    onTap: () => Navigator.of(context).pop(CreateAction.puntok),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sheetConfirm,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'ตกลง',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D6D1),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

/// The primary choice: a purple card that reads as the app's own action.
class _FeaturedOption extends StatelessWidget {
  const _FeaturedOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.createHeroStart, AppColors.createHeroEnd],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SvgPicture.asset(icon, width: 24, height: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.createHeroArrow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_outward,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlainOption extends StatelessWidget {
  const _PlainOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.screen,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.optionIconBg,
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(icon, width: 19, height: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the sheet and routes the choice.
///
/// "สร้างแพลนเอง" and "Post" have screens; the other two report themselves as
/// unbuilt rather than going nowhere quietly.
Future<void> openCreateSheet(
  BuildContext context, {
  required VoidCallback onOwnPlan,
  required VoidCallback onPost,
  required void Function(String message) onUnavailable,
}) async {
  final choice = await showCreateSheet(context);
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case CreateAction.ownPlan:
      onOwnPlan();
    case CreateAction.post:
      onPost();
    case CreateAction.punGuide:
      onUnavailable('ปันไกด์ทริปยังไม่เปิดใช้งาน');
    case CreateAction.puntok:
      onUnavailable('สร้างคลิป Puntok ยังไม่เปิดใช้งาน');
  }
}
