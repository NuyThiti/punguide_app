import 'package:flutter/material.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../trips/presentation/itinerary_display.dart';

/// What the planner came back with, before anything is written down.
///
/// `POST /trips/plan/generate` saves nothing, so this is the traveller's
/// chance to look the plan over and say yes. Returns true when they do.
Future<bool> showPlanReviewSheet(
  BuildContext context,
  PlanGenerationResult result,
) async {
  final keep = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (_) => _PlanReviewSheet(result: result),
  );
  return keep ?? false;
}

class _PlanReviewSheet extends StatelessWidget {
  const _PlanReviewSheet({required this.result});

  final PlanGenerationResult result;

  @override
  Widget build(BuildContext context) {
    final draft = result.draft;
    final report = result.generation;
    final stops =
        draft.days.fold<int>(0, (sum, day) => sum + day.activities.length);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            draft.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${draft.days.length} วัน · $stops สถานที่',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Not an error state: the draft is still usable, the plan
                  // just has spots worth a second look.
                  if (!report.resolvedWithoutErrors)
                    const _Notice(
                      icon: Icons.info_outline,
                      text: 'แผนนี้อาจมีจุดที่ต้องปรับ ดูรายละเอียดด้านล่าง',
                    ),
                  for (final warning in result.resolvedBrief.warnings)
                    _Notice(icon: Icons.tune, text: warning),
                  for (final warning in report.modelWarnings)
                    _Notice(icon: Icons.auto_awesome_outlined, text: warning),
                  for (final violation in report.violations)
                    _Notice(
                      icon: violation.severity == ViolationSeverity.error
                          ? Icons.error_outline
                          : Icons.warning_amber_outlined,
                      text: violation.dayNumber == null
                          ? violation.message
                          : 'วันที่ ${violation.dayNumber}: ${violation.message}',
                    ),
                  const SizedBox(height: 6),
                  for (final day in draft.days) _DayBlock(day: day),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppColors.foreground,
                    side: const BorderSide(color: AppColors.chipBorder),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('ทิ้งแผนนี้'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('บันทึกแผน'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.day});

  final DraftDay day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'วันที่ ${day.dayNumber ?? '-'}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2E6B4C),
            ),
          ),
          if ((day.daySummary ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              day.daySummary!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 8),
          for (final stop in day.activities)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      stop.time == null ? '' : clockLabel(stop.time!),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandOrange,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                        if (stop.category != null)
                          Text(
                            categoryLabels[stop.category] ?? '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.brandOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF5A5650)),
            ),
          ),
        ],
      ),
    );
  }
}
