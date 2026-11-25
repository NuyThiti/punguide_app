import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/photo_manager_library_source.dart';
import '../../domain/services/photo_library_source.dart';

/// The photo-first PunGuide picker's source — the real device library in
/// production, a fixed list in tests that override this provider instead of
/// stubbing `photo_manager`'s own method channel.
final photoLibrarySourceProvider = Provider<PhotoLibrarySource>(
  (ref) => const PhotoManagerLibrarySource(),
);
