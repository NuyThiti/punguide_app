import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/photo_manager_library_source.dart';
import '../../domain/services/photo_library_source.dart';

/// The photo-first PunGuide entry's own picker: our header and CTA wrapped
/// around a grid read straight from the device library (through
/// [PhotoLibrarySource]) instead of handing off to the bare OS picker sheet.
///
/// Returns null when the traveller backs out or access never came through;
/// otherwise the photos picked, in the order they were tapped.
Future<List<XFile>?> showPhotoLibraryPicker(
  BuildContext context, {
  PhotoLibrarySource? source,
}) =>
    Navigator.of(context).push<List<XFile>>(
      MaterialPageRoute(
        builder: (_) =>
            _PhotoLibraryPickerPage(source ?? const PhotoManagerLibrarySource()),
      ),
    );

enum _LoadState { loading, denied, error, ready }

/// A photo just shot with the camera tile — never came from the library, so
/// it wraps the picker's own [XFile] directly rather than an [AssetEntity].
class _CapturedAsset implements GalleryAsset {
  _CapturedAsset(this._file);
  final XFile _file;

  @override
  String get id => _file.path;

  @override
  Future<Uint8List?> thumbnail() async {
    try {
      return await _file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<XFile?> toXFile() async => _file;
}

class _PhotoLibraryPickerPage extends StatefulWidget {
  const _PhotoLibraryPickerPage(this.source);
  final PhotoLibrarySource source;

  @override
  State<_PhotoLibraryPickerPage> createState() =>
      _PhotoLibraryPickerPageState();
}

class _PhotoLibraryPickerPageState extends State<_PhotoLibraryPickerPage> {
  _LoadState _state = _LoadState.loading;
  List<GalleryAsset> _assets = const [];

  /// In the order each was tapped — the first is what the big preview
  /// shows, and the grid's own numbered badges read straight off this.
  final List<GalleryAsset> _selected = [];
  final Map<String, Uint8List?> _thumbnails = {};
  final _picker = ImagePicker();
  bool _finishing = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final granted = await widget.source
          .requestAccess()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (!granted) {
        setState(() => _state = _LoadState.denied);
        return;
      }
      final assets = await widget.source
          .recentPhotos()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _state = _LoadState.ready;
      });
    } catch (_) {
      // Never leave the spinner spinning forever — a broken platform call
      // (the plugin missing from a build that predates it, a transient
      // native error) ends in a message and a retry, not a dead screen.
      if (mounted) setState(() => _state = _LoadState.error);
    }
  }

  Future<Uint8List?> _thumbnailFor(GalleryAsset asset) async {
    final cached = _thumbnails[asset.id];
    if (cached != null) return cached;
    final bytes = await asset.thumbnail();
    if (mounted) _thumbnails[asset.id] = bytes;
    return bytes;
  }

  /// The camera tile — shoots one photo, adds it to the grid already
  /// selected (it becomes the live preview, same as tapping any other tile
  /// first), rather than requiring a second tap to pick what was just taken.
  Future<void> _openCamera() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (!mounted || photo == null) return;
      final asset = _CapturedAsset(photo);
      setState(() {
        _assets = [asset, ..._assets];
        _selected.insert(0, asset);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('เปิดกล้องไม่สำเร็จ ลองอีกครั้ง')));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _toggle(GalleryAsset asset) {
    setState(() {
      final existing =
          _selected.indexWhere((selected) => selected.id == asset.id);
      if (existing >= 0) {
        _selected.removeAt(existing);
      } else {
        _selected.add(asset);
      }
    });
  }

  Future<void> _finish() async {
    if (_selected.isEmpty || _finishing) return;
    setState(() => _finishing = true);
    final files = <XFile>[];
    for (final asset in _selected) {
      final file = await asset.toXFile();
      if (file != null) files.add(file);
    }
    if (!mounted) return;
    if (files.isEmpty) {
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('เลือกรูปไม่สำเร็จ กรุณาลองอีกครั้ง')));
      return;
    }
    Navigator.of(context).pop(files);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screen,
      body: Column(
        children: [
          _PickerHeader(onBack: () => Navigator.of(context).pop()),
          Expanded(child: _buildBody()),
          if (_state == _LoadState.ready)
            _PickerNextBar(
              enabled: _selected.isNotEmpty && !_finishing,
              onNext: _finish,
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.denied:
        return const _AccessDenied();
      case _LoadState.error:
        return _LoadError(onRetry: _load);
      case _LoadState.ready:
        return Column(
          children: [
            if (_selected.isNotEmpty)
              _LivePreview(asset: _selected.first, loader: _thumbnailFor),
            const _AlbumRow(),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(2),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                // The camera tile is always first, ahead of whatever the
                // library has — a traveller with an empty library still
                // needs some way to get a photo into the post at all.
                itemCount: _assets.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _CameraTile(
                        busy: _capturing, onTap: _openCamera);
                  }
                  final asset = _assets[index - 1];
                  final order = _selected
                      .indexWhere((selected) => selected.id == asset.id);
                  return _GalleryTile(
                    key: ValueKey('photo-picker-tile-${asset.id}'),
                    loader: () => _thumbnailFor(asset),
                    selectionNumber: order < 0 ? null : order + 1,
                    onTap: () => _toggle(asset),
                  );
                },
              ),
            ),
          ],
        );
    }
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.screen,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                Tooltip(
                  message: 'ย้อนกลับ',
                  child: Material(
                    color: AppColors.postField,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onBack,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.chevron_left,
                            color: AppColors.foreground),
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'New PunGuide',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The big edge-to-edge photo above the grid — whichever was tapped first,
/// so the traveller always sees the one the rest are gathering around.
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.asset, required this.loader});

  final GalleryAsset asset;
  final Future<Uint8List?> Function(GalleryAsset asset) loader;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: FutureBuilder<Uint8List?>(
        key: ValueKey(asset.id),
        future: loader(asset),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return const ColoredBox(color: Colors.black12);
          return Image.memory(bytes, fit: BoxFit.cover);
        },
      ),
    );
  }
}

