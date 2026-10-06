import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';

/// "เชื่อมแพลนของฉัน" — the row on the share screen that opens
/// [showTripLinkPicker] (`trip_link_picker.dart`) and, once a plan is linked,
/// shows which one.
///
/// Display-only: the caller resolves [title]/[coverUrl]/[factsLine] from
/// whatever it has on hand (the trip's own `linkedTrip`, or a freshly picked
/// [PostTripLink] matched back against `myPlansProvider`'s cached rows) —
/// this widget never reaches into either itself.
class ConnectPlanSection extends StatelessWidget {
  const ConnectPlanSection({
    super.key,
    required this.connected,
    required this.onTap,
    this.title,
    this.coverUrl,
    this.factsLine,
  });

  final bool connected;
  final VoidCallback onTap;
  final String? title;
  final String? coverUrl;
  final String? factsLine;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.screen,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.chipBorder),
          ),
          child: Row(
            children: [
              _Leading(connected: connected, coverUrl: coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      connected ? 'เชื่อมแพลน${title ?? ''}' : 'เชื่อมแพลนของฉัน',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connected
                          ? (factsLine ?? '')
                          : 'เชื่อมโพสต์นี้กับแพลนท่องเที่ยวของคุณ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.connected, required this.coverUrl});

  final bool connected;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    if (connected) {
      return Container(
        width: 40,
        height: 40,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.postIconWell,
          borderRadius: BorderRadius.circular(10),
        ),
        child: coverUrl == null || coverUrl!.isEmpty
            ? const Icon(Icons.map_outlined, color: AppColors.postPurple, size: 18)
            : CoverImage(source: coverUrl!),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.postPurpleSoft,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.link, color: AppColors.postPurple, size: 18),
    );
  }
}
