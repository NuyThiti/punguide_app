import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/post_draft.dart';
import '../../domain/services/trip_photo_grouper.dart';
import '../providers/place_pin_providers.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../../shared/widgets/full_image_viewer.dart';
import 'create_from_photos_sheet.dart'
    show PhotoImportSelection, ResolvedPlaceRow;
import 'photo_source_sheet.dart';
import 'place_pin_picker.dart';
import 'post_block.dart' show PostDashedBorder;

/// What the traveller chose on the review screen, once the photos they
/// picked from the create sheet are in front of them: have the assistant
/// write the post, or write it themselves — either way with the same photos
/// and place.
class PostReviewChoice {
  const PostReviewChoice({required this.selection, required this.useAi});
  final PhotoImportSelection selection;
  final bool useAi;
}

/// The screen between picking photos for a brand-new PunGuide and the
/// composer itself — "New PunGuide" review: the same photo review the AI
/// import page offers (main photo, zoom, thumbnails, add more), but ending
/// in a choice of who writes the post rather than one single CTA.
///
/// Returns null if the traveller backs out with no photos left.
Future<PostReviewChoice?> showPostPhotoReviewScreen(
  BuildContext context, {
  required ImagePicker picker,
  required List<XFile> initialPhotos,
}) =>
    Navigator.of(context).push<PostReviewChoice>(
      MaterialPageRoute(
        builder: (_) => _PostPhotoReviewPage(
          picker: picker,
          initialPhotos: initialPhotos,
        ),
      ),
    );

class _PostPhotoReviewPage extends ConsumerStatefulWidget {
  const _PostPhotoReviewPage({
    required this.picker,
    required this.initialPhotos,
  });

  final ImagePicker picker;
  final List<XFile> initialPhotos;

  @override
  ConsumerState<_PostPhotoReviewPage> createState() =>
      _PostPhotoReviewPageState();
}

