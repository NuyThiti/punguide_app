import 'widgets/post_info_dialog.dart';
import '../../../shared/widgets/cover_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../domain/services/trip_photo_grouper.dart';
import '../domain/services/post_photo_upload.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';
import '../../../core/api/models/trip_content.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/models/post_draft.dart';
import 'widgets/create_post_header.dart';
import 'widgets/photo_source_sheet.dart';
import 'widgets/place_pin_picker.dart';
import 'widgets/post_audience_chip.dart';
import 'widgets/post_block.dart';
import 'widgets/post_trip_row.dart';
import 'widgets/trip_link_picker.dart';

final _localDraftProvider =
    StateProvider.family<PostDraft?, String>((ref, id) => null);
final _localCoverProvider =
    StateProvider.family<String?, String>((ref, id) => null);
final _localPublishProvider =
    StateProvider.family<_PublishResume?, String>((ref, id) => null);

class _PublishResume {
  _PublishResume(this.id, this.coverId, this.uploaded, this.destination);
  final String? id, coverId, destination;
  final Map<String, Media> uploaded;
  String? sourceId, creationTitle, creationDestination;
  String key = '', title = '', postDestination = '';
  bool coverWasInContents = false;
  Set<String> uncertain = {}, legacy = {}, unavailable = {};
  Map<String, TripPhoto> metadata = {};
}

