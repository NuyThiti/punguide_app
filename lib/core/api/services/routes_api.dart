import '../../network/api_client.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/travel_segment.dart';

/// Point-to-point travel time and distance.
class RoutesApi {
  const RoutesApi(this._client);

  final PlunoApiClient _client;

  /// Time and distance between two points, cached for 24 hours on the key
  /// origin + destination + mode.
  ///
  /// Only [TravelMode.drive] is routable today; the others come back as a 400.
  /// A POST, because two coordinate pairs have no business in a query string.
  Future<RouteCalculation> calculate({
    required RouteWaypoint origin,
    required RouteWaypoint destination,
    TravelMode travelMode = TravelMode.drive,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/routes/calculate',
      body: <String, dynamic>{
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'travelMode': travelMode.wire,
      },
    );
    return RouteCalculation.fromJson(Json.asMap(body));
  }
}
