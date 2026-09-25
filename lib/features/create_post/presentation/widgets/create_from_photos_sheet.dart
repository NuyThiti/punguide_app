import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../domain/models/post_draft.dart';
import 'composer_sheet.dart';
import 'photo_source_sheet.dart';
import 'place_pin_picker.dart';

class PhotoImportSelection {
  const PhotoImportSelection(this.files, this.place, this.fromCamera);
  final List<XFile> files;
  final PostPlace? place;
  final bool fromCamera;
}

Future<PhotoImportSelection?> showCreateFromPhotosSheet(
  BuildContext context, {
  required ImagePicker picker,
  required int remaining,
}) =>
    showModalBottomSheet<PhotoImportSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoImportSheet(picker: picker, remaining: remaining),
    );

class _PhotoImportSheet extends StatefulWidget {
  const _PhotoImportSheet({required this.picker, required this.remaining});
  final ImagePicker picker;
  final int remaining;

  @override
  State<_PhotoImportSheet> createState() => _PhotoImportSheetState();
}

class _PhotoImportSheetState extends State<_PhotoImportSheet> {
  final _photos = <({XFile file, bool camera})>[];
  PostPlace? _place;
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
    } catch (_) {
      if (mounted)
        setState(() => _error = 'เลือกรูปไม่สำเร็จ กรุณาลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickLocation() async {
    final place = await showPlacePinPicker(context, hasPlace: _place != null);
    if (!mounted || place == null) return;
    setState(() => _place = place == clearedPlacePin ? null : place);
  }

  @override
  Widget build(BuildContext context) => ComposerSheet(
        title: 'Create from Photos',
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('เพิ่มสถานที่และรูปภาพสำหรับสร้างโพสต์',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.line)),
                leading: const Icon(Icons.location_on_outlined,
                    color: AppColors.postPurple),
                title: Text(_place?.name ?? 'Add Location'),
                subtitle: Text(_place == null
                    ? 'ไม่บังคับ • เลือกเมื่อทุกรูปเป็นสถานที่เดียวกัน'
                    : 'แตะเพื่อเปลี่ยนหรือลบสถานที่'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickLocation,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _picking ? null : _addPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_picking ? 'กำลังเลือกรูป…' : 'Add Photos'),
              ),
              if (_photos.isNotEmpty) ...[
                Text('${_photos.length} รูป',
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8),
                  itemCount: _photos.length,
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(fit: StackFit.expand, children: [
                      CoverImage(source: _photos[index].file.path),
                      Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton.filled(
                            tooltip: 'ลบรูปที่ ${index + 1}',
                            style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                foregroundColor: Colors.white),
                            onPressed: () =>
                                setState(() => _photos.removeAt(index)),
                            icon: const Icon(Icons.close, size: 18),
                          )),
                    ]),
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _photos.isEmpty || _picking
                    ? null
                    : () => Navigator.pop(
                        context,
                        PhotoImportSelection(
                          _photos.map((p) => p.file).toList(),
                          _place,
                          _photos.every((p) => p.camera),
                        )),
                child: const Text('สร้างโพสต์จากรูป'),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก')),
            ],
          ),
        ),
      );
}