/// "สร้างโพสต์" — the community composer, from the create sheet's Post row.
///
/// A post is one or more sections, each led by its story and carrying whatever
/// the writer added to it: a heading, a photo, a pinned place. Publishing is
/// the header's ปันไกด์ action.
///
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, this.initialTrip});
  final ApiTrip? initialTrip;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  /// Keep one section; any section can be removed when more than one exists.
  final List<_BlockFields> _blocks = <_BlockFields>[_BlockFields()];

  PostAudience _audience = PostAudience.public;
  PostTripLink? _trip;
  String? _tripDestination;

  final _picker = ImagePicker();
  String get _storageKey => widget.initialTrip?.id ?? 'new';
  String? _draftId;
  bool _publishing = false;
  bool _published = false;
  bool _arranging = false;
  int _arrangement = 0;
  final Map<String, Media> _uploaded = {};
  String? _coverPath;
  String? _savedCoverId;
  bool _savedCoverWasInContents = false;
  String _createKey = uuidV4();
  String? _creationTitle, _creationDestination;
  final _postTitle = TextEditingController();
  final _postDestination = TextEditingController();
  final Set<String> _uncertainUploads = {},
      _legacyUrls = {},
      _unavailablePaths = {};
  final Map<String, TripPhoto> _photoMetadata = {};

  void _syncCover() {
    final photos = _blocks.expand((block) => block.imagePaths);
    if (!photos.contains(_coverPath)) {
      _coverPath = null;
    }
  }

  @override
  void initState() {
    super.initState();
    final resumeState = ref.read(_localPublishProvider(_storageKey));
    final saved = resumeState?.sourceId == widget.initialTrip?.id
        ? ref.read(_localDraftProvider(_storageKey))
        : null;
    if (saved != null) {
      for (final block in _blocks) {
        block.dispose(_refresh);
      }
      _blocks.clear();
      for (final topic in saved.topics) {
        _blocks.add(_BlockFields()
          ..title.text = topic.title
          ..body.text = topic.body
          ..showTitle = topic.title.isNotEmpty
          ..imagePaths.addAll(topic.photos)
          ..place = topic.place
          ..location = topic.location
          ..legacyMapId = topic.legacyMapId);
      }
      if (_blocks.isEmpty) _blocks.add(_BlockFields());
      _audience = saved.audience;
      _trip = saved.trip;
      _coverPath = ref.read(_localCoverProvider(_storageKey));
      final resume = ref.read(_localPublishProvider(_storageKey));
      _draftId = resume?.id;
      _savedCoverId = resume?.coverId;
      _tripDestination = resume?.destination;
      _uploaded.addAll(resume?.uploaded ?? {});
      if (resume != null) {
        _savedCoverWasInContents = resume.coverWasInContents;
        _createKey = resume.key;
        _creationTitle = resume.creationTitle;
        _creationDestination = resume.creationDestination;
        _postTitle.text = resume.title;
        _postDestination.text = resume.postDestination;
        _uncertainUploads.addAll(resume.uncertain);
        _legacyUrls.addAll(resume.legacy);
        _unavailablePaths.addAll(resume.unavailable);
        _photoMetadata.addAll(resume.metadata);
      }
    }
    if (saved == null && widget.initialTrip != null) {
      final trip = widget.initialTrip!;
      _draftId = trip.id;
      _postTitle.text = trip.title;
      _postDestination.text = trip.destination;
      _audience = trip.visibility == TripVisibility.public
          ? PostAudience.public
          : PostAudience.onlyMe;
      for (final block in _blocks) {
        block.dispose(_refresh);
      }
      _blocks.clear();
      for (final section in trip.contents) {
        final block = _BlockFields()
          ..title.text = section.title
          ..showTitle = section.title.isNotEmpty
          ..body.text = section.content
          ..location = section.location
          ..legacyMapId = section.mapId;
        if (section.mediaIds != null) {
          for (final id in section.mediaIds!) {
            final images = section.images.where((image) => image.mediaId == id);
            final image = images.isEmpty ? null : images.first;
            final path = image?.urls?.full ?? 'unavailable:$id';
            block.imagePaths.add(path);
            if (image == null || image.unavailable || image.urls == null) {
              _unavailablePaths.add(path);
            } else {
              _uploaded[path] = Media(mediaId: id, urls: image.urls!);
            }
            final metadata =
                section.photoMetadata.where((m) => m.mediaId == id);
            if (metadata.isNotEmpty) {
              final m = metadata.first;
              _photoMetadata[path] = TripPhoto(path,
                  takenAt:
                      m.takenAt == null ? null : DateTime.tryParse(m.takenAt!),
                  captureTimestamp: m.takenAt,
                  latitude: m.latitude,
                  longitude: m.longitude);
            }
            if (trip.coverImage?.mediaId == id) {
              _coverPath = path;
              _savedCoverWasInContents = true;
            }
          }
        } else {
          block.imagePaths.addAll(section.imageUrls);
          _legacyUrls.addAll(section.imageUrls);
        }
        _blocks.add(block);
      }
      _savedCoverId = trip.coverImage?.mediaId;
      if (_blocks.isEmpty) _blocks.add(_BlockFields());
    }
    // เผยแพร่ lights up as soon as there is something to post, so what is
    // typed has to be listened to rather than read on build alone.
    for (final block in _blocks) {
      block.listen(_refresh);
    }
  }

  @override
  void dispose() {
    for (final block in _blocks) {
      block.dispose(_refresh);
    }
    _postTitle.dispose();
    _postDestination.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  PostDraft get _draft => PostDraft(
        audience: _audience,
        topics: _blocks
            .map((fields) => fields.toTopic())
            .where((topic) => !topic.isEmpty)
            .toList(growable: false),
        trip: _trip,
      );

  void _addBlock() {
    if (_blocks.length >= 100) {
      _message('เพิ่มเนื้อหาได้สูงสุด 100 ส่วน');
      return;
    }
    final fields = _BlockFields()..listen(_refresh);
    setState(() => _blocks.add(fields));
  }

  void _removeBlock(int index) {
    final fields = _blocks[index];
    setState(() {
      _blocks.removeAt(index);
      _syncCover();
    });
    fields.dispose(_refresh);
  }

  /// Puts the heading field on screen and drops the caret in it.
  void _addTitle(int index) {
    setState(() => _blocks[index].showTitle = true);
    _blocks[index].titleFocus.requestFocus();
  }

  void _clearTitle(int index) {
    setState(() {
      _blocks[index]
        ..showTitle = false
        ..title.clear();
    });
  }

  Future<void> _pickAudience() async {
    final picked = await showAudiencePicker(context, _audience);
    if (picked == null || !mounted) return;
    setState(() => _audience = picked);
  }

  Future<void> _pickPhoto(int index) async {
    final block = _blocks[index];
    if (block.imagePaths.any(_legacyUrls.contains)) {
      _message('ส่วนนี้ใช้รูปแบบเดิม กรุณาเพิ่มเนื้อหาส่วนใหม่สำหรับรูปใหม่');
      return;
    }
    if (_blocks.expand((b) => b.imagePaths).length >= 200) {
      _message('รองรับสูงสุด 200 รูปต่อโพสต์');
      return;
    }
    if (block.imagePaths.length >= 20) {
      _message('เพิ่มรูปได้สูงสุด 20 รูปต่อส่วน');
      return;
    }
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    try {
      final image = await _picker.pickImage(source: source);
      if (image == null || !mounted || !_blocks.contains(block)) return;
      try {
        _photoMetadata[image.path] =
            await compute(_readPhoto, (await image.readAsBytes(), image.path));
      } catch (_) {}
      if (!mounted || !_blocks.contains(block)) return;
      setState(() {
        block.imagePaths.add(image.path);
        _syncCover();
      });
    } catch (_) {
      // A denied permission, or no camera on the device.
      _message('เลือกรูปไม่สำเร็จ ลองอีกครั้ง');
    }
  }

  void _cancelArrangement() {
    _arrangement++;
    setState(() => _arranging = false);
  }

  Future<void> _createFromPhotos() async {
    if (_arranging) return;
    final token = ++_arrangement;
    setState(() => _arranging = true);
    try {
      // Original files preserve metadata; the system picker supports limited access.
      final files = await _picker.pickMultiImage();
      if (!mounted || token != _arrangement || files.isEmpty) return;
      final photos = <TripPhoto>[];
      for (final file in files) {
        if (!mounted || token != _arrangement) return;
        try {
          final bytes = await file.readAsBytes();
          photos.add(await compute(_readPhoto, (bytes, file.path)));
        } catch (_) {
          photos.add(TripPhoto(file.path));
        }
      }
      if (!mounted || token != _arrangement) return;
      if (_blocks.expand((b) => b.imagePaths).length + photos.length > 200) {
        _message('รองรับสูงสุด 200 รูปต่อโพสต์ กรุณาเลือกให้น้อยลง');
        return;
      }
      _photoMetadata.addEntries(photos.map((p) => MapEntry(p.path, p)));
      final groups = const TripPhotoGrouper().group(photos);
      final empty = _blocks.length == 1 && _blocks.first.toTopic().isEmpty;
      if (_blocks.length + groups.length - (empty ? 1 : 0) > 100) {
        _message(
            'รูปที่เลือกทำให้เกิน 100 ส่วน กรุณาเลือกจำนวนน้อยลง ร่างเดิมยังอยู่');
        return;
      }
      setState(() {
        if (empty) _blocks.removeLast().dispose(_refresh);
        for (final group in groups) {
          _blocks.add(_BlockFields()
            ..imagePaths.addAll(group.map((p) => p.path))
            ..listen(_refresh));
        }
        _syncCover();
      });
      _saveLocal();
      _message(
          'จัดรูปแล้ว ตรวจและแก้ไขในเนื้อหาด้านล่าง กดค้างที่รูปเพื่อลาก หรือกดย้ายรูป');
    } catch (_) {
      if (mounted && token == _arrangement)
        _message(
            'เลือกรูปไม่สำเร็จ กรุณาตรวจสิทธิ์เข้าถึงรูปแล้วลองอีกครั้ง ร่างเดิมยังอยู่');
    } finally {
      if (mounted && token == _arrangement) setState(() => _arranging = false);
    }
  }

  void _transferPhoto(int source, int photo, int target, [int? position]) {
    if (source >= _blocks.length ||
        target >= _blocks.length ||
        photo >= _blocks[source].imagePaths.length) return;
    if (source != target && _blocks[target].imagePaths.length >= 20) {
      _message('เพิ่มรูปได้สูงสุด 20 รูปต่อส่วน');
      return;
    }
    final movingLegacy =
        _legacyUrls.contains(_blocks[source].imagePaths[photo]);
    if (source != target &&
        _blocks[target]
            .imagePaths
            .any((p) => _legacyUrls.contains(p) != movingLegacy)) {
      _message('กรุณาแยกรูปใหม่กับรูปแบบเดิมเป็นคนละส่วน');
      return;
    }
    setState(() {
      final path = _blocks[source].imagePaths.removeAt(photo);
      final images = _blocks[target].imagePaths;
      var insertion = position ?? images.length;
      if (position != null && source == target && photo < position) insertion--;
      images.insert(insertion.clamp(0, images.length), path);
    });
  }

  Future<void> _movePhoto(int source, int photo) async {
    final target = await showModalBottomSheet<int>(
        context: context,
        builder: (context) => SafeArea(
              child: ListView(shrinkWrap: true, children: [
                const ListTile(title: Text('ย้ายรูปไปท้ายเนื้อหา')),
                for (var i = 0; i < _blocks.length; i++)
                  ListTile(
                      title: Text('เนื้อหา ${i + 1}'),
                      onTap: () => Navigator.pop(context, i)),
              ]),
            ));
    if (mounted && target != null) _transferPhoto(source, photo, target);
  }

  Future<void> _pickPlace(int index) async {
    final block = _blocks[index];
    final place = await showPlacePinPicker(context);
    if (place == null || !mounted || !_blocks.contains(block)) return;
    setState(() {
      block.place = place;
      block.location = null;
      block.legacyMapId = null;
    });
  }

  Future<void> _pickTrip() async {
    final link = await showTripLinkPicker(context);
    if (link == null || !mounted) return;
    if (link == noTripLink) {
      setState(() {
        _trip = null;
        _tripDestination = null;
      });
      return;
    }
    try {
      final api = await ref.read(plunoApiProvider.future);
      final trip = await api.trips.byId(link.id);
      if (!mounted) return;
      setState(() {
        _trip = link;
        _tripDestination = trip.destination;
      });
    } catch (_) {
      if (mounted) _message('โหลดข้อมูลทริปไม่สำเร็จ กรุณาลองอีกครั้ง');
    }
  }

  String _trimForTripField(String value) {
    final trimmed = value.trim();
    return trimmed.length <= 200 ? trimmed : trimmed.substring(0, 200);
  }

  String _titleForPublish(PostDraft draft) {
    if (_postTitle.text.trim().isNotEmpty) return _postTitle.text.trim();
    if (_trip != null && _trip!.title.trim().isNotEmpty) {
      return _trimForTripField(_trip!.title);
    }
    for (final topic in draft.topics) {
      if (topic.title.trim().isNotEmpty) {
        return _trimForTripField(topic.title);
      }
      if (topic.body.trim().isNotEmpty) {
        return _trimForTripField(topic.body);
      }
    }
    return '';
  }

  String _destinationForPublish(PostDraft draft) {
    if (_postDestination.text.trim().isNotEmpty)
      return _postDestination.text.trim();
    final linkedDestination = _tripDestination?.trim();
    if (linkedDestination != null && linkedDestination.isNotEmpty) {
      return _trimForTripField(linkedDestination);
    }
    for (final topic in draft.topics) {
      final place = topic.place;
      if (place == null) continue;
      if (place.area != null && place.area!.trim().isNotEmpty) {
        return _trimForTripField(place.area!);
      }
      if (place.name.trim().isNotEmpty) {
        return _trimForTripField(place.name);
      }
    }
    return '';
  }

  void _saveLocal() {
    if (_published) {
      ref.read(_localDraftProvider(_storageKey).notifier).state = null;
      ref.read(_localCoverProvider(_storageKey).notifier).state = null;
      ref.read(_localPublishProvider(_storageKey).notifier).state = null;
      return;
    }
    ref.read(_localPublishProvider(_storageKey).notifier).state =
        _PublishResume(
            _draftId, _savedCoverId, Map.of(_uploaded), _tripDestination)
          ..coverWasInContents = _savedCoverWasInContents
          ..sourceId = widget.initialTrip?.id
          ..key = _createKey
          ..creationTitle = _creationTitle
          ..creationDestination = _creationDestination
          ..title = _postTitle.text
          ..postDestination = _postDestination.text
          ..uncertain = Set.of(_uncertainUploads)
          ..legacy = Set.of(_legacyUrls)
          ..unavailable = Set.of(_unavailablePaths)
          ..metadata = Map.of(_photoMetadata);
    ref.read(_localDraftProvider(_storageKey).notifier).state = _draft;
    ref.read(_localCoverProvider(_storageKey).notifier).state = _coverPath;
  }

  void _close() {
    if (_publishing) return;
    _arrangement++;
    _saveLocal();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }

  Future<void> _publish() async {
    if (_publishing || _arranging || !_draft.isPublishable) return;
    if (_audience == PostAudience.followers) {
      _message('ขณะนี้รองรับสาธารณะและเฉพาะฉัน กรุณาเลือกผู้ชมอีกครั้ง');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = _draft;
    var title = _titleForPublish(draft);
    var destination = _destinationForPublish(draft);
    if (title.isEmpty || destination.isEmpty) {
      if (!await _editPostInfo(title, destination) || !mounted) return;
      title = _postTitle.text.trim();
      destination = _postDestination.text.trim();
    }
    setState(() => _publishing = true);
    try {
      if (draft.topics.expand((s) => s.photos).length > 200)
        throw const FormatException('รองรับสูงสุด 200 รูปต่อโพสต์');
      if (draft.topics.any((s) => s.photos.any(_unavailablePaths.contains)))
        throw const FormatException(
            'มีรูปที่ไม่พร้อมใช้งาน กรุณาเอารูปนั้นออกหรือเลือกใหม่ก่อนปันไกด์');
      final api = await ref.read(plunoApiProvider.future);
      if (_draftId == null) {
        _creationTitle ??= title;
        _creationDestination ??= destination;
        final created = await api.trips.createDraft(
            type: TripType.content,
            title: _creationTitle!,
            destination: _creationDestination!,
            idempotencyKey: _createKey);
        _draftId = created.id;
      }
      final contents = <TripContentRequest>[];
      final occurrences = <String, int>{};
      for (final topic in draft.topics) {
        final legacy = topic.photos.where(_legacyUrls.contains).toList();
        if (legacy.isNotEmpty && legacy.length != topic.photos.length)
          throw const FormatException(
              'กรุณาแยกรูปใหม่กับรูปแบบเดิมเป็นคนละส่วน');
        final ids = <String>[];
        final metadata = <PhotoMetadata>[];
        for (final path
            in topic.photos.where((p) => !_legacyUrls.contains(p))) {
          final occurrence =
              occurrences.update(path, (n) => n + 1, ifAbsent: () => 0);
          final key = occurrence == 0 || path.startsWith('http')
              ? path
              : '$path::$occurrence';
          if (_uncertainUploads.contains(key) &&
              !await _resolveUpload(key, path)) return;
          if (!_uploaded.containsKey(key)) {
            if (_uploaded.length >= 200)
              throw const FormatException(
                  'มีไฟล์อัปโหลดครบ 200 รูปแล้ว กรุณาจัดการ gallery ก่อนเพิ่มรูป');
            final prepared = await preparePostPhoto(path);
            try {
              _uploaded[key] = await api.media
                  .upload(_draftId!, bytes: prepared.$1, filename: prepared.$2);
            } on ApiException catch (error) {
              if (error.isNetworkFailure || (error.statusCode ?? 0) >= 500)
                _uncertainUploads.add(key);
              rethrow;
            }
          }
          final id = _uploaded[key]!.mediaId;
          ids.add(id);
          final m = _photoMetadata[path];
          if (m != null && (m.captureTimestamp != null || m.hasLocation))
            metadata.add(PhotoMetadata(
                mediaId: id,
                takenAt: m.captureTimestamp,
                latitude: m.hasLocation ? m.latitude : null,
                longitude: m.hasLocation ? m.longitude : null));
        }
        final location = topic.place == null
            ? topic.location
            : ContentLocation(
                status: ContentLocationStatus.confirmed,
                name: topic.place!.name);
        contents.add(TripContentRequest(
            title: topic.title,
            content: topic.body,
            mediaIds: legacy.isEmpty ? ids : null,
            imageUrls: legacy,
            location: topic.legacyMapId != null && location == null
                ? null
                : location ??
                    const ContentLocation(status: ContentLocationStatus.none),
            mapId: location == null ? topic.legacyMapId : null,
            photoMetadata: metadata));
      }
      TripContentRequest.serializeAll(contents);

      final cover = _coverPath == null ? null : _uploaded[_coverPath];
      if (cover != null) {
        await api.media.setCover(_draftId!, cover.mediaId);
        _savedCoverId = cover.mediaId;
        _savedCoverWasInContents = true;
      } else if (_savedCoverWasInContents &&
          _savedCoverId != null &&
          !contents.any((s) => s.mediaIds?.contains(_savedCoverId) ?? false)) {
        // The server rejects deleting media still referenced by saved contents.
        await api.trips.update(_draftId!, contents: contents);
        final removed = _savedCoverId!;
        await api.media.delete(_draftId!, removed);
        _uploaded.removeWhere((_, m) => m.mediaId == removed);
        _savedCoverId = null;
        _savedCoverWasInContents = false;
      }
      await api.trips.update(_draftId!,
          type: TripType.content,
          title: title,
          destination: destination,
          contents: contents,
          visibility: draft.audience == PostAudience.public
              ? TripVisibility.public
              : TripVisibility.private);
      if (!mounted) return;
      setState(() => _publishing = false);
      _published = true;
      _message('บันทึกโพสต์เรียบร้อยแล้ว');
      _close();
    } on ApiException catch (error) {
      if (mounted) {
        _message(
            '${_uncertainUploads.isNotEmpty ? 'มีรูปที่ไม่ทราบผลอัปโหลด ครั้งถัดไปต้องตรวจ gallery ก่อนส่งซ้ำ: ' : _draftId == null ? '' : 'ยังเผยแพร่ไม่สำเร็จ ลองอีกครั้งได้: '}${error.message}');
      }
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('บันทึกไม่สำเร็จ กรุณาลองอีกครั้ง');
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
        if (!_published) _saveLocal();
      }
    }
  }

  Future<bool> _editPostInfo(String title, String destination) async {
    final result = await showDialog<(String, String)>(
        context: context,
        builder: (_) => PostInfoDialog(title: title, destination: destination));
    if (result == null || !mounted) return false;
    _postTitle.text = result.$1;
    _postDestination.text = result.$2;
    _saveLocal();
    return true;
  }

  Future<bool> _resolveUpload(String key, String path) async {
    final api = await ref.read(plunoApiProvider.future);
    final images = <GalleryImage>[];
    for (var page = 1;; page++) {
      final gallery =
          await api.media.gallery(_draftId!, page: page, limit: 100);
      images.addAll(gallery.items);
      if (!gallery.hasNextPage) break;
    }
    if (!mounted) return false;
    final selected = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
                child: ListView(children: [
              SizedBox(height: 180, child: CoverImage(source: path)),
              const ListTile(
                  title: Text('ตรวจรูปที่อัปโหลดไม่ทราบผล'),
                  subtitle: Text(
                      'เลือกรูปที่ตรงกันใน gallery หากตรวจแล้วไม่มีรูปนี้จึงส่งซ้ำ')),
              for (final image in images)
                ListTile(
                    leading: SizedBox(
                        width: 56,
                        child: Image.network(image.urls.thumbnail,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image))),
                    title: Text(image.caption ?? 'รูปใน gallery'),
                    onTap: () => Navigator.pop(context, image.id)),
              TextButton(
                  onPressed: () => Navigator.pop(context, 'retry'),
                  child: const Text('ตรวจแล้วไม่มีรูปนี้ ส่งใหม่')),
            ])));
    if (!mounted || selected == null) return false;
    if (selected != 'retry') {
      final image = images.firstWhere((i) => i.id == selected);
      _uploaded[key] = Media(mediaId: image.id, urls: image.urls);
    }
    _uncertainUploads.remove(key);
    return true;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return AppFrame(
      background: AppColors.screen,
      child: PopScope(
        canPop: !_publishing && !_arranging,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) _saveLocal();
          if (!didPop && _arranging) _cancelArrangement();
        },
        child: AbsorbPointer(
          absorbing: _publishing,
          child: SafeArea(
            child: Column(
              children: [
                CreatePostHeader(
                  onClose: _close,
                  onPublish: _publish,
                  canPublish:
                      !_publishing && !_arranging && _draft.isPublishable,
                ),
                if (_publishing) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    children: [
                      PostAuthorRow(
                        session: session,
                        audience: _audience,
                        onChangeAudience: _pickAudience,
                      ),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                              onPressed: () => _editPostInfo(
                                  _titleForPublish(_draft),
                                  _destinationForPublish(_draft)),
                              child: const Text('ชื่อโพสต์และจุดหมาย'))),
                      const SizedBox(height: 12),
                      if (_arranging)
                        Row(children: [
                          const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 10),
                          const Expanded(
                              child: Text('กำลังจัดรูปเป็นเรื่องราว…')),
                          TextButton(
                              onPressed: _cancelArrangement,
                              child: const Text('ยกเลิก')),
                        ])
                      else
                        Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _createFromPhotos,
                              icon: const Icon(Icons.auto_awesome_outlined,
                                  size: 19),
                              label: const Text('สร้างจากรูปทริป'),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColors.createTop),
                            )),
                      const SizedBox(height: 12),
                      for (var index = 0; index < _blocks.length; index++) ...[
                        if (index > 0)
                          const Divider(height: 30, color: AppColors.line),
                        if (_blocks.length > 1)
                          Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('เนื้อหา ${index + 1}'),
                                IconButton(
                                    tooltip: 'เลื่อนขึ้น',
                                    icon: const Icon(Icons.arrow_upward),
                                    onPressed: index == 0
                                        ? null
                                        : () => setState(() {
                                              final block =
                                                  _blocks.removeAt(index);
                                              _blocks.insert(index - 1, block);
                                            })),
                                IconButton(
                                    tooltip: 'เลื่อนลง',
                                    icon: const Icon(Icons.arrow_downward),
                                    onPressed: index == _blocks.length - 1
                                        ? null
                                        : () => setState(() {
                                              final block =
                                                  _blocks.removeAt(index);
                                              _blocks.insert(index + 1, block);
                                            })),
                              ]),
                        if (_blocks[index].legacyMapId != null &&
                            _blocks[index].location == null)
                          Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('สถานที่เดิม (ยังไม่ยืนยัน)'),
                                onTap: () => _pickPlace(index),
                                trailing: IconButton(
                                    tooltip: 'ลบสถานที่เดิม',
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(() {
                                          _blocks[index].legacyMapId = null;
                                          _blocks[index].location =
                                              const ContentLocation(
                                                  status: ContentLocationStatus
                                                      .none);
                                        })),
                              )),
                        if (_blocks[index].location != null &&
                            _blocks[index].location!.status !=
                                ContentLocationStatus.none)
                          Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(_blocks[index].location!.status ==
                                        ContentLocationStatus.suggested
                                    ? 'สถานที่ที่แนะนำ: ${_blocks[index].location!.name ?? "รอยืนยัน"}'
                                    : _blocks[index].location!.name ??
                                        'สถานที่ที่ยืนยัน'),
                                subtitle: _blocks[index].location!.status ==
                                        ContentLocationStatus.suggested
                                    ? TextButton(
                                        onPressed: () => setState(() {
                                              final l =
                                                  _blocks[index].location!;
                                              _blocks[index].location =
                                                  ContentLocation(
                                                      status:
                                                          ContentLocationStatus
                                                              .confirmed,
                                                      name: l.name,
                                                      placeId: l.placeId,
                                                      latitude: l.latitude,
                                                      longitude: l.longitude);
                                            }),
                                        child: const Text('ยืนยันสถานที่'))
                                    : null,
                                onTap: () => _pickPlace(index),
                                trailing: IconButton(
                                    tooltip: 'ลบสถานที่',
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(() =>
                                        _blocks[index].location =
                                            const ContentLocation(
                                                status: ContentLocationStatus
                                                    .none))),
                              )),
                        PostBlock(
                          key: ValueKey(_blocks[index]),
                          titleController: _blocks[index].title,
                          titleFocus: _blocks[index].titleFocus,
                          bodyController: _blocks[index].body,
                          showTitle: _blocks[index].showTitle,
                          imagePath: null,
                          imagePaths: _blocks[index].imagePaths,
                          unavailableImages: _unavailablePaths,
                          coverPath: _coverPath,
                          onMoveImage: (photoIndex) =>
                              _movePhoto(index, photoIndex),
                          onDropImage: (move) =>
                              _transferPhoto(move.$1, move.$2, index),
                          blockIndex: index,
                          onDropBeforeImage: (move, position) =>
                              _transferPhoto(move.$1, move.$2, index, position),
                          onSelectCover: (path) {
                            if (_legacyUrls.contains(path)) {
                              _message(
                                  'รูปเดิมนี้ไม่มี mediaId สำหรับตั้งปก กรุณาเลือกรูปใหม่ในส่วนใหม่');
                              return;
                            }
                            setState(() => _coverPath = path);
                          },
                          onRemoveImage: (photoIndex) => setState(() {
                            _blocks[index].imagePaths.removeAt(photoIndex);
                            _syncCover();
                          }),
                          place: _blocks[index].place,
                          onAddTitle: () => _addTitle(index),
                          onClearTitle: () => _clearTitle(index),
                          onPickImage: () => _pickPhoto(index),
                          onClearImage: () => setState(() {
                            _blocks[index].imagePaths.clear();
                            _syncCover();
                          }),
                          onPickPlace: () => _pickPlace(index),
                          onClearPlace: () => setState(() {
                            _blocks[index].place = null;
                            _blocks[index].location = const ContentLocation(
                                status: ContentLocationStatus.none);
                            _blocks[index].legacyMapId = null;
                          }),
                          onRemove: _blocks.length == 1
                              ? null
                              : () => _removeBlock(index),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _AddBlockButton(onTap: _addBlock),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          'เพิ่มเรื่องราวส่วนถัดไป',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Divider(height: 30, color: AppColors.line),
                      PostTripRow(trip: _trip?.title, onTap: _pickTrip),
                      const Divider(height: 1, color: AppColors.line),
                    ],
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

