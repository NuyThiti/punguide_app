import '../domain/models/puntok_post.dart';

/// Stand-in feed for Puntok.
///
/// The first entry is the Figma board's card verbatim — same creator, caption
/// and counts — so the screen can be checked against the design. The rest are
/// written to their own footage.
const puntokMockPosts = <PuntokPost>[
  PuntokPost(
    id: 'puntok-1',
    video: 'assets/videos/puntok_osaka.mp4',
    poster: 'assets/images/puntok_osaka.jpg',
    author: 'TravelWithTawn',
    authorAvatar: 'assets/images/puntok_avatar_1.jpg',
    caption: 'เที่ยวหลวงพระบาง 3 วัน ชิลล์ๆ',
    likes: 5597,
    comments: 5,
    saves: 39,
    shares: 126,
  ),
  PuntokPost(
    id: 'puntok-2',
    video: 'assets/videos/puntok_beijing.mp4',
    poster: 'assets/images/puntok_beijing.jpg',
    author: 'NamPloyWalks',
    authorAvatar: 'assets/images/puntok_avatar_2.jpg',
    caption: 'เดินเขาเช้าตรู่ชานเมืองปักกิ่ง 2 วัน',
    likes: 12840,
    comments: 214,
    saves: 908,
    shares: 331,
    following: true,
  ),
  PuntokPost(
    id: 'puntok-3',
    video: 'assets/videos/puntok_seoul.mp4',
    poster: 'assets/images/puntok_seoul.jpg',
    author: 'SeoulSoGood',
    authorAvatar: 'assets/images/puntok_avatar_1.jpg',
    caption: 'ใส่ฮันบกเดินพระราชวัง โซล 4 วัน ใบไม้เปลี่ยนสี',
    likes: 48219,
    comments: 1302,
    saves: 6754,
    shares: 2180,
    liked: true,
  ),
  PuntokPost(
    id: 'puntok-4',
    video: 'assets/videos/puntok_london.mp4',
    poster: 'assets/images/puntok_london.jpg',
    author: 'MoWanders',
    authorAvatar: 'assets/images/puntok_avatar_2.jpg',
    caption: 'ลอนดอน 5 วัน งบ 30,000 ไม่เกินจริง',
    likes: 903,
    comments: 46,
    saves: 128,
    shares: 57,
    saved: true,
  ),
];
