import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// One photo in the device library — abstracted behind [PhotoLibrarySource]
/// so the picker screen never touches `photo_manager`'s own `AssetEntity`
/// directly, and a test can stand a fixed list in for the real library.
abstract class GalleryAsset {
  /// Stable across the session — never the list position, which changing
  /// selection order must not disturb.
  String get id;

  /// A small preview for the grid tile and the live main preview; null when
  /// the device could not produce one (an iCloud photo still downloading, a
  /// corrupt file).
  Future<Uint8List?> thumbnail();

  /// The real file, read only once the traveller actually taps "ต่อไป" —
  /// this can be slow (an iCloud download) so the grid itself never calls it
  /// just to draw a tile.
  Future<XFile?> toXFile();
}

/// Where the photo-first PunGuide picker's photos come from.
abstract class PhotoLibrarySource {
  /// Asks for photo library access. `true` for both full and limited access
  /// — a limited grant still lets the traveller choose from what they
  /// picked, the same as the OS's own picker would.
  Future<bool> requestAccess();

  /// The most recent photos, newest first.
  Future<List<GalleryAsset>> recentPhotos({int limit = 120});
}
