import 'trip_content.dart';
import 'package:flutter/foundation.dart';

import 'day.dart';
import 'destination_place.dart';
import 'enums.dart';
import 'json.dart';
import 'media.dart';
import 'schedule.dart';

/// The preference brief behind a trip, echoed back exactly as it was sent —
/// good for rendering chips under the title.
///
/// Head count, budget tier, budget cap and dates are *not* here; they have
/// their own columns on the trip.
@immutable
class TripPlanBrief {
  const TripPlanBrief({
    this.styles = const <TravelStyle>[],
    this.customStyles = const <String>[],
    this.intensity,
    this.transport = const <TransportMode>[],
    this.customTransport = const <String>[],
    this.constraints = const <TripConstraint>[],
    this.customConstraints = const <String>[],
    this.groupType,
  });

  factory TripPlanBrief.fromJson(Map<String, dynamic> json) => TripPlanBrief(
        styles: parseEnumList(json['styles'], TravelStyle.from),
        customStyles: Json.stringList(json, 'customStyles'),
        intensity: TripIntensity.from(json['intensity']),
        transport: parseEnumList(json['transport'], TransportMode.from),
        customTransport: Json.stringList(json, 'customTransport'),
        constraints: parseEnumList(json['constraints'], TripConstraint.from),
        customConstraints: Json.stringList(json, 'customConstraints'),
        groupType: GroupType.from(json['groupType']),
      );

  static TripPlanBrief? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return TripPlanBrief.fromJson(json);
  }

  final List<TravelStyle> styles;
  final List<String> customStyles;
  final TripIntensity? intensity;
  final List<TransportMode> transport;
  final List<String> customTransport;
  final List<TripConstraint> constraints;
  final List<String> customConstraints;
  final GroupType? groupType;
}

/// Whoever made the trip, as shown on a feed card.
@immutable
class TripCreator {
  const TripCreator({required this.id, required this.name, this.avatarUrl});

  factory TripCreator.fromJson(Map<String, dynamic> json) => TripCreator(
        id: Json.requiredString(json, 'id'),
        name: Json.requiredString(json, 'name'),
        avatarUrl: Json.string(json, 'avatarUrl'),
      );

  static TripCreator? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return TripCreator.fromJson(json);
  }

  final String id;

  /// Falls back to the username when the account has no display name.
  final String name;
  final String? avatarUrl;
}

/// The owner of a full trip, with the head count the plan was built for.
@immutable
class TripCustomer {
  const TripCustomer({
    required this.id,
    required this.name,
    required this.groupSize,
    this.avatarUrl,
  });

  factory TripCustomer.fromJson(Map<String, dynamic> json) => TripCustomer(
        id: Json.requiredString(json, 'id'),
        name: Json.requiredString(json, 'name'),
        avatarUrl: Json.string(json, 'avatarUrl'),
        groupSize: Json.integer(json, 'groupSize') ?? 1,
      );

  static TripCustomer? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return TripCustomer.fromJson(json);
  }

  final String id;
  final String name;
  final String? avatarUrl;

  /// The trip's `numPeople`.
  final int groupSize;
}

/// The plan a post hangs off, trimmed to what the row under the post needs.
///
/// Absent from a response means "no plan to show", and deliberately covers
/// three cases at once: nothing was linked, the plan was deleted, or the
/// reader is not the owner and the plan is still private. Linking is not
/// publishing — a public post can point at a draft only its author can open.
@immutable
class LinkedTrip {
  const LinkedTrip({
    required this.id,
    required this.title,
    required this.schedule,
    required this.placeCount,
    this.coverImage,
  });

  factory LinkedTrip.fromJson(Map<String, dynamic> json) => LinkedTrip(
        id: Json.requiredString(json, 'id'),
        title: Json.requiredString(json, 'title'),
        schedule: Schedule.fromJson(Json.asMap(json['schedule'])),
        placeCount: Json.integer(json, 'placeCount') ?? 0,
        coverImage: Media.maybeFromJson(json['coverImage']),
      );

  static LinkedTrip? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return LinkedTrip.fromJson(json);
  }

  final String id;
  final String title;
  final Schedule schedule;
  final int placeCount;
  final Media? coverImage;
}

