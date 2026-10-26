import '../domain/album.dart';

/// Stand-in albums until the API has an endpoint for them.
///
/// Kept in one place and behind [albumsFor] so the tab reads the same way it
/// will once a provider replaces this — see `Album`.
const _personal = <Album>[
  Album(
    id: 'album-old-town',
    title: 'มุมถ่ายรูปย่านเมืองเก่า',
    cover: 'assets/images/puntok_beijing.jpg',
  ),
  Album(
    id: 'album-yaowarat-food',
    title: 'ของอร่อยเยาวราช',
    cover: 'assets/images/puntok_osaka.jpg',
  ),
  Album(
    id: 'album-lanterns',
    title: 'สายมูห้ามพลาด',
    cover: 'assets/images/puntok_seoul.jpg',
  ),
  Album(
    id: 'album-bangkok-night',
    title: 'ทรงวาดวันชิลๆ ลองเก็บมุมสวย',
    cover: 'assets/images/puntok_london.jpg',
  ),
];

const _shared = <Album>[
  Album(
    id: 'album-trip-with-friends',
    title: 'ทริปกับเพื่อน',
    cover: 'assets/images/puntok_london.jpg',
  ),
];

List<Album> albumsFor(AlbumShelf shelf) => switch (shelf) {
      AlbumShelf.personal => _personal,
      AlbumShelf.shared => _shared,
    };
