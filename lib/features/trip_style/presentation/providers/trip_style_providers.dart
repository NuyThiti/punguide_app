import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/data/onboarding_sync.dart';
import '../../data/trip_style_store.dart';
import '../../domain/trip_style_preference.dart';

/// Where the answer is kept between runs.
final tripStyleStoreProvider =
    Provider<TripStyleStore>((ref) => const PrefsTripStyleStore());

/// The answer as it stood when the app started, which `main` overrides once it
/// has read storage. Null means the question has never been put.
///
/// Read once at startup rather than awaited on demand, for the same reason
/// the stored origin and the location answer are: the launch sequence decides
/// where to send the traveller while it builds, and the board asks for its
/// filter in the same breath. Waiting on the disk would stall both.
final storedTripStyleProvider = Provider<TripStylePreference?>((ref) => null);

/// What the traveller last answered, or null while they have never been asked.
final tripStyleProvider =
    NotifierProvider<TripStyleController, TripStylePreference?>(
  TripStyleController.new,
);

class TripStyleController extends Notifier<TripStylePreference?> {
  @override
  TripStylePreference? build() => ref.watch(storedTripStyleProvider);

  /// Takes the answer and writes it through, so the page does not come back on
  /// the next launch. Waving it away with ข้ามไปก่อน is an answer too — it
  /// saves [TripStylePreference.skipped] rather than nothing, or the launch
  /// sequence would put the same page up every run.
  Future<void> save(TripStylePreference preference) async {
    state = preference;
    await ref.read(tripStyleStoreProvider).write(preference);
    // And onto the account, so a second device does not ask again. An empty
    // preference goes up as an empty set rather than not at all, which is
    // what records "answered, chose nothing" server-side.
    await ref.read(onboardingSyncProvider).pushTravelStyle(preference);
  }

  /// Takes an answer the account already held, without sending it back.
  ///
  /// Used once at launch, for a traveller signing in on a new device.
  Future<void> adopt(TripStylePreference preference) async {
    state = preference;
    await ref.read(tripStyleStoreProvider).write(preference);
  }

  /// Forgets the answer, so สไตล์เที่ยวของฉัน is asked again.
  Future<void> clear() async {
    state = null;
    await ref.read(tripStyleStoreProvider).clear();
  }
}

/// Whether the launch sequence still owes the traveller this page.
final needsTripStyleProvider =
    Provider<bool>((ref) => ref.watch(tripStyleProvider) == null);