class _PostPhotoReviewPageState extends ConsumerState<_PostPhotoReviewPage> {
  late final _photos = widget.initialPhotos.map((file) => (file: file, camera: false)).toList();
  final Map<String, TripPhoto> _metadata = {};
  PostPlace? _place;
  int _mainIndex = 0;
  int? _coverIndex;
  double _zoom = 1;
  bool _picking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _readMetadataAndMaybeSuggestPlace(widget.initialPhotos);
    });
  }

  Future<void> _addPhotos() async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final files = source == ImageSource.camera
          ? [await widget.picker.pickImage(source: source)]
              .whereType<XFile>()
              .toList()
          : await widget.picker.pickMultiImage();
      if (!mounted) return;
      final fresh = files
          .where((file) => !_photos.any((p) => p.file.path == file.path))
          .toList();
      if (_photos.length + fresh.length > 200) {
        setState(() => _error =
            'เพิ่มได้อีก ${200 - _photos.length} รูป (สูงสุด 200 รูปต่อโพสต์)');
        return;
      }
      setState(() {
        for (final file in fresh) {
          _photos.add((file: file, camera: source == ImageSource.camera));
        }
      });
      await _readMetadataAndMaybeSuggestPlace(fresh);
    } catch (_) {
      if (mounted) setState(() => _error = 'เลือกรูปไม่สำเร็จ กรุณาลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// The same EXIF-then-nearby-place lookup the AI import page runs, so a
  /// photo's own GPS offers a place here just as readily as it does there.
  Future<void> _readMetadataAndMaybeSuggestPlace(List<XFile> fresh) async {
    TripPhoto? located;
    for (final file in fresh) {
      try {
        final bytes = await file.readAsBytes();
        final photo = await compute(_readPhoto, (bytes, file.path));
        _metadata[file.path] = photo;
        located ??= photo.hasLocation ? photo : null;
      } catch (_) {
        // No metadata for this one; the rest still get a chance.
      }
    }
    if (!mounted || _place != null || located == null) return;
    try {
      final api = await ref.read(plunoApiProvider.future);
      final nearby = await api.places.suggest(
        latitude: located.latitude!,
        longitude: located.longitude!,
        radiusMeters: 150,
        limit: 1,
      );
      if (!mounted || _place != null || nearby.isEmpty) return;
      setState(() => _place = postPlaceFromSearchResult(nearby.first));
    } catch (_) {
      // Still just a hint; no worse than the photo carrying no GPS at all.
    }
  }

  Future<void> _pickLocation() async {
    final place = await showPlacePinPicker(context, hasPlace: _place != null);
    if (!mounted || place == null) return;
    setState(() => _place = place == clearedPlacePin ? null : place);
  }

  void _removePhoto(int index) {
    setState(() {
      final removed = _photos.removeAt(index);
      _metadata.remove(removed.file.path);
      if (_coverIndex != null) {
        if (_coverIndex == index) {
          _coverIndex = null;
        } else if (_coverIndex! > index) {
          _coverIndex = _coverIndex! - 1;
        }
      }
      if (_mainIndex >= _photos.length) {
        _mainIndex = _photos.isEmpty ? 0 : _photos.length - 1;
      }
      _zoom = 1;
    });
    // Nothing left to review — back to wherever the picker was opened from.
    if (_photos.isEmpty && mounted) Navigator.of(context).pop();
  }

  void _selectMain(int index) {
    setState(() {
      _mainIndex = index;
      _zoom = 1;
    });
  }

  /// Marks the photo on screen as the post's cover — cosmetic here, just a
  /// badge on its thumbnail; the composer still resolves its own cover the
  /// way it always has once the post is actually being written.
  void _markCover() => setState(() => _coverIndex = _mainIndex);

  void _finish(bool useAi) {
    if (_photos.isEmpty) return;
    Navigator.of(context).pop(PostReviewChoice(
      selection: PhotoImportSelection(
        _photos.map((p) => p.file).toList(),
        _place,
        _photos.every((p) => p.camera),
      ),
      useAi: useAi,
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.screen,
        body: Column(
          children: [
            _ReviewHeader(
              onBack: () => Navigator.of(context).pop(),
              onSetCover: _photos.isEmpty ? null : _markCover,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child:
                          ResolvedPlaceRow(place: _place, onTap: _pickLocation),
                    ),
                    const SizedBox(height: 12),
                    _FullBleedPhoto(
                      path: _photos[_mainIndex].file.path,
                      zoom: _zoom,
                      onDelete: () => _removePhoto(_mainIndex),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _ZoomRow(
                        zoom: _zoom,
                        onZoomChanged: (value) => setState(() => _zoom = value),
                        onReset: () => setState(() => _zoom = 1),
                        onFullScreen: () => showFullImages(
                          context,
                          urls: _photos.map((p) => p.file.path).toList(),
                          initialIndex: _mainIndex,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PhotoStrip(
                      paths: _photos.map((p) => p.file.path).toList(),
                      selected: _mainIndex,
                      adding: _picking,
                      onAdd: _addPhotos,
                      onSelect: _selectMain,
                      onDelete: _removePhoto,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
            ),
            _ReviewActionBar(
              hasPhotos: _photos.isNotEmpty,
              onUseAi: () => _finish(true),
              onUseManual: () => _finish(false),
            ),
          ],
        ),
      );
}

Future<TripPhoto> _readPhoto((Uint8List, String) input) =>
    readTripPhoto(input.$1, input.$2);

/// The photo on screen, edge to edge on black — letterboxed rather than
/// cropped, so the traveller sees the whole of what they picked before
/// zooming in on it.
class _FullBleedPhoto extends StatelessWidget {
  const _FullBleedPhoto({
    required this.path,
    required this.zoom,
    required this.onDelete,
  });

  final String path;
  final double zoom;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.1,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            Transform.scale(
              scale: zoom,
              child: CoverImage(source: path, fit: BoxFit.contain),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: _DeleteButton(
                tooltip: 'ลบรูปนี้',
                size: 52,
                iconHeight: 26,
                onTap: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fit-to-frame on the left, the zoom slider, then full screen and reset.
class _ZoomRow extends StatelessWidget {
  const _ZoomRow({
    required this.zoom,
    required this.onZoomChanged,
    required this.onReset,
    required this.onFullScreen,
  });

  final double zoom;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onReset;
  final VoidCallback onFullScreen;

  static const _minZoom = 1.0, _maxZoom = 2.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'จัดกึ่งกลาง',
          onPressed: onReset,
          icon: const Icon(Icons.zoom_in_map, color: AppColors.foreground),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              activeTrackColor: AppColors.postPurple,
              inactiveTrackColor: AppColors.postDraftBg,
              thumbColor: Colors.white,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const _RingThumb(),
            ),
            child: Slider(
              value: zoom.clamp(_minZoom, _maxZoom),
              min: _minZoom,
              max: _maxZoom,
              onChanged: onZoomChanged,
            ),
          ),
        ),
        IconButton(
          tooltip: 'ดูเต็มจอ',
          onPressed: onFullScreen,
          icon: const Icon(Icons.zoom_out_map, color: AppColors.foreground),
        ),
        _CircleAction(
          icon: Icons.refresh,
          tooltip: 'รีเซ็ตขนาด',
          size: 40,
          background: AppColors.postDraftBg,
          foreground: AppColors.foreground,
          onTap: onReset,
        ),
      ],
    );
  }
}

/// A white thumb ringed in the slider's own purple.
class _RingThumb extends SliderComponentShape {
  const _RingThumb();

  static const _radius = 12.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, _radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      _radius - 1.5,
      Paint()
        ..color = AppColors.postPurple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

/// Every photo picked so far, led by a dashed tile that adds more — tap a
/// photo to bring it up front, or its own badge to drop it.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.paths,
    required this.selected,
    required this.adding,
    required this.onAdd,
    required this.onSelect,
    required this.onDelete,
  });

  final List<String> paths;
  final int selected;
  final bool adding;
  final VoidCallback onAdd;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onDelete;

  static const _tile = 104.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _tile,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: paths.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) return _AddTile(busy: adding, onTap: onAdd);
          final photo = index - 1;
          return GestureDetector(
            onTap: () => onSelect(photo),
            child: Container(
              width: _tile,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: photo == selected
                    ? Border.all(color: AppColors.postPurple, width: 2)
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(source: paths[photo]),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _DeleteButton(
                      tooltip: 'ลบรูปที่ ${photo + 1}',
                      size: 30,
                      iconHeight: 18,
                      onTap: () => onDelete(photo),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'เพิ่มรูป',
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: const PostDashedBorder(
              color: AppColors.postDashed, radius: 12),
          child: SizedBox.square(
            dimension: _PhotoStrip._tile,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.postPurple),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined,
                      size: 40, color: AppColors.postPurple),
            ),
          ),
        ),
      ),
    );
  }
}

