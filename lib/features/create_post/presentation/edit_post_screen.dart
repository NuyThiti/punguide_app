import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../trips/presentation/providers/trip_providers.dart';
import 'create_post_screen.dart';

/// The post page's แก้ไข: the full composer, opened on the existing post.
///
/// Only the id travels in the route, so the post is read here first and the
/// composer gets it whole — it seeds every field from `initialTrip` once, in
/// `initState`, and never looks again. Next then goes on to
/// `PostShareSettingsScreen` as step 2/2, exactly as a new post does.
class EditPostScreen extends ConsumerWidget {
  const EditPostScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(apiTripProvider(tripId));
    return trip.when(
      data: (loaded) => CreatePostScreen(initialTrip: loaded),
      loading: () => const Scaffold(
        backgroundColor: AppColors.screen,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.screen,
        appBar: AppBar(backgroundColor: AppColors.screen),
        body: const Center(child: Text('โหลดโพสต์ไม่สำเร็จ ลองอีกครั้ง')),
      ),
    );
  }
}
