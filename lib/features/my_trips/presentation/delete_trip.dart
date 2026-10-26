import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/presentation/providers/profile_providers.dart';
import 'providers/my_trips_providers.dart';

/// Asks first, then deletes the trip and everything filed under it.
///
/// Shared by every wall of the traveller's own trips, so the wording and the
/// failure handling cannot drift between them. The row leaves the list before
/// the request — [MyTripsNotifier.delete] does that — and comes back if the
/// server refuses.
Future<void> confirmDeleteTrip(
  BuildContext context,
  WidgetRef ref,
  TripListItem trip,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'ลบทริปนี้',
        style: TextStyle(
          color: AppColors.foreground,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        '"${trip.title}" จะถูกลบถาวร พร้อมวัน สถานที่ รูป และค่าใช้จ่ายในทริป',
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'ยกเลิก',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'ลบ',
            style: TextStyle(
              color: AppColors.brandOrangeDeep,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await ref.read(myTripsProvider.notifier).delete(trip.id);
    // The album shelf is its own read of the same trips, so it would keep
    // showing a row that no longer exists until something re-read it.
    ref.invalidate(myAlbumsProvider);
    messenger.showSnackBar(const SnackBar(content: Text('ลบทริปแล้ว')));
  } on ApiException catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error.statusCode == 401 ? 'เข้าสู่ระบบก่อน จึงจะลบได้' : error.message,
        ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('ลบไม่สำเร็จ ลองอีกครั้ง')),
    );
  }
}