/// A trip as it appears in a list: the feed, "my trips", and saved trips.
///
/// Deliberately light — no days, no gallery. Open the card, then fetch the
/// full trip.
@immutable
class TripListItem {
  final TripType type;
  const TripListItem({
    this.type = TripType.planTrip,
    required this.id,
    required this.title,
    required this.destination,
    required this.status,
    required this.schedule,
    required this.totalBudget,
    required this.tags,
    this.budgetCurrency,
    this.placeCount = 0,
    this.description,
    required this.isSaved,
    required this.isLiked,
    required this.likeCount,
    required this.remixCount,
    required this.createdAt,
    required this.updatedAt,
    this.destinationPlace,
    this.budgetLimit,
    this.budgetTier,
    this.coverImage,
    this.creator,
    this.distanceKm,
  });

  factory TripListItem.fromJson(Map<String, dynamic> json) {
    final place = DestinationPlace.maybeFromJson(json['destinationPlace']);

    return TripListItem(
      type: TripType.from(json['type']),
      id: Json.requiredString(json, 'id'),
      title: Json.requiredString(json, 'title'),
      destination: Json.requiredString(json, 'destination'),
      destinationPlace: place,
      status: TripStatus.from(json['status']) ?? TripStatus.draft,
      schedule: Schedule.fromJson(Json.asMap(json['schedule'])),
      budgetLimit: Json.number(json, 'budgetLimit'),
      totalBudget: Json.number(json, 'totalBudget') ?? 0,
      budgetTier: BudgetTier.from(json['budgetTier']),
      tags: Json.stringList(json, 'tags'),
      coverImage: Media.maybeFromJson(json['coverImage']),
      budgetCurrency: Json.string(json, 'budgetCurrency'),
      placeCount: Json.integer(json, 'placeCount') ?? 0,
      description: Json.string(json, 'description'),
      isSaved: Json.boolean(json, 'isSaved'),
      isLiked: Json.boolean(json, 'isLiked'),
      likeCount: Json.integer(json, 'likeCount') ?? 0,
      remixCount: Json.integer(json, 'remixCount') ?? 0,
      creator: TripCreator.maybeFromJson(json['creator']),
      // Only present when the request carried both `lat` and `lng`; a trip
      // whose destination is still free text never gets one, so absent is
      // "unknown" rather than zero.
      //
      // Read only when the row actually has a resolved destination, which
      // is the documented condition for the field existing at all. Posts
      // come back without one yet carry `distanceKm: 20015` — π × the
      // Earth's radius, the maximum a great circle can be, which is what a
      // null pair measures to rather than a place anyone can travel to.
      // Dropping it here keeps that number off every card at once; take
      // this guard out once the server stops sending it.
      distanceKm: place?.hasCoordinates ?? false
          ? Json.number(json, 'distanceKm')
          : null,
      createdAt: Json.timestamp(json, 'createdAt') ?? DateTime.now(),
      updatedAt: Json.timestamp(json, 'updatedAt') ?? DateTime.now(),
    );
  }

  static List<TripListItem> listFrom(Object? value) =>
      Json.asMapList(value).map(TripListItem.fromJson).toList(growable: false);

  final String id;
  final String title;
  final String destination;
  final DestinationPlace? destinationPlace;
  final TripStatus status;
  final Schedule schedule;

  /// The cap the planner set, in THB. Absent means no budget was set — which
  /// is different from a budget of zero.
  final double? budgetLimit;

  /// ISO 4217. **Absent means THB** — the server never backfilled a currency
  /// onto trips whose owner did not choose one, and the stored amounts were
  /// always baht.
  final String? budgetCurrency;

  /// What the plan actually adds up to.
  final double totalBudget;
  final BudgetTier? budgetTier;

  /// Stops filed under a day on a plan, or located sections on a post. A trip
  /// with nothing in it answers 0, so a card can print it without a fallback.
  ///
  /// A plan's staging shelf — stops not yet on a day — is **not** counted.
  final int placeCount;

  /// The post's blurb, so a card can print it without opening the trip.
  final String? description;

  /// `styles` and `customStyles`, already merged for display.
  final List<String> tags;
  final Media? coverImage;

  /// Always false for an anonymous caller, even on a trip the user did save.
  final bool isSaved;
  final bool isLiked;
  final int likeCount;

  /// How many trips were remixed from this one.
  final int remixCount;
  final TripCreator? creator;

