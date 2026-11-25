import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../domain/services/photo_library_source.dart';

class _PhotoManagerAsset implements GalleryAsset {
  _PhotoManagerAsset(this._entity);
  final AssetEntity _entity;

  @override
  String get id => _entity.id;

  @override
  Future<Uint8List?> thumbnail() =>
      _entity.thumbnailDataWithSize(const ThumbnailSize.square(300));

  @override
  Future<XFile?> toXFile() async {
    final file = await _entity.file;
    return file == null ? null : XFile(file.path);
  }
}

/// The real device library, read through `photo_manager` — full access or
/// limited both count as "go ahead", matching how the OS itself treats a
/// limited grant as still letting the traveller pick from it.
class PhotoManagerLibrarySource implements PhotoLibrarySource {
  const PhotoManagerLibrarySource();

  @override
  Future<bool> requestAccess() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state == PermissionState.limited;
  }

  @override
  Future<List<GalleryAsset>> recentPhotos({int limit = 120}) async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) return const [];
    final assets =
        await albums.first.getAssetListPaged(page: 0, size: limit);
    return assets.map(_PhotoManagerAsset.new).toList(growable: false);
  }
}
