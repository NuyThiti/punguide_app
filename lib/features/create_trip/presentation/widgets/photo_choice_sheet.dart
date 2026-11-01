import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';

/// What the traveller picked in [showPhotoChoiceSheet].
sealed class PhotoChoice {
  const PhotoChoice();
}

/// New photos from the device; the first is the one they want shown.
class DevicePhotos extends PhotoChoice {
  const DevicePhotos(this.files);
  final List<XFile> files;
}

/// One of the photos already picked in this form, by its index there.
class PendingPhoto extends PhotoChoice {
  const PendingPhoto(this.index);
  final int index;
}

/// The photo the stop shows today — nothing to change.
class CurrentPhoto extends PhotoChoice {
  const CurrentPhoto();
}

/// One of the linked place's Google photos, as `GET /places/:id` lists it.
class GooglePhoto extends PhotoChoice {
  const GooglePhoto(this.url);
  final String url;
}

/// A place's Google photos: the `photos` of `GET /places/:id`. The URLs are
/// for showing only — never stored, they expire or redirect.
final placePhotosProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, placeId) async {
  final api = await ref.watch(plunoApiProvider.future);
  final details = await api.places.byId(placeId, reviews: false, photos: true);
  return details.photos;
});

/// The sheet the tabs and grid live in, for tests to scope to.
const photoChoiceSheetKey = Key('photo-choice-sheet');

/// "เปลี่ยนรูปภาพ": the traveller's own photos on one tab, the place's Google
/// photos on the other. Returns null when closed without choosing.
Future<PhotoChoice?> showPhotoChoiceSheet(
  BuildContext context, {
  required List<XFile> pending,
  String? currentUrl,
  String? placeId,
  String? selectedGoogleUrl,
}) {
  return showModalBottomSheet<PhotoChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: PhotoChoiceSheet(
        pending: pending,
        currentUrl: currentUrl,
        placeId: placeId,
        selectedGoogleUrl: selectedGoogleUrl,
      ),
    ),
  );
}

class PhotoChoiceSheet extends StatefulWidget {
  const PhotoChoiceSheet({
    super.key,
    required this.pending,
    this.currentUrl,
    this.placeId,
    this.selectedGoogleUrl,
  });

  final List<XFile> pending;

  /// What the stop shows now: its newest upload, else the place's photo.
  final String? currentUrl;

  /// The linked place, whose Google photos fill the second tab.
  final String? placeId;
  final String? selectedGoogleUrl;

  @override
  State<PhotoChoiceSheet> createState() => _PhotoChoiceSheetState();
}

/// The reference's selection blue.
const _selectBlue = Color(0xFF4353E8);

class _PhotoChoiceSheetState extends State<PhotoChoiceSheet> {
  final _picker = ImagePicker();

  /// The highlighted tile; tapping its "เลือก" confirms it.
  PhotoChoice? _selected;

  @override
  void initState() {
    super.initState();
    final google = widget.selectedGoogleUrl;
    _selected = google != null
        ? GooglePhoto(google)
        : widget.pending.isNotEmpty
            ? const PendingPhoto(0)
            : widget.currentUrl != null
                ? const CurrentPhoto()
                : null;
  }

