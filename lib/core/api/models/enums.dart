enum TripType {
  planTrip('plan_trip'),
  content('content');

  const TripType(this.wire);
  final String wire;
  static TripType from(Object? value) =>
      value == 'content' ? content : planTrip;
}

/// Every enum the API accepts or returns, with its exact wire value.
///
/// Values are case-sensitive on the wire. Unknown values decode to `null`
/// rather than throwing, so a server-side addition does not crash the app.

/// How `GET /trips` orders the feed.
///
/// [nearest] needs `lat`/`lng` alongside it; without them the server falls
/// back to [recent] rather than failing, so a traveller who refused location
/// still gets a feed.
enum FeedSort {
  recent('recent'),
  nearest('nearest'),
  popular('popular');

  const FeedSort(this.wire);

  final String wire;
}

/// Whether a budget ceiling on the feed filter is one traveller's share or the
/// whole group's bill. The server divides by the *trip's* head count for
/// [perPerson] — not by the head count in the filter.
enum FeedBudgetScope {
  total('total'),
  perPerson('per_person');

  const FeedBudgetScope(this.wire);

  final String wire;
}

/// Where a trip is in its life cycle.
enum TripStatus {
  draft('draft'),
  shared('shared'),
  confirmed('confirmed'),
  completed('completed');

  const TripStatus(this.wire);

  final String wire;

  static TripStatus? from(Object? value) => _lookup(values, value);
}

/// Who can see — and remix — a trip.
enum TripVisibility {
  private('private'),
  public('public');

  const TripVisibility(this.wire);

  final String wire;

  static TripVisibility? from(Object? value) => _lookup(values, value);
}

/// How a trip came to exist.
enum PlanMode {
  ai('ai'),
  manual('manual'),
  remixed('remixed');

  const PlanMode(this.wire);

  final String wire;

  static PlanMode? from(Object? value) => _lookup(values, value);
}

/// The database's place taxonomy — what `Place.category` uses.
enum PlaceCategory {
  attraction('attraction'),
  restaurant('restaurant'),
  hotel('hotel'),
  cafe('cafe'),
  activity('activity'),
  transport('transport'),
  shopping('shopping');

  const PlaceCategory(this.wire);

  final String wire;

  static PlaceCategory? from(Object? value) => _lookup(values, value);

  /// The itinerary taxonomy this place maps to. The server already applies
  /// this when a stop is linked to a place; it is here for local previews.
  ActivityCategory get asActivityCategory {
    switch (this) {
      case PlaceCategory.attraction:
        return ActivityCategory.sightseeing;
      case PlaceCategory.restaurant:
      case PlaceCategory.cafe:
        return ActivityCategory.food;
      case PlaceCategory.hotel:
        return ActivityCategory.hotel;
      case PlaceCategory.activity:
        return ActivityCategory.activity;
      case PlaceCategory.transport:
        return ActivityCategory.transport;
      case PlaceCategory.shopping:
        return ActivityCategory.other;
    }
  }
}

/// The itinerary taxonomy — what `Activity.category` uses. Narrower than
/// [PlaceCategory]: cafés fold into food, and shopping has no slot.
enum ActivityCategory {
  transport('transport'),
  food('food'),
  hotel('hotel'),
  sightseeing('sightseeing'),
  activity('activity'),
  other('other');

  const ActivityCategory(this.wire);

  final String wire;

  static ActivityCategory? from(Object? value) => _lookup(values, value);
}

/// Expense and budget-summary categories: [ActivityCategory] plus fuel and
/// shopping, which a stop can never be.
enum ExpenseCategory {
  transport('transport'),
  food('food'),
  hotel('hotel'),
  sightseeing('sightseeing'),
  activity('activity'),
  fuel('fuel'),
  shopping('shopping'),
  other('other');

  const ExpenseCategory(this.wire);

  final String wire;

  static ExpenseCategory? from(Object? value) => _lookup(values, value);
}

enum BookingStatus {
  notRequired('not_required'),
  available('available'),
  booked('booked'),
  soldOut('sold_out'),
  unknown('unknown');

