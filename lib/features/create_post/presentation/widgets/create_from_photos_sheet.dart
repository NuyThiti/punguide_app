import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../../shared/widgets/full_image_viewer.dart';
import '../../domain/models/post_draft.dart';
import '../../domain/services/trip_photo_grouper.dart';
import '../providers/place_pin_providers.dart';
import 'photo_source_sheet.dart';
import 'place_pin_picker.dart';

class PhotoImportSelection {
  const PhotoImportSelection(this.files, this.place, this.fromCamera);
  final List<XFile> files;
  final PostPlace? place;
  final bool fromCamera;
}

/// A full page, not a sheet (Figma 2480-80792 draws it taking over the whole
/// screen, its own dark cap in place of the composer's) — pushed the same
/// way any other composer step is.
///
/// The title is the composer's own `TextEditingController`, so typing here
/// writes straight into the same draft rather than a copy that would need
/// copying back. Who's posting and the audience stay off this screen —
/// there is nothing here for either to do.
Future<PhotoImportSelection?> showCreateFromPhotosSheet(
  BuildContext context, {
  required ImagePicker picker,
  required int remaining,
  required TextEditingController titleController,
}) =>
    Navigator.of(context).push<PhotoImportSelection>(
      MaterialPageRoute(
        builder: (_) => _PhotoImportPage(
          picker: picker,
          remaining: remaining,
          titleController: titleController,
        ),
      ),
    );

class _PhotoImportPage extends ConsumerStatefulWidget {
  const _PhotoImportPage({
    required this.picker,
    required this.remaining,
    required this.titleController,
  });
  final ImagePicker picker;
  final int remaining;
  final TextEditingController titleController;

  @override
  ConsumerState<_PhotoImportPage> createState() => _PhotoImportPageState();
}