/// A plain stand-in for the native picker's own album switcher and Cancel —
/// this picker only ever reads one album (ล่าสุด/Recents) for now, so
/// "Recents" is a label rather than a real menu.
class _AlbumRow extends StatelessWidget {
  const _AlbumRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Recents',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(Icons.expand_more, color: AppColors.muted),
            ],
          ),
          Material(
            color: AppColors.postField,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The grid's own first tile — a plain camera glyph on black, same spot the
/// reference keeps it in ahead of every library photo.
class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.add_a_photo_outlined,
                  color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    super.key,
    required this.loader,
    required this.selectionNumber,
    required this.onTap,
  });

  final Future<Uint8List?> Function() loader;
  final int? selectionNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectionNumber != null;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: loader(),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) {
                return const ColoredBox(color: Colors.black12);
              }
              return Image.memory(bytes, fit: BoxFit.cover);
            },
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.postPurple : Colors.white70,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: selected
                  ? Text(
                      '$selectionNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerNextBar extends StatelessWidget {
  const _PickerNextBar({required this.enabled, required this.onNext});

  final bool enabled;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        9,
        6,
        9,
        6 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.screen,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: Colors.black,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onNext : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Text(
                'ต่อไป',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'ให้สิทธิ์เข้าถึงรูปภาพก่อนเพื่อเลือกรูปสำหรับโพสต์',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      ),
    );
  }
}

/// A broken platform call (the plugin missing from a build that predates
/// it, a one-off native hiccup) — a message and a retry, never a spinner
/// stuck turning forever.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'เปิดคลังภาพไม่สำเร็จ กรุณาลองอีกครั้ง',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }
}
