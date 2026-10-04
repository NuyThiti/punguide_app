import 'package:flutter/foundation.dart';

import 'json.dart';
import 'place.dart';

/// Where the account says the traveller last was — a row in `places`, not a
/// raw GPS reading.
///
/// One place, overwritten on every save — deliberately not a trail. See
/// `PUT /users/me/location`, which is readable only by its owner. It answers
/// in the same shape as a place search result, so [place] drops straight into
/// anything that already renders one.
@immutable
class UserLocation {
  const UserLocation._(this.place, this.latitude, this.longitude);

  /// Null for `{"location": null}`, which is what a 200 says when nothing has
  /// been stored yet — and also for a stored place with no coordinates. The
  /// server itself treats that one as "no location" when the post assistant
  /// falls back to it, and every caller here wants a point to measure from,
  /// so a name alone is not worth handing on.
  static UserLocation? maybeFrom(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (Json.string(json, 'id') == null || Json.string(json, 'name') == null) {
      return null;
    }
    final place = Place.fromJson(json);
    final latitude = place.latitude;
    final longitude = place.longitude;
    if (latitude == null || longitude == null) return null;
    return UserLocation._(place, latitude, longitude);
  }

  /// Unwraps the `location` key that both the GET and the PUT answer with.
  static UserLocation? fromEnvelope(Object? body) =>
      maybeFrom(Json.asMap(body)['location']);

  /// The stored place itself. `place.id` is what a PUT takes back.
  final Place place;

  /// The place's own coordinates — never null here, see [maybeFrom].
  final double latitude;
  final double longitude;

  String get placeId => place.id;
  String get name => place.name;
  String? get address => place.address;
}