  const BookingStatus(this.wire);

  final String wire;

  static BookingStatus? from(Object? value) => _lookup(values, value);
}

/// How tiring a day is planned to be.
enum FatigueLevel {
  low('low'),
  medium('medium'),
  high('high');

  const FatigueLevel(this.wire);

  final String wire;

  static FatigueLevel? from(Object? value) => _lookup(values, value);
}

/// How one leg of a day is travelled, as stored on the itinerary item.
enum TravelType {
  walk('walk'),
  bicycle('bicycle'),
  tukTuk('tuk_tuk'),
  privateTransfer('private_transfer'),
  rentalCar('rental_car'),
  boat('boat'),
  train('train'),
  airplane('airplane'),
  other('other');

  const TravelType(this.wire);

  final String wire;

  static TravelType? from(Object? value) => _lookup(values, value);
}

/// The routing mode asked of Google. Note the SCREAMING_CASE wire values.
///
/// Only [drive] is routable today; the other three pass validation and then
/// come back as 400 "not supported yet".
enum TravelMode {
  drive('DRIVE'),
  walk('WALK'),
  bicycle('BICYCLE'),
  transit('TRANSIT');

  const TravelMode(this.wire);

  final String wire;

  /// Whether the API can currently calculate a route for this mode.
  bool get isSupported => this == TravelMode.drive;

  static TravelMode? from(Object? value) => _lookup(values, value);
}

enum RouteStatus {
  calculated('CALCULATED'),
  failed('FAILED');

  const RouteStatus(this.wire);

  final String wire;

  static RouteStatus? from(Object? value) => _lookup(values, value);
}

/// A trip-level transport preference used in the plan brief. Distinct from
/// [TravelMode], which is the routing mode for a single leg.
enum TransportMode {
  privateCar('private_car'),
  rentalCar('rental_car'),
  motorbike('motorbike'),
  publicTransit('public_transit'),

  /// "Just recommend something" — no particular preference.
  recommend('recommend');

  const TransportMode(this.wire);

  final String wire;

  static TransportMode? from(Object? value) => _lookup(values, value);
}

/// A travel style. Free-text additions go in `customStyles` instead — only
/// these map onto Google Places queries.
enum TravelStyle {
  beach('beach'),
  mountain('mountain'),
  nature('nature'),
  local('local'),
  culture('culture'),
  food('food'),
  cafe('cafe'),
  nightlife('nightlife'),
  shopping('shopping'),
  adventure('adventure');

  const TravelStyle(this.wire);

  final String wire;

  static TravelStyle? from(Object? value) => _lookup(values, value);
}

/// Trip pace, which decides how many stops a day holds.
enum TripIntensity {
  slowLife('slow_life', 3, 4),
  chill('chill', 5, 6),
  balance('balance', 8, 8),
  active('active', 9, 11),
  hardcore('hardcore', 12, 16);

  const TripIntensity(this.wire, this.minItemsPerDay, this.maxItemsPerDay);

  final String wire;
  final int minItemsPerDay;
  final int maxItemsPerDay;

  static TripIntensity? from(Object? value) => _lookup(values, value);
}

/// An accessibility or group constraint. These *beat* [TripIntensity]: pairing
/// `hardcore` with `wheelchair` yields 6 stops a day, not 12–16.
enum TripConstraint {
  seniors('seniors', 7),
  wheelchair('wheelchair', 6),
  limitedWalking('limited_walking', 6),
  youngChildren('young_children', 7);

  const TripConstraint(this.wire, this.maxItemsPerDay);

  final String wire;

  /// The ceiling this constraint imposes on stops per day.
  final int maxItemsPerDay;

  static TripConstraint? from(Object? value) => _lookup(values, value);
}

/// Budget per person per day in THB, excluding accommodation.
enum BudgetTier {
  economy('economy', 0, 1000),
  comfort('comfort', 1000, 5000),
  premium('premium', 5000, 10000),
  luxury('luxury', 10000, null),

