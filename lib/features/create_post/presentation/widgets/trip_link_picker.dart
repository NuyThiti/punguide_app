import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../trips/presentation/providers/trip_providers.dart';
import '../../domain/models/post_draft.dart';
import 'composer_sheet.dart';

/// Asks which trip the post belongs to. Returns null when dismissed, and
/// [PostTripLink] with an empty id to mean "no trip after all".
Future<PostTripLink?> showTripLinkPicker(BuildContext context) {
  return showModalBottomSheet<PostTripLink>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => const _TripLinkPicker(),
  );
}

/// What [showTripLinkPicker] returns for "ไม่เชื่อมกับทริป".
const noTripLink = PostTripLink(id: '', title: '');

class _TripLinkPicker extends ConsumerWidget {
  const _TripLinkPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripListProvider);

    return ComposerSheet(
      title: 'เชื่อมกับทริป',
      child: trips.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, __) => const _SheetNote('อ่านทริปของคุณไม่สำเร็จ'),
        data: (rows) {
          if (rows.isEmpty) {
            return const _SheetNote('ยังไม่มีทริปให้เชื่อม สร้างแพลนก่อนได้เลย');
          }
          return ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: rows.length + 1,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.line),
            itemBuilder: (context, index) {
              if (index == rows.length) {
                return ListTile(
                  onTap: () => Navigator.of(context).pop(noTripLink),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(
                    Icons.link_off,
                    size: 20,
                    color: AppColors.muted,
                  ),
                  title: const Text(
                    'ไม่เชื่อมกับทริป',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              final trip = rows[index];
              return ListTile(
                onTap: () => Navigator.of(context).pop(
                  PostTripLink(id: trip.id, title: trip.title),
                ),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                leading: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.postIconWell,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.route,
                    size: 19,
                    color: AppColors.brandOrange,
                  ),
                ),
                title: Text(
                  trip.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  trip.destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SheetNote extends StatelessWidget {
  const _SheetNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    );
  }
}