/// The controllers and attachments of one section, owned by the screen so the
/// block itself stays stateless.
class _BlockFields {
  final TextEditingController title = TextEditingController();
  final TextEditingController body = TextEditingController();
  final FocusNode titleFocus = FocusNode();

  /// The heading field has been asked for. Not the same as the heading having
  /// text: one just added is on screen and still blank.
  bool showTitle = false;

  final List<String> imagePaths = [];
  PostPlace? place;
  ContentLocation? location;
  String? legacyMapId;

  PostTopic toTopic() => PostTopic(
        title: title.text,
        body: body.text,
        imagePaths: List.of(imagePaths),
        place: place,
        location: location,
        legacyMapId: legacyMapId,
      );

  void listen(VoidCallback onChanged) {
    title.addListener(onChanged);
    body.addListener(onChanged);
  }

  void dispose(VoidCallback onChanged) {
    title.removeListener(onChanged);
    body.removeListener(onChanged);
    title.dispose();
    body.dispose();
    titleFocus.dispose();
  }
}

class _AddBlockButton extends StatelessWidget {
  const _AddBlockButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 21),
        label: const Text(
          'เพิ่มเนื้อหา',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.createTop,
          side: const BorderSide(color: AppColors.createTop, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

Future<TripPhoto> _readPhoto((Uint8List, String) input) =>
    readTripPhoto(input.$1, input.$2);
