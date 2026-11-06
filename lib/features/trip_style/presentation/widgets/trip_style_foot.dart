import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The foot of สไตล์เที่ยวของฉัน: what has been chosen, the way on, and the
/// way past.
///
/// The count row only appears once something is picked — and the button
/// changes its word with it, from ถัดไป to ตกลง, because by then the page is
/// an answer rather than a step to walk through.
class TripStyleFoot extends StatelessWidget {
  const TripStyleFoot({
    super.key,
    required this.chosenCount,
    required this.onClear,
    required this.onContinue,
    required this.onSkip,
  });

  final int chosenCount;
  final VoidCallback onClear;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final chosen = chosenCount > 0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chosen) ...[
                Row(
                  children: [
                    Text(
                      '$chosenCount รายการ',
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onClear,
                      child: const Text(
                        'ล้างที่เลือก',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Material(
                  color: AppColors.filterAction,
                  borderRadius: BorderRadius.circular(99),
                  child: InkWell(
                    onTap: onContinue,
                    borderRadius: BorderRadius.circular(99),
                    child: Center(
                      child: Text(
                        chosen ? 'ตกลง' : 'ถัดไป',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onSkip,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'ข้ามไปก่อน',
                    style: TextStyle(
                      color: AppColors.filterAction,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