class _PhotoImportPageState extends ConsumerState<_PhotoImportPage> {
  final _photos = <({XFile file, bool camera})>[];
  final Map<String, TripPhoto> _metadata = {};
  PostPlace? _place;
  int _mainIndex = 0;
  double _zoom = 1;
  bool _picking = false;
  String? _error;

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
      if (_photos.length + fresh.length > widget.remaining) {
        setState(() => _error =
            'เพิ่มได้อีก ${widget.remaining - _photos.length} รูป (สูงสุด 200 รูปต่อโพสต์)');
        return;
      }
      setState(() {
        for (final file in fresh) {
          if (!_photos.any((p) => p.file.path == file.path)) {
            _photos.add((file: file, camera: source == ImageSource.camera));
          }
        }
      });
      await _readMetadataAndMaybeSuggestPlace(fresh);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'เลือกรูปไม่สำเร็จ กรุณาลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Reads each fresh photo's own EXIF, then — the same lookup the main
  /// composer runs when a photo is added by hand — offers a nearby place the
  /// moment one of them turns out to carry GPS. Never overwrites an answer
  /// that already exists; a failed lookup just leaves the row unanswered.
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
      if (_mainIndex >= _photos.length) {
        _mainIndex = _photos.isEmpty ? 0 : _photos.length - 1;
      }
      _zoom = 1;
    });
  }

  void _selectMain(int index) {
    setState(() {
      _mainIndex = index;
      _zoom = 1;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.screen,
        body: Column(
          children: [
            _PhotoImportHeader(
                onBack: () => Navigator.pop(context), onAddPhotos: _addPhotos),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Just the title here — no account row, no audience
                    // chip: the composer's own identity card already owns
                    // those, and this page has nothing new to say about them.
                    _TitleField(controller: widget.titleController),
                    const SizedBox(height: 20),
                    if (_photos.isEmpty) ...[
                      const _EmptyPhotosIllustration(),
                      const SizedBox(height: 16),
                      const Text(
                        'เพิ่มรูป',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.postEmptyHeading,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ให้เราช่วยสร้างเรื่องราวการท่องเที่ยวของคุณ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.postEmptySubtitle,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Figma 2480-80792 has no location prompt before a
                      // photo is even picked — the place only ever shows up
                      // afterward, in `_ResolvedPlaceRow`, auto-suggested or
                      // picked by hand. The one "add a photo" action lives in
                      // the pinned bar now, so it is not repeated here too.
                    ] else ...[
                      _ResolvedPlaceRow(place: _place, onTap: _pickLocation),
                      const SizedBox(height: 12),
                      _MainPhotoPreview(
                        path: _photos[_mainIndex].file.path,
                        allPaths: _photos.map((p) => p.file.path).toList(),
                        index: _mainIndex,
                        zoom: _zoom,
                        onDelete: () => _removePhoto(_mainIndex),
                        onZoomChanged: (value) =>
                            setState(() => _zoom = value),
                        onReset: () => setState(() => _zoom = 1),
                      ),
                      const SizedBox(height: 12),
                      _ThumbnailStrip(
                        paths: _photos.map((p) => p.file.path).toList(),
                        selected: _mainIndex,
                        onSelect: _selectMain,
                        onDelete: _removePhoto,
                      ),
                      const SizedBox(height: 12),
                      _DashedAddPhotosButton(
                          busy: _picking, onTap: _picking ? null : _addPhotos),
                    ],
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ),
            _PublishBar(
              // Nothing to submit yet without a photo — rather than a CTA
              // sitting there disabled, the bar offers the one action that's
              // actually available until that changes.
              hasPhotos: _photos.isNotEmpty,
              busy: _picking,
              onAddPhotos: _addPhotos,
              onPublish: () => Navigator.pop(
                  context,
                  PhotoImportSelection(
                    _photos.map((p) => p.file).toList(),
                    _place,
                    _photos.every((p) => p.camera),
                  )),
            ),
          ],
        ),
      );
}

/// The dark cap this page wears instead of the composer's own — back, the
/// title naming the flow rather than the app, the same cover-photo action on
/// the right, and the AI button's own gradient run thin along the bottom
/// edge in place of the button itself (Figma 2480-80792: there is nowhere
/// left for that button to go once its own screen is what is showing).
class _PhotoImportHeader extends StatelessWidget {
  const _PhotoImportHeader({required this.onBack, required this.onAddPhotos});

  final VoidCallback onBack;
  final VoidCallback onAddPhotos;

  @override
  Widget build(BuildContext context) {
    // One rounded-bottom shape, not two stacked ones: the strip is this
    // shape's own gradient background, left uncovered for the last 6px so
    // the header's corner curve carries straight into it instead of butting
    // a second, separately-rounded bar underneath.
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredBox(
              color: AppColors.postImportHeroBg,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        Tooltip(
                          message: 'ย้อนกลับ',
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: onBack,
                              customBorder: const CircleBorder(),
                              child: const SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(Icons.chevron_left,
                                    color: AppColors.postImportHeroBg),
                              ),
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'AI สร้างโพสจากรูป',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.white24,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: onAddPhotos,
                            customBorder: const CircleBorder(),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.add_photo_alternate_outlined,
                                  size: 21, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

Future<TripPhoto> _readPhoto((Uint8List, String) input) =>
    readTripPhoto(input.$1, input.$2);

/// A plain title input — the same field style the Title sheet uses, minus
/// everything that sheet also does (activities, about, place). Bound
/// directly to the composer's own controller, so typing here needs no
/// separate save step to reach the draft.
class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 200,
      textInputAction: TextInputAction.done,
      style: const TextStyle(
        color: AppColors.foreground,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: 'Title..',
        hintStyle: const TextStyle(
          color: AppColors.postFieldHint,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: const Icon(Icons.edit_outlined,
            size: 20, color: AppColors.postPurple),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.chipBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.chipBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppColors.postPurple, width: 1.3),
        ),
      ),
    );
  }
}

/// The place row once photos exist — a plain row over a divider, reading
/// whatever `_place` currently holds (auto-suggested from a photo's GPS, or
/// picked by hand) rather than the bordered "Add Location" prompt above.
class _ResolvedPlaceRow extends StatelessWidget {
  const _ResolvedPlaceRow({required this.place, required this.onTap});

  final PostPlace? place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = place?.subtitle ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.postPurple),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place?.name ?? 'Add Location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 13),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Container(height: 2, color: Colors.black),
      ],
    );
  }
}

/// The one photo the traveller is looking at, with the zoom row underneath —
/// tap the corner icon for a real full-screen look, or the reset icon to
/// undo the pinch. The zoom itself is a plain scale, not a saved crop: there
/// is nowhere in the post's own data for a crop to live yet.
class _MainPhotoPreview extends StatelessWidget {
  const _MainPhotoPreview({
    required this.path,
    required this.allPaths,
    required this.index,
    required this.zoom,
    required this.onDelete,
    required this.onZoomChanged,
    required this.onReset,
  });

  final String path;
  final List<String> allPaths;
  final int index;
  final double zoom;
  final VoidCallback onDelete;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onReset;

