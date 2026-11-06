import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../create_trip/domain/plan_labels.dart';
import '../../location_access/domain/location_service.dart';
import '../../trip_style/domain/trip_style_preference.dart';

/// Mirrors the two onboarding answers onto the account, through
/// `/users/me/preferences`.
///
/// One direction only. The device keeps its own copy and the launch sequence
/// reads that and nothing else, so wiping the app's data gives the whole
/// sequence back; this is what puts the answers somewhere a report or another
/// client can see them. `UsersApi.preferences()` is the read half, if the app
/// ever wants it.
///
/// Every route is behind the auth guard, so all of it is skipped while signed
/// out; the local copies carry the app on their own.
class OnboardingSync {
  OnboardingSync(this._ref);

  final Ref _ref;

  /// Records what was tapped on the Location Access page.
  ///
  /// [LocationPermissionStatus.unavailable] is deliberately not sent: the API
  /// takes granted, denied or later and nothing else, and none of them is
  /// true of "the question could not be put". Mapping it onto `denied` would
  /// also wipe the stored place, which is the one thing a traveller whose
  /// location services happen to be off has not asked for.
  Future<bool> pushLocationAccess(LocationPermissionStatus status) async {
    final answer = switch (status) {
      LocationPermissionStatus.granted => LocationAccessAnswer.granted,
      LocationPermissionStatus.denied => LocationAccessAnswer.denied,
      LocationPermissionStatus.later => LocationAccessAnswer.later,
      LocationPermissionStatus.unavailable => null,
    };
    if (answer == null) return false;
    if (!_ref.read(isSignedInProvider)) return false;

    try {
      await (await _ref.read(plunoApiProvider.future))
          .users
          .saveLocationAccess(answer);
      return true;
    } on ApiException catch (failure) {
      debugPrint('location access push failed: ${failure.statusCode} $failure');
      return false;
    }
  }

  /// Records สไตล์เที่ยวของฉัน, splitting the Thai chip labels the page works
  /// in into the enums and free text the API wants.
  Future<bool> pushTravelStyle(TripStylePreference preference) async {
    if (!_ref.read(isSignedInProvider)) return false;

    try {
      await (await _ref.read(plunoApiProvider.future))
          .users
          .saveTravelStyle(travelStyleFrom(preference));
      return true;
    } on ApiException catch (failure) {
      debugPrint('travel style push failed: ${failure.statusCode} $failure');
      return false;
    }
  }
}

/// Thai chip labels to the four lists the API keeps them in.
///
/// A label with an enum behind it goes up as that enum; anything else — a
/// chip typed into "+ เพิ่ม", and อิสลาม / มังสวิรัติ, which are dietary and
/// have no `TripConstraint` — goes up as free text rather than being dropped.
TravelStylePreference travelStyleFrom(TripStylePreference preference) {
  final styles = <TravelStyle>[];
  final customStyles = <String>[];
  for (final label in preference.styles) {
    final style = styleByLabel[label];
    if (style == null) {
      customStyles.add(label);
    } else {
      styles.add(style);
    }
  }

  final constraints = <TripConstraint>[];
  final customConstraints = <String>[];
  for (final label in preference.constraints) {
    final rule = constraintByLabel[label];
    if (rule == null) {
      customConstraints.add(label);
    } else {
      constraints.add(rule);
    }
  }

  return TravelStylePreference(
    styles: styles,
    customStyles: customStyles,
    constraints: constraints,
    customConstraints: customConstraints,
  );
}

/// The way back: what the account holds, as the chips the page draws.
///
/// A free-text entry is kept as it is — that is already the label — so a chip
/// somebody typed on another device shows up here too.
TripStylePreference tripStyleFrom(TravelStylePreference preference) {
  return TripStylePreference(
    styles: <String>[
      ...preference.styles.map(styleLabel).whereType<String>(),
      ...preference.customStyles,
    ],
    constraints: <String>[
      ...preference.constraints.map(constraintLabel).whereType<String>(),
      ...preference.customConstraints,
    ],
  );
}

final onboardingSyncProvider = Provider<OnboardingSync>(OnboardingSync.new);
