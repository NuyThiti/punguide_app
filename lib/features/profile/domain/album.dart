/// Which shelf of อัลบั้มของฉัน the sub-tabs are showing.
///
/// Personal is `GET /trips/mine?type=content,puntok`. Share has no endpoint
/// yet — the backend note that opened the Personal shelf says it was left out
/// of that round — so it is deliberately empty rather than mocked.
enum AlbumShelf { personal, shared }

/// The shelves the tab actually renders.
///
/// `shared` is left out rather than shown as a dead tab: the backend note
/// that opened Personal (`GET /trips/mine?type=content,puntok`) said Share
/// was cut from that round and has no endpoint. Add it back to this list the
/// day one exists — nothing else needs to change.
const visibleAlbumShelves = <AlbumShelf>[AlbumShelf.personal];

extension AlbumShelfLabel on AlbumShelf {
  String get label => switch (this) {
        AlbumShelf.personal => 'Personal',
        AlbumShelf.shared => 'Share',
      };
}
