import 'package:flutter/foundation.dart';

import '../../features/trips/domain/models/trip.dart';

/// Community stats that the backend does not expose yet. Derived from the trip
/// content so the same trip always renders the same numbers.
@immutable
class TripSocialMeta {
  const TripSocialMeta({
    required this.tags,
    required this.avatar,
    required this.handle,
    required this.saves,
    required this.remixes,
  });

  final List<String> tags;
  final String avatar;
  final String handle;
  final String saves;
  final int remixes;

  factory TripSocialMeta.fromTrip(Trip trip) {
    final text =
        '${trip.title} ${trip.destination} ${trip.description}'.toLowerCase();

    if (text.contains('maldives')) {
      return const TripSocialMeta(
        tags: ['Beach', 'Luxury'],
        avatar: '🌺',
        handle: '@sofiatravel',
        saves: '1.2k',
        remixes: 87,
      );
    }
    if (text.contains('swiss') || text.contains('alpine')) {
      return const TripSocialMeta(
        tags: ['Mountain', 'Adventure'],
        avatar: '🏔️',
        handle: '@marcohikes',
        saves: '892',
        remixes: 124,
      );
    }
    if (text.contains('brussels')) {
      return const TripSocialMeta(
        tags: ['City', 'Culture'],
        avatar: '🍫',
        handle: '@leaexplores',
        saves: '567',
        remixes: 43,
      );
    }
    if (text.contains('thailand') || text.contains('samui')) {
      return const TripSocialMeta(
        tags: ['Beach', 'Budget'],
        avatar: '🌴',
        handle: '@budgettravels',
        saves: '2.1k',
        remixes: 215,
      );
    }
    return const TripSocialMeta(
      tags: ['Adventure', 'Culture'],
      avatar: '✈️',
      handle: '@pluno',
      saves: '128',
      remixes: 12,
    );
  }
}
