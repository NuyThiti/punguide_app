import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// ติดตาม / ติดตามกลับ / กำลังติดตาม.
///
/// Filled orange while there is something to do, outlined once done.
/// "ติดตามกลับ" only when they follow the viewer and the viewer does not
/// follow them yet.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.following,
    required this.onPressed,
    this.followsYou = false,
    this.dense = false,
  });

  final bool following;
  final bool followsYou;
  final VoidCallback onPressed;

  /// A list-row size rather than the profile's full-width one.
  final bool dense;

  static String labelFor({required bool following, required bool followsYou}) =>
      following
          ? 'กำลังติดตาม'
          : followsYou
              ? 'ติดตามกลับ'
              : 'ติดตาม';

  @override
  Widget build(BuildContext context) {
    final label = labelFor(following: following, followsYou: followsYou);
    final height = dense ? 32.0 : 40.0;
    final text = TextStyle(
      fontSize: dense ? 12.5 : 14,
      fontWeight: FontWeight.w700,
      color: following ? AppColors.foreground : Colors.white,
    );

    return SizedBox(
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 20),
          minimumSize: Size(dense ? 92 : 0, height),
          backgroundColor: following ? Colors.white : AppColors.brandOrange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
            side: following
                ? const BorderSide(color: AppColors.line)
                : BorderSide.none,
          ),
        ),
        child: Text(label, style: text),
      ),
    );
  }
}
