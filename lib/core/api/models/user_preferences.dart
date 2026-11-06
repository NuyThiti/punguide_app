import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json.dart';

/// What the traveller answered on the Location Access page.
///
/// This is the answer **on the app's own screen**, not the OS permission:
/// somebody can revoke location in Settings without the server ever hearing
/// about it, so the real state always has to come from the device.
enum LocationAccessAnswer {
  /// Tapped อนุญาต, and the OS allowed it.
  granted('granted'),

  /// Tapped อนุญาต and the OS dialog was refused — or the permission was
  /// taken back later.
  denied('denied'),

  /// Tapped ไว้ทีหลังนะ.
  later('later');

  const LocationAccessAnswer(this.wire);

  final String wire;

  static LocationAccessAnswer? from(Object? value) {
    for (final answer in values) {
      if (answer.wire == value) return answer;
    }
    return null;
  }
}

/// One onboarding page's answer, with when it was given.
@immutable
class LocationAccessPreference {
  const LocationAccessPreference({required this.status, this.updatedAt});

  static LocationAccessPreference? maybeFrom(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    final status = LocationAccessAnswer.from(json['status']);
    // A status this build cannot read is no answer at all: asking once more
    // costs a page, acting on a value we do not understand costs trust.
    if (status == null) return null;
    return LocationAccessPreference(
      status: status,
      updatedAt: Json.timestamp(json, 'updatedAt'),
    );
  }

  final LocationAccessAnswer status;
  final DateTime? updatedAt;
}

/// สไตล์เที่ยวของฉัน as the account holds it.
///
/// Four lists rather than two because only some chips have an enum behind
/// them: อิสลาม and มังสวิรัติ are dietary, have no `TripConstraint`, and ride
/// in [customConstraints] — the same split `GET /trips` already uses.
@immutable
class TravelStylePreference {
  const TravelStylePreference({
    this.styles = const <TravelStyle>[],
    this.customStyles = const <String>[],
    this.constraints = const <TripConstraint>[],
    this.customConstraints = const <String>[],
  });

  static TravelStylePreference? maybeFrom(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    return TravelStylePreference(
      styles: _enums(json['styles'], TravelStyle.from),
      customStyles: Json.stringList(json, 'customStyles'),
      constraints: _enums(json['constraints'], TripConstraint.from),
      customConstraints: Json.stringList(json, 'customConstraints'),
    );
  }

  final List<TravelStyle> styles;
  final List<String> customStyles;
  final List<TripConstraint> constraints;
  final List<String> customConstraints;

  /// Answered, but with nothing picked — what `PUT {}` records.
  bool get isEmpty =>
      styles.isEmpty &&
      customStyles.isEmpty &&
      constraints.isEmpty &&
      customConstraints.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'styles': styles.map((style) => style.wire).toList(growable: false),
        'customStyles': customStyles,
        'constraints':
            constraints.map((rule) => rule.wire).toList(growable: false),
        'customConstraints': customConstraints,
      };

  /// A value this build does not know is dropped rather than failing the
  /// whole answer — a chip added server-side should not blank the rest.
  static List<T> _enums<T>(Object? value, T? Function(Object?) read) {
    if (value is! List) return const [];
    return List<T>.unmodifiable(value.map(read).whereType<T>());
  }
}

/// Which onboarding pages this account has answered.
///
/// Either half is null while that page has never been answered, which is what
/// decides whether to put it up again.
@immutable
class UserPreferences {
  const UserPreferences({this.locationAccess, this.travelStyle});

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        locationAccess:
            LocationAccessPreference.maybeFrom(json['locationAccess']),
        travelStyle: TravelStylePreference.maybeFrom(json['travelStyle']),
      );

  /// Nothing answered — the shape a brand new account comes back as.
  static const none = UserPreferences();

  final LocationAccessPreference? locationAccess;
  final TravelStylePreference? travelStyle;
}
