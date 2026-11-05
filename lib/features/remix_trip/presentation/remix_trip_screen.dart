import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart' show ApiException, uuidV4;
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../create_post/presentation/widgets/trip_link_picker.dart';
import '../../my_trips/presentation/providers/my_trips_providers.dart';
import '../../trips/presentation/providers/trip_providers.dart';

/// Whole-trip remix: `POST /trips/:id/remix` copies the source into a private
/// draft of the traveller's own, with fresh ids for every day and stop.
class RemixTripScreen extends ConsumerStatefulWidget {
  const RemixTripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<RemixTripScreen> createState() => _RemixTripScreenState();
}

class _RemixTripScreenState extends ConsumerState<RemixTripScreen> {
  /// Minted once per visit and reused across retries, so a second tap or a
  /// retry after a dropped response replays the first remix instead of
  /// creating another copy.
  final String _idempotencyKey = uuidV4();

  bool _creating = false;
  String? _error;

  Future<void> _create(String sourceTitle) async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final api = await ref.read(plunoApiProvider.future);
      final remix = await api.trips.remix(
        widget.tripId,
        title: '$sourceTitle Remix',
        idempotencyKey: _idempotencyKey,
      );
      // The new draft joins the traveller's lists, and the source's
      // remixCount has gone up.
      ref
        ..invalidate(myTripsProvider)
        ..invalidate(myPlansProvider)
        ..invalidate(apiTripProvider(widget.tripId));
      if (!mounted) return;
      setState(() => _creating = false);
      // Pushed, not go'd: "อยู่ต่อ" on the done screen pops straight back to
      // this trip, which `go` would discard.
      context.pushNamed(
        AppRoute.postDone.name,
        params: {'tripId': remix.id},
        queryParams: {'reason': 'remix'},
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = switch (error.statusCode) {
          // The server's own reason: remix switched off, followers only…
          403 => error.message,
          401 => 'เข้าสู่ระบบก่อน จึงจะ Remix ได้',
          404 => 'ไม่พบทริปนี้แล้ว',
          _ => 'Remix ไม่สำเร็จ ลองอีกครั้ง',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = 'Remix ไม่สำเร็จ ลองอีกครั้ง';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(selectedTripProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Remix Trip')),
      body: trip.when(
        data: (trip) {
          if (trip == null) {
            return const Center(child: Text('Trip not found.'));
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duplicate "${trip.title}" and edit it into your own plan.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CoverImage(
                    source: trip.coverImage,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const Spacer(),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _creating ? null : () => _create(trip.title),
                  icon: _creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.call_split),
                  label: const Text('Create remix and edit'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
