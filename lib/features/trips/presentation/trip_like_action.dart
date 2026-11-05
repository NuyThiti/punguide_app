import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'providers/trip_like_providers.dart';

/// Hearts or un-hearts [trip] from whichever wall the traveller tapped.
///
/// Written once rather than per screen: every wall that shows a card does the
/// same three things around the flip — turn an anonymous tap into a sign-in
/// prompt, let the ledger do the optimistic work, and say something when the
/// server refuses. Four copies of that drifted apart the moment one of them
/// got a better message.
Future<void> toggleTripLike(
  BuildContext context,
  WidgetRef ref,
  TripListItem trip,
) async {
  // Liking needs an account; the feed itself reads fine anonymously.
  if (!ref.read(isSignedInProvider)) {
    _promptSignIn(context);
    return;
  }

  final wasLiked = likedNow(ref.read(tripLikedProvider), trip);
  try {
    await ref
        .read(tripLikedProvider.notifier)
        .toggle(trip.id, wasLiked: wasLiked);
  } on ApiException catch (failure) {
    if (!context.mounted) return;
    if (failure.isUnauthorized) {
      _promptSignIn(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure.isNetworkFailure
              ? 'เชื่อมต่อไม่ได้ ลองใหม่อีกครั้ง'
              : 'ถูกใจทริปไม่สำเร็จ: ${failure.message}',
        ),
      ),
    );
  }
}

void _promptSignIn(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('เข้าสู่ระบบก่อนเพื่อถูกใจทริป'),
      action: SnackBarAction(
        label: 'เข้าสู่ระบบ',
        onPressed: () => context.goNamed(AppRoute.login.name),
      ),
    ),
  );
}