  /// Requires `amountPerPersonPerDay` alongside it.
  custom('custom', null, null);

  const BudgetTier(this.wire, this.minPerPersonPerDay, this.maxPerPersonPerDay);

  final String wire;
  final double? minPerPersonPerDay;

  /// `null` on [luxury] (no ceiling) and on [custom] (caller-specified).
  final double? maxPerPersonPerDay;

  static BudgetTier? from(Object? value) => _lookup(values, value);
}

enum GroupType {
  solo('solo'),
  couple('couple'),
  family('family'),
  friends('friends'),
  business('business');

  const GroupType(this.wire);

  final String wire;

  static GroupType? from(Object? value) => _lookup(values, value);
}

enum AccommodationStatus {
  booked('booked'),
  notBooked('not_booked');

  const AccommodationStatus(this.wire);

  final String wire;

  static AccommodationStatus? from(Object? value) => _lookup(values, value);
}

/// A price bracket for accommodation. Orthogonal to [HotelStyle].
enum HotelGrade {
  hostel('hostel'),
  budget('budget'),
  midscale('midscale'),
  upscale('upscale'),
  luxury('luxury');

  const HotelGrade(this.wire);

  final String wire;

  static HotelGrade? from(Object? value) => _lookup(values, value);
}

/// A kind of accommodation. `hostel` appears here and in [HotelGrade] on
/// purpose — they answer different questions ("not a resort" vs "cheap").
enum HotelStyle {
  boutique('boutique'),
  resort('resort'),
  hotel('hotel'),
  homestay('homestay'),
  villa('villa'),
  hostel('hostel');

  const HotelStyle(this.wire);

  final String wire;

  static HotelStyle? from(Object? value) => _lookup(values, value);
}

enum DateMode {
  /// Real calendar dates.
  fixed('fixed'),

  /// A number of days, no dates yet.
  flexible('flexible');

  const DateMode(this.wire);

  final String wire;

  static DateMode? from(Object? value) => _lookup(values, value);
}

/// Where a media item came from.
enum MediaSource {
  userUpload('user_upload'),
  place('place'),
  activity('activity'),
  destination('destination'),
  systemDefault('system_default');

  const MediaSource(this.wire);

  final String wire;

  static MediaSource? from(Object? value) => _lookup(values, value);
}

/// Share links are read-only; this is the only member today.
enum ShareAccessLevel {
  view('view');

  const ShareAccessLevel(this.wire);

  final String wire;

  static ShareAccessLevel? from(Object? value) => _lookup(values, value);
}

/// Where a line in the budget summary came from.
enum BudgetItemSource {
  activity('activity'),
  travel('travel'),
  accommodation('accommodation'),
  expense('expense');

  const BudgetItemSource(this.wire);

  final String wire;

  static BudgetItemSource? from(Object? value) => _lookup(values, value);
}

/// Severity of a plan-generation violation.
enum ViolationSeverity {
  error('error'),
  warning('warning');

  const ViolationSeverity(this.wire);

  final String wire;

  static ViolationSeverity? from(Object? value) => _lookup(values, value);
}

T? _lookup<T>(List<T> values, Object? value) {
  if (value == null) return null;
  final wanted = value is String ? value : '$value';
  for (final candidate in values) {
    if ((candidate as dynamic).wire == wanted) return candidate;
  }
  return null;
}

/// `['culture', 'food']` -> `[TravelStyle.culture, TravelStyle.food]`,
/// skipping anything this build does not know about.
List<T> parseEnumList<T>(Object? value, T? Function(Object?) parse) {
  if (value is! List) return <T>[];
  final parsed = <T>[];
  for (final entry in value) {
    final item = parse(entry);
    if (item != null) parsed.add(item);
  }
  return parsed;
}

/// Wire values for a list of enums, or `null` when the list is empty so the
/// key can be omitted from a request body.
List<String>? wireList<T>(Iterable<T>? values) {
  if (values == null) return null;
  final wire = values
      .map((value) => (value as dynamic).wire as String)
      .toList(growable: false);
  return wire.isEmpty ? null : wire;
}