  /// Straight-line kilometres from the `lat`/`lng` the feed was asked for, as
  /// the server measured them. Null unless both were sent — and null, never 0,
  /// for a trip with no resolved destination.
  final double? distanceKm;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Echoes a save/unsave the server has accepted locally.
  ///
  /// `POST /trips/:id/save` returns nothing, so a list that wants to show the
  /// new bookmark state without re-reading the whole feed patches the one row.
  TripListItem withSaved(bool saved) => TripListItem(
        type: type,
        id: id,
        title: title,
        destination: destination,
        destinationPlace: destinationPlace,
        status: status,
        schedule: schedule,
        budgetLimit: budgetLimit,
        totalBudget: totalBudget,
        budgetTier: budgetTier,
        tags: tags,
        coverImage: coverImage,
        isSaved: saved,
        isLiked: isLiked,
        likeCount: likeCount,
        remixCount: remixCount,
        creator: creator,
        distanceKm: distanceKm,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// A full trip, including its itinerary.
///
/// Accommodations and expenses are *not* here — read them from
/// `GET /trips/:id/budget`.
@immutable
class ApiTrip {
  final TripType type;
  final List<TripContent> contents;
  const ApiTrip({
    this.type = TripType.planTrip,
    this.contents = const [],
    required this.id,
    required this.ownerId,
    required this.title,
    required this.destination,
    required this.status,
    required this.schedule,
    required this.totalBudget,
    required this.visibility,
    required this.remixCount,
    required this.mediaSummary,
    required this.isSaved,
    required this.isLiked,
    required this.likeCount,
    required this.days,
    required this.createdAt,
    required this.updatedAt,
    this.destinationPlace,
    this.budgetLimit,
    this.budgetTier,
    this.planMode,
    this.brief,
    this.customer,
    this.sourceTripId,
    this.publishedAt,
    this.coverImage,
    this.specialNotes,
    this.guestCount,
    this.budgetCurrency,
    this.placeCount = 0,
    this.linkedTrip,
    this.description,
  });

  factory ApiTrip.fromJson(Map<String, dynamic> json) => ApiTrip(
        type: TripType.from(json['type']),
        contents: TripContent.listFrom(json['contents']),
        id: Json.requiredString(json, 'id'),
        ownerId: Json.requiredString(json, 'ownerId'),
        title: Json.requiredString(json, 'title'),
        destination: Json.requiredString(json, 'destination'),
        destinationPlace:
            DestinationPlace.maybeFromJson(json['destinationPlace']),
        status: TripStatus.from(json['status']) ?? TripStatus.draft,
        schedule: Schedule.fromJson(Json.asMap(json['schedule'])),
        budgetLimit: Json.number(json, 'budgetLimit'),
        totalBudget: Json.number(json, 'totalBudget') ?? 0,
        budgetTier: BudgetTier.from(json['budgetTier']),
        planMode: PlanMode.from(json['planMode']),
        brief: TripPlanBrief.maybeFromJson(json['brief']),
        customer: TripCustomer.maybeFromJson(json['customer']),
        visibility:
            TripVisibility.from(json['visibility']) ?? TripVisibility.private,
        remixCount: Json.integer(json, 'remixCount') ?? 0,
        sourceTripId: Json.string(json, 'sourceTripId'),
        publishedAt: Json.timestamp(json, 'publishedAt'),
        coverImage: Media.maybeFromJson(json['coverImage']),
        // Owner-only: someone opening a public trip gets no key at all, so
        // null here means "not mine to read", not "the writer left it blank".
        specialNotes: Json.string(json, 'specialNotes'),
        description: Json.string(json, 'description'),
        guestCount: Json.integer(json, 'guestCount'),
        budgetCurrency: Json.string(json, 'budgetCurrency'),
        placeCount: Json.integer(json, 'placeCount') ?? 0,
        linkedTrip: LinkedTrip.maybeFromJson(json['linkedTrip']),
        mediaSummary: MediaSummary.fromJson(Json.asMap(json['mediaSummary'])),
        isSaved: Json.boolean(json, 'isSaved'),
        isLiked: Json.boolean(json, 'isLiked'),
        likeCount: Json.integer(json, 'likeCount') ?? 0,
        days: ItineraryDay.listFrom(json['days']),
        createdAt: Json.timestamp(json, 'createdAt') ?? DateTime.now(),
        updatedAt: Json.timestamp(json, 'updatedAt') ?? DateTime.now(),
      );

  final String id;
  final String ownerId;
  final String title;
  final String destination;
  final DestinationPlace? destinationPlace;
  final TripStatus status;
  final Schedule schedule;
  final double? budgetLimit;

  /// ISO 4217. **Absent means THB** — trips whose owner never chose a currency
  /// were not backfilled, and their amounts were always baht.
  final String? budgetCurrency;

  /// The head count the plan was built for, echoed back at the top level so a
  /// `type: content` post — which has no `customer` — can read it too.
  final int? guestCount;

  /// Stops on a day, or located sections on a post. Never absent — 0 means
  /// empty. A plan's unscheduled staging shelf is not counted.
  final int placeCount;

  /// The plan this post points at, when there is one the reader may see.
  final LinkedTrip? linkedTrip;

  /// The trip's own prose. **Owner only**: the public response leaves it out
  /// on purpose, since it often carries personal notes (allergies, mobility,
  /// small children).
  ///
  /// Not the post's blurb — that is [description], which everyone sees.
  final String? specialNotes;

  /// The blurb under the post's name, written for whoever reads it. Absent
  /// when none was written.
  final String? description;

  final double totalBudget;
  final BudgetTier? budgetTier;

  /// Absent on trips that predate the column.
  final PlanMode? planMode;

  /// Absent when the planner filled in no preferences at all.
  final TripPlanBrief? brief;
  final TripCustomer? customer;
  final TripVisibility visibility;
  final int remixCount;

  /// Set when this trip is itself a remix of another.
  final String? sourceTripId;

  /// Stamped the first time the trip goes public, and never cleared.
  final DateTime? publishedAt;
  final Media? coverImage;
  final MediaSummary mediaSummary;
  final bool isSaved;
  final bool isLiked;
  final int likeCount;

  /// Ordered by day number; empty, never null, before an itinerary exists.
  final List<ItineraryDay> days;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublic => visibility == TripVisibility.public;
}

/// The trip a remix was copied from.
@immutable
class SourceTripRef {
  const SourceTripRef({
    required this.id,
    required this.title,
    required this.ownerId,
    this.ownerDisplayName,
  });

  factory SourceTripRef.fromJson(Map<String, dynamic> json) => SourceTripRef(
        id: Json.requiredString(json, 'id'),
        title: Json.requiredString(json, 'title'),
        ownerId: Json.requiredString(json, 'ownerId'),
        ownerDisplayName: Json.string(json, 'ownerDisplayName'),
      );

  static SourceTripRef? maybeFromJson(Object? value) =>
      value is Map ? SourceTripRef.fromJson(Json.asMap(value)) : null;

  final String id;
  final String title;
  final String ownerId;
  final String? ownerDisplayName;
}

/// The result of remixing a trip: a private draft of your own.
///
/// A narrower shape than [ApiTrip] — no budget, media, or schedule. Fetch the
/// new trip by [id] for the full picture.
@immutable
class RemixedTrip {
  const RemixedTrip({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    required this.visibility,
    required this.days,
    required this.createdAt,
    this.planMode,
    this.sourceTrip,
  });

  factory RemixedTrip.fromJson(Map<String, dynamic> json) => RemixedTrip(
        id: Json.requiredString(json, 'id'),
        ownerId: Json.requiredString(json, 'ownerId'),
        title: Json.requiredString(json, 'title'),
        planMode: PlanMode.from(json['planMode']),
        status: TripStatus.from(json['status']) ?? TripStatus.draft,
        visibility:
            TripVisibility.from(json['visibility']) ?? TripVisibility.private,
        sourceTrip: SourceTripRef.maybeFromJson(json['sourceTrip']),
        days: ItineraryDay.listFrom(json['days']),
        createdAt: Json.timestamp(json, 'createdAt') ?? DateTime.now(),
      );

  final String id;
  final String ownerId;
  final String title;

  /// Always [PlanMode.remixed].
  final PlanMode? planMode;
  final TripStatus status;
  final TripVisibility visibility;
  final SourceTripRef? sourceTrip;

  /// Days and stops carry brand-new ids.
  final List<ItineraryDay> days;
  final DateTime createdAt;
}
