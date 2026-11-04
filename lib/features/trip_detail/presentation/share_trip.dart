import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';

/// Hands a message to the platform share sheet. A provider so tests can see
/// what would have been shared without a real sheet opening.
final shareSheetProvider = Provider<Future<void> Function(ShareParams)>(
  (ref) => (params) async {
    await SharePlus.instance.share(params);
  },
);

/// Opens (or reuses) the trip's share link and offers it on the share sheet.
///
/// Owner-only: `POST /trips/:id/share` checks ownership, and is idempotent
/// while a link is live, so sharing twice hands out the same URL. The link is
/// used exactly as the server built it — its base is server configuration.
///
/// [origin] anchors the sheet's popover on iPad; pass the tapped widget's
/// context when there is one.
Future<void> shareTripLink(
  BuildContext context,
  WidgetRef ref, {
  required String tripId,
  required String title,
  BuildContext? origin,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final box = (origin ?? context).findRenderObject() as RenderBox?;
  final anchor = box != null && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;

  final TripShare share;
  try {
    final api = await ref.read(plunoApiProvider.future);
    share = await api.share.create(tripId);
  } on ApiException catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error.statusCode == 401
              ? 'เข้าสู่ระบบก่อน จึงจะแชร์ได้'
              : 'สร้างลิงก์แชร์ไม่สำเร็จ ลองอีกครั้ง',
        ),
      ),
    );
    return;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('สร้างลิงก์แชร์ไม่สำเร็จ ลองอีกครั้ง')),
    );
    return;
  }

  final name = title.trim();
  try {
    await ref.read(shareSheetProvider)(
      ShareParams(
        // Text rather than `uri`: share_plus takes one or the other, and a
        // URL inside the text still unfurls into a preview in LINE and
        // Messenger while keeping the trip's name above it.
        text: name.isEmpty ? share.shareUrl : '$name\n${share.shareUrl}',
        subject: name.isEmpty ? null : name,
        sharePositionOrigin: anchor,
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('เปิดหน้าแชร์ไม่สำเร็จ')),
    );
  }
}
