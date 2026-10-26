import '../../core/api/pluno_api.dart';

/// Everything a wall of cards can actually print.
///
/// A Puntok is a clip, not something a card can show: it has no days, no
/// budget and no places, and its cover is a video rather than an image. The
/// Puntok tab reads those with its own request and its own full-screen player.
///
/// **Two tests, because the wire does not say it outright.** `TripType.puntok`
/// exists in the client but the server does not use it yet — checked against a
/// live feed on 2026-10-21, where a clip comes back as `type: "content"` with
/// a `mediaType: "video"` cover. The cover is therefore the test that works
/// today, and the type is the one that will work once the server ships it;
/// keeping both means neither release has to be timed against the other.
///
/// Filtered here rather than in the query because `type` names the one kind to
/// keep, and a card wall wants whatever is left — there is no "everything but"
/// on the endpoint. Both Home's feed and the ไปกัน board run every row through
/// this, so the rule lives once.
List<TripListItem> withoutClips(List<TripListItem> trips) =>
    List<TripListItem>.unmodifiable(trips.where((trip) => !trip.isClip));

/// The other half of [withoutClips], for the walls that want *only* clips —
/// the Puntok tab on a traveller's own profile. Same two tests, so the two
/// halves can never drift apart.
List<TripListItem> onlyClips(List<TripListItem> trips) =>
    List<TripListItem>.unmodifiable(trips.where((trip) => trip.isClip));

/// Whether a row is a Puntok clip rather than something a card wall can
/// print. Public because the walls now draw clips too, with their own card.
extension ClipRow on TripListItem {
  bool get isClip => type == TripType.puntok || (coverImage?.isVideo ?? false);
}