  Future<void> _upload() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty || !mounted) return;
    Navigator.of(context).pop(DevicePhotos(picked));
  }

  bool _isSelected(PhotoChoice choice) => switch ((choice, _selected)) {
        (PendingPhoto(:final index), PendingPhoto(index: final other)) =>
          index == other,
        (CurrentPhoto(), CurrentPhoto()) => true,
        (GooglePhoto(:final url), GooglePhoto(url: final other)) =>
          url == other,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      // A stop with a place most likely wants one of its photos.
      length: 2,
      initialIndex: widget.selectedGoogleUrl != null ? 1 : 0,
      child: Column(
        key: photoChoiceSheetKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'เปลี่ยนรูปภาพ',
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'ปิด',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.symmetric(horizontal: 8),
            labelColor: AppColors.brandOrange,
            unselectedLabelColor: AppColors.foreground,
            indicatorColor: AppColors.brandOrange,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            unselectedLabelStyle:
                TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'รูปภาพของคุณ'),
              Tab(text: 'เลือกรูปภาพ'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [_ownTab(), _googleTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ownTab() {
    final current = widget.currentUrl;
    // Photos picked in this form replace the stop's photo on save, so the
    // current one is only offered while there are none.
    return _PhotoGrid(
      leading: _UploadTile(onTap: _upload),
      tiles: [
        for (final (index, file) in widget.pending.indexed)
          _tile(PendingPhoto(index),
              Image.file(File(file.path), fit: BoxFit.cover)),
        if (widget.pending.isEmpty && current != null)
          _tile(const CurrentPhoto(), CoverImage(source: current)),
      ],
    );
  }

  Widget _googleTab() {
    final placeId = widget.placeId;
    if (placeId == null) {
      return const _Note(
        icon: Icons.add_location_alt_outlined,
        text: 'เลือกสถานที่ก่อน เพื่อดูรูปจาก Google',
      );
    }
    return Consumer(
      builder: (context, ref, _) {
        final photos = ref.watch(placePhotosProvider(placeId));
        return photos.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _Note(
            icon: Icons.cloud_off_outlined,
            text: 'โหลดรูปจาก Google ไม่สำเร็จ',
            action: 'ลองใหม่',
            onAction: () => ref.invalidate(placePhotosProvider(placeId)),
          ),
          data: (urls) => urls.isEmpty
              ? const _Note(
                  icon: Icons.image_not_supported_outlined,
                  text: 'สถานที่นี้ยังไม่มีรูปจาก Google',
                )
              : _PhotoGrid(
                  tiles: [
                    for (final url in urls)
                      _tile(GooglePhoto(url), CoverImage(source: url)),
                  ],
                ),
        );
      },
    );
  }

  Widget _tile(PhotoChoice choice, Widget image) {
    return _ChoiceTile(
      selected: _isSelected(choice),
      image: image,
      onTap: () => setState(() => _selected = choice),
      onConfirm: () => Navigator.of(context).pop(choice),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.tiles, this.leading});

  final List<Widget> tiles;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final children = [if (leading != null) leading!, ...tiles];
    return LayoutBuilder(
      builder: (context, constraints) => GridView.count(
        // Three across as drawn on a wide frame; two on a phone, where three
        // would leave each photo too small to judge.
        crossAxisCount: constraints.maxWidth >= 560 ? 3 : 2,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: children,
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.image,
    required this.onTap,
    required this.onConfirm,
  });

  final bool selected;
  final Widget image;
  final VoidCallback onTap;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.all(selected ? 3 : 0),
        decoration: BoxDecoration(
          color: selected ? _selectBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(selected ? 11 : 14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: _selectBlue,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'เลือก',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F2EF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 28, color: AppColors.muted),
            SizedBox(height: 6),
            Text(
              'อัปโหลดรูป',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.muted),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      ),
    );
  }
}

/// A photo a stop already has, offered as the trip's cover.
class CoverCandidate {
  const CoverCandidate({
    required this.url,
    required this.title,
    this.mediaId,
    this.placeId,
  });

  final String url;

  /// The stop it came from, shown on the tile.
  final String title;

  /// Set when it is already in the gallery — an upload to the stop.
  final String? mediaId;

  /// Set when it is the linked place's photo, which has to be pulled into the
  /// gallery before it can be the cover.
  final String? placeId;
}

/// What the traveller picked in [showCoverChoiceSheet].
sealed class CoverChoice {
  const CoverChoice();
}

class CoverUpload extends CoverChoice {
  const CoverUpload(this.file);
  final XFile file;
}

class CoverFromStop extends CoverChoice {
  const CoverFromStop(this.candidate);
  final CoverCandidate candidate;
}

const coverChoiceSheetKey = Key('cover-choice-sheet');

/// "เปลี่ยนรูปปก": upload a new photo, or pick one the stops already have.
/// Returns null when closed without choosing.
Future<CoverChoice?> showCoverChoiceSheet(
  BuildContext context, {
  required List<CoverCandidate> candidates,
  String? currentUrl,
}) {
  return showModalBottomSheet<CoverChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: CoverChoiceSheet(candidates: candidates, currentUrl: currentUrl),
    ),
  );
}

class CoverChoiceSheet extends StatefulWidget {
  const CoverChoiceSheet({
    super.key,
    required this.candidates,
    this.currentUrl,
  });

  final List<CoverCandidate> candidates;

  /// The cover shown now, so its tile starts highlighted.
  final String? currentUrl;

  @override
  State<CoverChoiceSheet> createState() => _CoverChoiceSheetState();
}

class _CoverChoiceSheetState extends State<CoverChoiceSheet> {
  final _picker = ImagePicker();
  String? _selectedUrl;

  @override
  void initState() {
    super.initState();
    _selectedUrl = widget.currentUrl;
  }

  Future<void> _upload() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    Navigator.of(context).pop(CoverUpload(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: coverChoiceSheetKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'เปลี่ยนรูปปก',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'ปิด',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'อัปโหลดรูปใหม่ หรือเลือกรูปจากกิจกรรมในแผน',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: _PhotoGrid(
            leading: _UploadTile(onTap: _upload),
            tiles: [
              for (final candidate in widget.candidates)
                _ChoiceTile(
                  selected: candidate.url == _selectedUrl,
                  image: Stack(
                    fit: StackFit.expand,
                    children: [
                      CoverImage(source: candidate.url),
                      _TileCaption(candidate.title),
                    ],
                  ),
                  onTap: () => setState(() => _selectedUrl = candidate.url),
                  onConfirm: () =>
                      Navigator.of(context).pop(CoverFromStop(candidate)),
                ),
            ],
          ),
        ),
        if (widget.candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Text(
              'ยังไม่มีรูปจากกิจกรรม เพิ่มรูปให้สถานที่ในแผน แล้วเลือกเป็นปกได้ที่นี่',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// The stop's name along a tile's bottom edge.
class _TileCaption extends StatelessWidget {
  const _TileCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