/// The red trash glyph straight on the photo — no well behind it.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.tooltip,
    required this.size,
    required this.iconHeight,
    required this.onTap,
  });

  final String tooltip;
  final double size;
  final double iconHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: SvgPicture.asset('assets/icons/delete.svg',
                  height: iconHeight),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final double size;
  final Color background, foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: size * 0.55, color: foreground),
          ),
        ),
      ),
    );
  }
}

/// The plain (not the AI import page's gradient) cap this screen wears: back,
/// "New PunGuide", and a "Cover" action on the right instead of "add photo" —
/// adding more photos already has its own dashed button lower on the page.
class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.onBack, required this.onSetCover});

  final VoidCallback onBack;
  final VoidCallback? onSetCover;

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
                Material(
                  color: AppColors.postField,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: onSetCover,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_outlined,
                              size: 18, color: AppColors.foreground),
                          SizedBox(width: 6),
                          Text(
                            'Cover',
                            style: TextStyle(
                              color: AppColors.foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar pinned to the bottom: "ให้ AI สร้างโพสจากรูป" over "ฉันสร้างโพสเอง" —
/// the one fork in the road this screen exists for.
class _ReviewActionBar extends StatelessWidget {
  const _ReviewActionBar({
    required this.hasPhotos,
    required this.onUseAi,
    required this.onUseManual,
  });

  final bool hasPhotos;
  final VoidCallback onUseAi;
  final VoidCallback onUseManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.screen,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Opacity(
        opacity: hasPhotos ? 1 : 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // เพิ่มตรงนี้
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.postImportStart,
                    AppColors.postImportMid,
                    AppColors.postImportMid2,
                    AppColors.postImportEnd,
                  ],
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hasPhotos ? onUseAi : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'ให้ AI สร้างโพสจากรูป',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.black,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: hasPhotos ? onUseManual : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Text(
                    'ฉันสร้างโพสเอง',
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
          ],
        ),
      ),
    );
  }
}