  static const _minZoom = 1.0, _maxZoom = 2.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.black),
                Transform.scale(
                  scale: zoom,
                  child: CoverImage(source: path, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _RoundIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'ลบรูปนี้',
                    onTap: onDelete,
                    background: Colors.white,
                    foreground: AppColors.postShare,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _RoundIconButton(
              icon: Icons.center_focus_strong_outlined,
              tooltip: 'จัดกึ่งกลาง',
              onTap: onReset,
              background: AppColors.postField,
              foreground: AppColors.postRowIcon,
              size: 32,
            ),
            Expanded(
              child: Slider(
                value: zoom.clamp(_minZoom, _maxZoom),
                min: _minZoom,
                max: _maxZoom,
                activeColor: AppColors.postPurple,
                onChanged: onZoomChanged,
              ),
            ),
            _RoundIconButton(
              icon: Icons.fullscreen,
              tooltip: 'ดูเต็มจอ',
              onTap: () => showFullImages(context,
                  urls: allPaths, initialIndex: index),
              background: AppColors.postField,
              foreground: AppColors.postRowIcon,
              size: 32,
            ),
            const SizedBox(width: 8),
            _RoundIconButton(
              icon: Icons.refresh,
              tooltip: 'รีเซ็ตขนาด',
              onTap: onReset,
              background: AppColors.postField,
              foreground: AppColors.postRowIcon,
              size: 32,
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.size = 40,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color background, foreground;
  final double size;

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
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.55, color: foreground),
          ),
        ),
      ),
    );
  }
}

/// Every photo in the post so far — tap one to bring it up front, or its own
/// badge to drop it.
class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.paths,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  final List<String> paths;
  final int selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => onSelect(index),
          child: Container(
            width: 84,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: index == selected
                    ? AppColors.postPurple
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(source: paths[index]),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _RoundIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'ลบรูปที่ ${index + 1}',
                    onTap: () => onDelete(index),
                    background: Colors.white,
                    foreground: AppColors.postShare,
                    size: 26,
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

class _DashedAddPhotosButton extends StatelessWidget {
  const _DashedAddPhotosButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.postDashed),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: const Icon(Icons.add_photo_alternate_outlined,
          color: AppColors.postPurple),
      label: Text(
        busy ? 'กำลังเลือกรูป…' : 'เพิ่มรูป',
        style: const TextStyle(
            color: AppColors.postPurple, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// The bar pinned to the bottom of the page — the same shell the composer's
/// own Save Draft/Next bar uses, so the CTA stays put as the body scrolls
/// underneath it rather than trailing off at the end of the content.
///
/// It is one button, not a CTA that merely dims: with nothing picked yet,
/// "add a photo" is the only action that does anything, so that is what
/// shows. The gradient "สร้างโพสเลย" only takes its place once a photo exists
/// — past the only thing it actually does blocking it.
class _PublishBar extends StatelessWidget {
  const _PublishBar({
    required this.hasPhotos,
    required this.busy,
    required this.onAddPhotos,
    required this.onPublish,
  });

  final bool hasPhotos;
  final bool busy;
  final VoidCallback onAddPhotos;
  final VoidCallback onPublish;

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
      child: hasPhotos
          ? _PublishCta(enabled: !busy, onTap: onPublish)
          : _AddPhotosButton(busy: busy, onTap: busy ? null : onAddPhotos),
    );
  }
}

/// The publish action — the same purple-to-lime gradient the "AI
/// สร้างโพสจากรูป" header button wears, since both hand photos to the
/// assistant.
class _PublishCta extends StatelessWidget {
  const _PublishCta({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Container(
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
            onTap: enabled ? onTap : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'สร้างโพสเลย',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The fanned pile of photos above "เพิ่มรูป" (Figma 2480-80673, Frame 2461) —
/// one bundled illustration, already composed at the same 300×304 the design
/// draws it at, rather than three separate photos rotated into place.
class _EmptyPhotosIllustration extends StatelessWidget {
  const _EmptyPhotosIllustration();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/create_post_empty_photos.png',
      width: 255,
      height: 258,
    );
  }
}

/// The solid black pill under the illustration — plain, unlike the AI
/// button's gradient, since this one is a manual, ordinary action.
class _AddPhotosButton extends StatelessWidget {
  const _AddPhotosButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  busy ? 'กำลังเลือกรูป…' : 'เพิ่มรูป',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
