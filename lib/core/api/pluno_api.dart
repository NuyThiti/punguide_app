import '../network/api_client.dart';
import '../network/api_config.dart';
import 'services/auth_api.dart';
import 'services/budget_api.dart';
import 'services/chat_api.dart';
import 'services/itinerary_api.dart';
import 'services/media_api.dart';
import 'services/places_api.dart';
import 'services/routes_api.dart';
import 'services/share_api.dart';
import 'services/trips_api.dart';

export '../network/api_client.dart';
export '../network/api_config.dart';
export '../network/api_exception.dart';
export '../network/api_headers.dart';
export '../network/auth_token_store.dart';
export '../network/uuid_v4.dart';
export 'models/accommodation.dart';
export 'models/activity.dart';
export 'models/auth_user.dart';
export 'models/budget.dart';
export 'models/chat.dart';
export 'models/day.dart';
export 'models/destination_place.dart';
export 'models/enums.dart';
export 'models/expense.dart';
export 'models/json.dart' show Json, Patch;
export 'models/media.dart';
export 'models/place.dart';
export 'models/post_assistant.dart';
export 'models/plan_generation.dart';
export 'models/schedule.dart';
export 'models/share.dart';
export 'models/travel_segment.dart';
export 'models/trip.dart';
export 'models/trip_draft.dart';
export 'models/trip_feed_query.dart';
export 'models/user_location.dart';
export 'services/auth_api.dart';
export 'services/budget_api.dart';
export 'services/chat_api.dart';
export 'services/itinerary_api.dart';
export 'services/media_api.dart';
export 'services/places_api.dart';
export 'services/routes_api.dart';
export 'services/share_api.dart';
export 'services/trips_api.dart';

/// The Pluno API, grouped by area.
///
/// Build one per app run — [create] sets up the persistent cookie jar the
/// refresh flow depends on — and read it from `plunoApiProvider`.
class PlunoApi {
  PlunoApi(this.client)
      : auth = AuthApi(client),
        users = UsersApi(client),
        trips = TripsApi(client),
        itinerary = ItineraryApi(client),
        budget = BudgetApi(client),
        places = PlacesApi(client),
        routes = RoutesApi(client),
        media = MediaApi(client),
        share = ShareApi(client),
        chat = ChatApi(client);

  /// Reads the host from `PLUNO_API_BASE_URL`, restores the stored access
  /// token, and opens the on-disk cookie jar.
  static Future<PlunoApi> create({ApiConfig? config}) async =>
      PlunoApi(await PlunoApiClient.create(config: config));

  final PlunoApiClient client;
  final AuthApi auth;
  final UsersApi users;
  final TripsApi trips;
  final ItineraryApi itinerary;

  /// Accommodations and standalone expenses. The budget *summary* itself is
  /// `trips.budget`, since it hangs off the trip.
  final BudgetApi budget;
  final PlacesApi places;
  final RoutesApi routes;
  final MediaApi media;
  final ShareApi share;

  /// The travel assistant. Token-only — there is no anonymous mode here.
  final ChatApi chat;

  /// True once a token has been restored or issued. It says nothing about the
  /// token still being valid — the client refreshes it on first use.
  bool get hasSession => client.tokenStore.hasToken;

  Future<void> close() => client.close();
}
