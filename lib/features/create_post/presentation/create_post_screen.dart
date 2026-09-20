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
import 'widgets/post_about_trip.dart';
import 'widgets/post_action_bar.dart';
import 'widgets/post_spot_details.dart';
import 'widgets/post_title_field.dart';
import 'widgets/post_warnings.dart';
import 'widgets/post_block.dart';
import 'widgets/trip_link_picker.dart';

/// What `POST /trips/:id/contents/generate` takes in one call. A cost ceiling
/// billed per photo, not a limit on the post, which still holds 200.
const _assistantPhotoLimit = 20;

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
  PostAboutTrip about = const PostAboutTrip();
  List<PostSpotDetails> spotDetails = const [];
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

  /// What the assistant warned about on the last draft. The contract requires
  /// every one of these to reach the screen, so they stay until dismissed.
  List<String> _warnings = const [];

  /// The places the assistant offered for a spot, kept against the spot itself
  /// so reordering or deleting cannot point them at the wrong one.
  final Map<_BlockFields, SectionPlaceOptions> _placeOptions = {};

  /// The Trip Activity chips from the Title sheet. These have a field behind
  /// them — `travelStyles` on the trip — so they go up with the post.
  List<TravelStyle> _styles = const [];

  /// Activities the traveller typed themselves, sent as `customStyles`.
  List<String> _customStyles = const [];

  /// One key per draft attempt: replaying it inside five minutes returns the
  /// same draft without paying for the model again. "ร่างใหม่" mints a new one.
  String _assistKey = uuidV4();

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

  /// What the whole trip was about, and what it cost per head. Both optional.
  PostAboutTrip _about = const PostAboutTrip();
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

  int _photoCount() =>
      _blocks.fold(0, (count, block) => count + block.imagePaths.length);

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
          ..replaceItems(topic.contentItems)
          ..copyLegacyPlaceToFirstItem(topic));
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
        _about = resume.about;
        for (var i = 0;
            i < resume.spotDetails.length && i < _blocks.length;
            i++) {
          _blocks[i].details = resume.spotDetails[i];
        }
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
      // specialNotes is owner-only; a null here means the response withheld it
      // rather than that the writer left About trip blank.
      final linked = trip.linkedTrip;
      if (linked != null) {
        _trip = PostTripLink(id: linked.id, title: linked.title);
      }
      _about = PostAboutTrip(
        overview: trip.specialNotes ?? '',
        budget: trip.budgetLimit,
        // Absent on the wire means THB — nothing was backfilled.
        currency: trip.budgetCurrency ?? 'THB',
      );
      _audience = trip.visibility == TripVisibility.public
          ? PostAudience.public
          : PostAudience.onlyMe;
      for (final block in _blocks) {
        block.dispose(_refresh);
      }
      _blocks.clear();
      for (final section in trip.contents) {
        final canMerge = section.title.isNotEmpty &&
            _blocks.isNotEmpty &&
            _blocks.last.title.text == section.title;
        final block = canMerge
            ? _blocks.last
            : (_BlockFields()..title.text = section.title);
        final item = canMerge ? _BlockItemFields() : block.items.first;
        block.details = PostSpotDetails(
          visitedAt: _timeOfDay(section.visitedAt),
          opensAt: _timeOfDay(section.opensAt),
          closesAt: _timeOfDay(section.closesAt),
          transportModes: section.transportModes,
          transportCost: section.transportCost,
          tripHack: section.tripHack ?? '',
        );
        item
          ..body.text = section.content
          ..location = section.location
          ..legacyMapId = section.mapId;
        if (section.mediaIds != null) {
          for (final id in section.mediaIds!) {
            final images = section.images.where((image) => image.mediaId == id);
            final image = images.isEmpty ? null : images.first;
            final path = image?.urls?.full ?? 'unavailable:$id';
            item.imagePaths.add(path);
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
          item.imagePaths.addAll(section.imageUrls);
          _legacyUrls.addAll(section.imageUrls);
        }
        if (canMerge) {
          block.items.add(item);
        } else {
          _blocks.add(block);
        }
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
  void _addItem(int index) {
    final block = _blocks[index];
    if (block.items.length >= 20) {
      _message('เพิ่มชุดข้อมูลได้สูงสุด 20 ชุดต่อหัวข้อ');
      return;
    }
    final item = _BlockItemFields()..listen(_refresh);
    setState(() => block.items.add(item));
  }

  void _removeItem(int blockIndex, int itemIndex) {
    final block = _blocks[blockIndex];
    if (block.items.length == 1 || itemIndex >= block.items.length) return;
    final item = block.items[itemIndex];
    setState(() {
      block.items.removeAt(itemIndex);
      _syncCover();
    });
    item.dispose(_refresh);
  }

  /// Names the post and records what kind of trip it was.
  Future<void> _editTitle() async {
    final result = await showPostTitleSheet(
      context,
      title: _postTitle.text,
      styles: _styles,
      customStyles: _customStyles,
    );
    if (result == null || !mounted) return;
    setState(() {
      _postTitle.text = result.title;
      _styles = List.unmodifiable(result.styles);
      _customStyles = List.unmodifiable(result.customStyles);
    });
    _saveLocal();
  }

  Future<void> _pickAudience() async {
    final picked = await showAudiencePicker(context, _audience);
    if (picked == null || !mounted) return;
    setState(() => _audience = picked);
  }

  /// [forcedSource] is the camera chip, which has already said where the photo
  /// comes from; without it the source sheet asks.
  Future<void> _pickPhoto(int index,
      [int itemIndex = 0, ImageSource? forcedSource]) async {
    final block = _blocks[index];
    if (itemIndex >= block.items.length) return;
    final item = block.items[itemIndex];
    if (item.imagePaths.any(_legacyUrls.contains)) {
      _message('ส่วนนี้ใช้รูปแบบเดิม กรุณาเพิ่มเนื้อหาส่วนใหม่สำหรับรูปใหม่');
      return;
    }
    if (_photoCount() >= 200) {
      _message('รองรับสูงสุด 200 รูปต่อโพสต์');
      return;
    }
    if (item.imagePaths.length >= 20) {
      _message('เพิ่มรูปได้สูงสุด 20 รูปต่อชุดข้อมูล');
      return;
    }
    final source = forcedSource ?? await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    try {
      final image = await _picker.pickImage(source: source);
      if (image == null ||
          !mounted ||
          !_blocks.contains(block) ||
          !block.items.contains(item)) {
        return;
      }
      try {
        _photoMetadata[image.path] =
            await compute(_readPhoto, (await image.readAsBytes(), image.path));
      } catch (_) {}
      if (!mounted || !_blocks.contains(block) || !block.items.contains(item)) {
        return;
      }
      setState(() {
        item.imagePaths.add(image.path);
        _syncCover();
      });
    } catch (_) {
      // A denied permission, or no camera on the device.
      _message('เลือกรูปไม่สำเร็จ ลองอีกครั้ง');
    }
  }

  /// The header's round action: choose the photo the post leads with.
  ///
  /// A cover has to be a photo the post actually carries — publishing marks
  /// one of the uploaded media as the cover — so this adds it to the first
  /// spot and then points the cover at it.
  Future<void> _pickCover() async {
    final before = _blocks.first.items.first.imagePaths.length;
    await _pickPhoto(0);
    if (!mounted) return;
    final paths = _blocks.first.items.first.imagePaths;
    if (paths.length <= before) return;
    setState(() => _coverPath = paths.last);
    _saveLocal();
    _message('ตั้งเป็นรูปหน้าปกแล้ว');
  }

  void _cancelArrangement() {
    _arrangement++;
    setState(() => _arranging = false);
  }

  /// The draft trip the photos and the assistant both need.
  ///
  /// Shares [_createKey] and [_creationTitle] with publish, so a draft made
  /// here is the one publish goes on to fill in — never a second trip. Returns
  /// false when the traveller backed out of naming it.
  Future<bool> _ensureDraftTrip(PlunoApi api) async {
    if (_draftId != null) return true;

    // `POST /trips` needs both, and nothing is worth interrupting the draft
    // for: these are provisional and publish sends whatever they have become
    // by then — including the headline the assistant is about to write. The
    // stand-in destination is the photos' own coordinates, never a place name
    // the app would be making up.
    final derivedTitle = _titleForPublish(_draft);
    final title = derivedTitle.isEmpty ? 'ร่างจากรูป' : derivedTitle;
    final derivedDestination = _destinationForPublish(_draft);
    final destination = derivedDestination.isEmpty
        ? _coordinatesOfFirstPhoto() ?? 'ยังไม่ระบุ'
        : derivedDestination;

    _creationTitle ??= title;
    _creationDestination ??= destination;
    final created = await api.trips.createDraft(
        type: TripType.content,
        title: _creationTitle!,
        destination: _creationDestination!,
        idempotencyKey: _createKey);
    _draftId = created.id;
    return true;
  }

  /// The place the traveller pinned themselves, which is the only name the
  /// assistant may write into a caption.
  ///
  /// A place the assistant suggested does not count, however sure it was: a
  /// name it guessed goes public the moment the post does, while a pin it
  /// guessed stays `suggested` and never leaves the draft unseen.
  String? _confirmedPlaceName() {
    for (final block in _blocks) {
      for (final item in block.items) {
        final picked = item.place;
        if (picked != null && picked.name.trim().isNotEmpty) {
          return picked.name.trim();
        }
        final location = item.location;
        if (location?.status == ContentLocationStatus.confirmed &&
            (location?.name?.trim().isNotEmpty ?? false)) {
          return location!.name!.trim();
        }
      }
    }
    return null;
  }

  /// "13.7563, 100.4930" for the first photo that carries coordinates — a fact
  /// off the photo, standing in for a destination until publish sets the real
  /// one. Null when no photo has any.
  String? _coordinatesOfFirstPhoto() {
    for (final photo in _photoMetadata.values) {
      if (photo.hasLocation) {
        return '${photo.latitude!.toStringAsFixed(4)}, '
            '${photo.longitude!.toStringAsFixed(4)}';
      }
    }
    return null;
  }

  /// Uploads [photos] and asks the assistant for a draft.
  ///
  /// Returns false when it could not run at all — no key on the server, the
  /// quota is spent, the network is down — so the caller can still group the
  /// photos locally. The uploads are kept either way: publish reuses them
  /// rather than sending the same files twice.
  Future<bool> _draftWithAssistant(List<TripPhoto> photos, int token) async {
    // A fresh key per attempt. Replaying one returns the draft it returned
    // before, which is right for a retry and wrong for a different set of
    // photos — and the traveller may well have picked different photos.
    _assistKey = uuidV4();
    try {
      final api = await ref.read(plunoApiProvider.future);
      if (!mounted || token != _arrangement) return false;
      if (!await _ensureDraftTrip(api)) return false;
      if (!mounted || token != _arrangement) return false;

      // The endpoint takes 20 photos a call — a cost ceiling, not the post's.
      // The rest still reach the draft, at the end, with a warning.
      final sent = photos.take(_assistantPhotoLimit).toList(growable: false);
      final extra = photos.skip(_assistantPhotoLimit).toList(growable: false);

      final uploaded = <PostAssistantPhoto>[];
      for (final photo in sent) {
        if (!mounted || token != _arrangement) return false;
        final media = await _uploadForAssistant(api, photo.path);
        if (media == null) return false;
        uploaded.add(PostAssistantPhoto(
          mediaId: media.mediaId,
          takenAt: photo.captureTimestamp,
          latitude: photo.hasLocation ? photo.latitude : null,
          longitude: photo.hasLocation ? photo.longitude : null,
        ));
      }
      if (!mounted || token != _arrangement) return false;

      final notes = _postTitle.text.trim();
      final draft = await api.trips.generateContents(
        _draftId!,
        photos: uploaded,
        language: 'th',
        notes: notes.isEmpty ? null : notes,
        locationName: _confirmedPlaceName(),
        idempotencyKey: _assistKey,
      );
      if (!mounted || token != _arrangement) return false;

      _applyAssistantDraft(draft, sent, extra);
      return true;
    } on ApiException catch (error) {
      _noteAssistantFailure(_assistantFailure(error), token);
      return false;
    } on FormatException catch (error) {
      _noteAssistantFailure(error.message, token);
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Puts one photo in the trip's gallery, reusing anything already uploaded
  /// so a retry never sends the same file twice.
  Future<Media?> _uploadForAssistant(PlunoApi api, String path) async {
    final existing = _uploaded[path];
    if (existing != null) return existing;
    if (_uploaded.length >= 200) {
      _message('มีไฟล์อัปโหลดครบ 200 รูปแล้ว กรุณาจัดการ gallery ก่อนเพิ่มรูป');
      return null;
    }

    final prepared = await preparePostPhoto(path);
    try {
      final media = await api.media
          .upload(_draftId!, bytes: prepared.$1, filename: prepared.$2);
      _uploaded[path] = media;
      return media;
    } on ApiException catch (error) {
      // Same rule publish follows: a timeout or a 5xx may still have stored
      // the file, so the next attempt checks the gallery instead of resending.
      if (error.isNetworkFailure || (error.statusCode ?? 0) >= 500) {
        _uncertainUploads.add(path);
      }
      rethrow;
    }
  }

  /// Why the draft is grouped rather than written. It goes on the warnings
  /// card, not into a snack bar: the fallback shows one of its own a moment
  /// later, and the reason would be gone before it was read.
  void _noteAssistantFailure(String reason, int token) {
    if (!mounted || token != _arrangement) return;
    setState(() => _warnings = List.unmodifiable([reason]));
  }

  String _assistantFailure(ApiException error) {
    final status = error.statusCode ?? 0;
    if (status == 503) {
      return 'ผู้ช่วยเขียนโพสต์ยังไม่เปิดใช้งาน จัดรูปให้ตามเวลาและสถานที่แทน';
    }
    if (status == 429) {
      return 'ร่างด้วยผู้ช่วยบ่อยเกินกำหนด ลองใหม่ในอีกสักครู่ — จัดรูปให้ก่อน';
    }
    return 'ร่างด้วยผู้ช่วยไม่สำเร็จ (${error.message}) จัดรูปให้ตามเวลาและสถานที่แทน';
  }

  /// Lays the assistant's draft into the composer for review.
  ///
  /// Every photo that was sent comes back in some section — the server
  /// guarantees it — but anything it left out is appended rather than trusted
  /// away, and so are the photos past the per-call limit.
  void _applyAssistantDraft(
    GeneratedPostDraft draft,
    List<TripPhoto> sent,
    List<TripPhoto> extra,
  ) {
    final pathOf = <String, String>{
      for (final entry in _uploaded.entries) entry.value.mediaId: entry.key,
    };
    final warnings = <String>[...draft.warnings];

    final blocks = <_BlockFields>[];
    final placed = <String>{};
    for (var index = 0; index < draft.contents.length; index++) {
      final section = draft.contents[index];
      final paths = <String>[];
      for (final mediaId in section.mediaIds ?? const <String>[]) {
        final path = pathOf[mediaId];
        if (path == null || !placed.add(path)) continue;
        paths.add(path);
      }

      final block = _BlockFields()
        ..title.text = section.title
        ..items.first.body.text = section.content
        ..items.first.imagePaths.addAll(paths)
        ..items.first.location = section.location;
      block.listen(_refresh);
      blocks.add(block);

      final options = draft.optionsFor(index);
      if (options != null && options.options.isNotEmpty) {
        _placeOptions[block] = options;
      }
    }

    // The draft holds a card per photo it was given, so anything left over —
    // a photo the answer somehow missed, or one past the per-call ceiling —
    // gets a card of its own rather than being stacked onto the last one.
    final leftovers = <String>[
      for (final photo in sent)
        if (!placed.contains(photo.path)) photo.path,
      ...extra.map((photo) => photo.path),
    ];
    for (final path in leftovers) {
      blocks.add(_BlockFields()
        ..items.first.imagePaths.add(path)
        ..listen(_refresh));
    }
    if (extra.isNotEmpty) {
      warnings.add(
          'ส่งให้ผู้ช่วยได้ครั้งละ $_assistantPhotoLimit รูป อีก ${extra.length} รูปได้การ์ดของตัวเองไว้ให้เติมคำเอง');
    }
    if (blocks.isEmpty) {
      blocks.add(_BlockFields()..listen(_refresh));
    }

    setState(() {
      final empty = _blocks.length == 1 && _blocks.first.toTopic().isEmpty;
      if (empty) {
        final spare = _blocks.removeLast();
        _placeOptions.remove(spare);
        spare.dispose(_refresh);
      }
      _blocks.addAll(blocks);
      if (_postTitle.text.trim().isEmpty && draft.title.trim().isNotEmpty) {
        _postTitle.text = draft.title.trim();
      }
      _warnings = List.unmodifiable(warnings);
      _syncCover();
    });
    _saveLocal();
    _message('ร่างให้แล้ว ตรวจและแก้ได้ก่อนแชร์ สถานที่ต้องกดยืนยันเอง');
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
      if (_photoCount() + photos.length > 200) {
        _message('รองรับสูงสุด 200 รูปต่อโพสต์ กรุณาเลือกให้น้อยลง');
        return;
      }
      _photoMetadata.addEntries(photos.map((p) => MapEntry(p.path, p)));

      // The assistant writes the draft when it can. It needs the trip and the
      // uploaded photos first, so anything short of a working endpoint falls
      // back to grouping them here, which is what this button did before.
      if (await _draftWithAssistant(photos, token)) return;
      if (!mounted || token != _arrangement) return;

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
            ..items.first.imagePaths.addAll(group.map((p) => p.path))
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

  void _transferPhoto(int source, int photo, int target, [int? position]) =>
      _transferPhotoFrom(
          (block: source, item: 0, photo: photo), target, 0, position);

  void _transferPhotoFrom(PostPhotoMove move, int targetBlock, int targetItem,
      [int? position]) {
    final source = move.block;
    final sourceItem = move.item;
    final photo = move.photo;
    if (source >= _blocks.length ||
        sourceItem >= _blocks[source].items.length ||
        targetBlock >= _blocks.length ||
        targetItem >= _blocks[targetBlock].items.length ||
        photo >= _blocks[source].items[sourceItem].imagePaths.length) return;
    final sameItem = source == targetBlock && sourceItem == targetItem;
    if (!sameItem &&
        _blocks[targetBlock].items[targetItem].imagePaths.length >= 20) {
      _message('เพิ่มรูปได้สูงสุด 20 รูปต่อชุดข้อมูล');
      return;
    }
    final movingLegacy = _legacyUrls
        .contains(_blocks[source].items[sourceItem].imagePaths[photo]);
    if (!sameItem &&
        _blocks[targetBlock]
            .items[targetItem]
            .imagePaths
            .any((p) => _legacyUrls.contains(p) != movingLegacy)) {
      _message('กรุณาแยกรูปใหม่กับรูปแบบเดิมเป็นคนละส่วน');
      return;
    }
    setState(() {
      final path = _blocks[source].items[sourceItem].imagePaths.removeAt(photo);
      final images = _blocks[targetBlock].items[targetItem].imagePaths;
      var insertion = position ?? images.length;
      if (position != null && sameItem && photo < position) insertion--;
      images.insert(insertion.clamp(0, images.length), path);
    });
  }

  Future<void> _movePhoto(int source, int photo) async =>
      _movePhotoFrom((block: source, item: 0, photo: photo));

  Future<void> _movePhotoFrom(PostPhotoMove move) async {
    final target = await showModalBottomSheet<(int, int)>(
        context: context,
        builder: (context) => SafeArea(
              child: ListView(shrinkWrap: true, children: [
                const ListTile(title: Text('ย้ายรูปไปท้ายเนื้อหา')),
                for (var i = 0; i < _blocks.length; i++)
                  for (var item = 0; item < _blocks[i].items.length; item++)
                    ListTile(
                        title: Text(_blocks[i].items.length > 1
                            ? 'จุด ${i + 1} · ชุด ${item + 1}'
                            : 'จุด ${i + 1}'),
                        onTap: () => Navigator.pop(context, (i, item))),
              ]),
            ));
    if (mounted && target != null) {
      _transferPhotoFrom(move, target.$1, target.$2);
    }
  }

  Future<void> _pickPlace(int index, [int itemIndex = 0]) async {
    final block = _blocks[index];
    if (itemIndex >= block.items.length) return;
    final item = block.items[itemIndex];
    final hasPlace = item.place != null ||
        item.location?.status == ContentLocationStatus.confirmed ||
        item.legacyMapId != null;
    final place = await showPlacePinPicker(
      context,
      hasPlace: hasPlace,
      // Only the first item carries the assistant's candidates: they were
      // drafted for the spot, and the extra items are photo groups inside it.
      suggestions: itemIndex == 0 ? _placeOptions[block] : null,
    );
    if (place == null ||
        !mounted ||
        !_blocks.contains(block) ||
        !block.items.contains(item)) return;

    // The row itself carries only a chevron now, so taking the pin off again
    // comes back from the sheet.
    final cleared = place == clearedPlacePin;
    setState(() {
      if (itemIndex == 0) _placeOptions.remove(block);
      item.place = cleared ? null : place;
      item.location = cleared
          ? const ContentLocation(status: ContentLocationStatus.none)
          : null;
      item.legacyMapId = null;
    });
  }

  /// The เชื่อมกับแผนของฉัน step. Answers false when the traveller backed out,
  /// so the caller knows not to carry on to whatever came after it.
  Future<bool> _chooseTrip() async {
    final link = await showTripLinkPicker(context, current: _trip);
    if (link == null || !mounted) return false;
    if (link == noTripLink) {
      setState(() {
        _trip = null;
        _tripDestination = null;
      });
      return true;
    }
    try {
      final api = await ref.read(plunoApiProvider.future);
      final trip = await api.trips.byId(link.id);
      if (!mounted) return false;
      setState(() {
        _trip = link;
        _tripDestination = trip.destination;
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      // The link itself is settled — the sheet already answered with an id and
      // a title. Only the plan's destination, which merely fills the post's
      // own when it is blank, failed to load; that must not cancel publishing.
      setState(() => _trip = link);
      _message('เชื่อมแผนแล้ว แต่โหลดจุดหมายของแผนไม่สำเร็จ');
      return true;
    }
  }

  /// The bar's Next: the link step first, then publishing. Backing out of the
  /// sheet cancels the whole thing rather than posting without it.
  Future<void> _next() async {
    if (!await _chooseTrip()) return;
    if (!mounted) return;
    await _publish();
  }

  /// "06:00" for the wire, or null when the traveller never set one.
  static String? _hhmm(TimeOfDay? time) => time == null
      ? null
      : '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';

  /// The reverse, for a section coming back from the server. Anything that is
  /// not `HH:mm` is dropped rather than guessed at.
  static TimeOfDay? _timeOfDay(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
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
      PostPlace? place;
      for (final item in topic.contentItems) {
        if (item.place != null) {
          place = item.place;
          break;
        }
      }
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
          ..about = _about
          ..spotDetails =
              _blocks.map((block) => block.details).toList(growable: false)
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
        final topicItems = topic.contentItems
            .where((item) => !item.isEmpty)
            .toList(growable: false);
        final publishItems = topicItems.isEmpty && topic.title.trim().isNotEmpty
            ? [topic.contentItems.first]
            : topicItems;
        for (final item in publishItems) {
          final legacy = item.photos.where(_legacyUrls.contains).toList();
          if (legacy.isNotEmpty && legacy.length != item.photos.length) {
            throw const FormatException(
                'กรุณาแยกรูปใหม่กับรูปแบบเดิมเป็นคนละส่วน');
          }
          final ids = <String>[];
          final metadata = <PhotoMetadata>[];
          for (final path
              in item.photos.where((p) => !_legacyUrls.contains(p))) {
            final occurrence =
                occurrences.update(path, (n) => n + 1, ifAbsent: () => 0);
            final key = occurrence == 0 || path.startsWith('http')
                ? path
                : '$path::$occurrence';
            if (_uncertainUploads.contains(key) &&
                !await _resolveUpload(key, path)) return;
            if (!_uploaded.containsKey(key)) {
              if (_uploaded.length >= 200) {
                throw const FormatException(
                    'มีไฟล์อัปโหลดครบ 200 รูปแล้ว กรุณาจัดการ gallery ก่อนเพิ่มรูป');
              }
              final prepared = await preparePostPhoto(path);
              try {
                _uploaded[key] = await api.media.upload(_draftId!,
                    bytes: prepared.$1, filename: prepared.$2);
              } on ApiException catch (error) {
                if (error.isNetworkFailure || (error.statusCode ?? 0) >= 500) {
                  _uncertainUploads.add(key);
                }
                rethrow;
              }
            }
            final id = _uploaded[key]!.mediaId;
            ids.add(id);
            final m = _photoMetadata[path];
            if (m != null && (m.captureTimestamp != null || m.hasLocation)) {
              metadata.add(PhotoMetadata(
                  mediaId: id,
                  takenAt: m.captureTimestamp,
                  latitude: m.hasLocation ? m.latitude : null,
                  longitude: m.hasLocation ? m.longitude : null));
            }
          }
          final location = item.place == null
              ? item.location
              : ContentLocation(
                  status: ContentLocationStatus.confirmed,
                  name: item.place!.name,
                  // `/places/search` answers with coordinates, and the content
                  // location takes them — dropping them would lose the pin.
                  placeId: item.place!.placeId,
                  latitude: item.place!.latitude,
                  longitude: item.place!.longitude);
          contents.add(TripContentRequest(
              title: topic.title,
              content: item.body,
              mediaIds: legacy.isEmpty ? ids : null,
              imageUrls: legacy,
              location: item.legacyMapId != null && location == null
                  ? null
                  : location ??
                      const ContentLocation(status: ContentLocationStatus.none),
              mapId: location == null ? item.legacyMapId : null,
              photoMetadata: metadata,
              visitedAt: _hhmm(topic.details.visitedAt),
              opensAt: _hhmm(topic.details.opensAt),
              closesAt: _hhmm(topic.details.closesAt),
              transportModes: topic.details.transportModes,
              transportCost: topic.details.transportCost,
              // Only alongside an amount: a currency on its own says nothing.
              transportCurrency:
                  topic.details.transportCost == null ? null : 'THB',
              tripHack: topic.details.hasHack
                  ? topic.details.tripHack.trim()
                  : null));
        }
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
      final overview = _about.overview.trim();
      await api.trips.update(_draftId!,
          type: TripType.content,
          title: title,
          destination: destination,
          // Only when something was chosen: an empty list would clear whatever
          // the trip already carries.
          travelStyles: _styles.isEmpty ? null : _styles,
          // The brief merges per key, so an empty list would clear whatever the
          // trip already carries rather than leaving it alone.
          customStyles: _customStyles.isEmpty ? null : _customStyles,
          // The เชื่อมกับแผนของฉัน step: a plan links, confirming with none
          // unlinks, and both are deliberate answers the traveller just gave.
          linkedTripId: _trip == null
              ? const Patch<String>.clear()
              : Patch<String>.value(_trip!.id),
          // About trip. `specialNotes` is write-only on this API — it goes up
          // and never comes back on the trip — so the overview survives the
          // publish but not a reopen; the local draft is what restores it.
          specialNotes: overview.isEmpty ? null : overview,
          // Stored exactly as typed: the server does no per-head arithmetic,
          // so "ต่อคน" stays the app's reading of the same number.
          budgetLimit: _about.budget,
          budgetCurrency: _about.budget == null ? null : _about.currency,
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

  /// Floated clear of the pinned action bar: a docked snack bar lands exactly
  /// on top of Save Draft and Share PunGuide and swallows taps meant for them.
  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 88 + MediaQuery.paddingOf(context).bottom,
        ),
      ));
  }

  /// The rows the design draws but the trip API has no field for yet.
  ///
  /// `POST /trips` runs `forbidNonWhitelisted`, so an invented key fails the
  /// whole request — these stay unsent until the API grows a home for them
  /// rather than being smuggled into `content`.
  /// Opens the About trip sheet. Backing out leaves what was there — only
  /// ตกลง writes, including writing a field back to empty on purpose.
  Future<void> _editAbout() async {
    final result = await showAboutTripSheet(context, current: _about);
    if (result == null || !mounted) return;
    setState(() => _about = result);
    _saveLocal();
  }

  /// Opens the sheet behind one of the three chips and keeps what it answers.
  ///
  /// These are drawn and drafted but never published: a content section holds
  /// a title, a body, media, a location and photo metadata, and `/trips`
  /// rejects any key it does not know. The warning before publishing says so.
  Future<void> _editExtra(int index, PostSpotExtra extra) async {
    final current = _blocks[index].details;
    final updated = switch (extra) {
      PostSpotExtra.recommendTime =>
        await showRecommendTimeSheet(context, current: current),
      PostSpotExtra.howToGetHere =>
        await showTransportSheet(context, current: current),
      PostSpotExtra.tripHack =>
        await showTripHackSheet(context, current: current),
    };
    if (updated == null || !mounted) return;
    setState(() => _blocks[index].details = updated);
    _saveLocal();
  }

  /// Keeps what has been written and leaves. The draft lives in this app run,
  /// not on the server: a post only becomes a trip when it is shared.
  void _saveDraftAndClose() {
    _saveLocal();
    _message('เก็บร่างไว้ในเครื่องแล้ว');
    _close();
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
          child: Column(
            children: [
              // The dark cap runs under the status bar, so it takes the top
              // inset itself instead of sitting inside a SafeArea.
              CreatePostHeader(
                onClose: _close,
                onPickCover: _pickCover,
                onImportPhotos: _createFromPhotos,
                importing: _arranging,
                onCancelImport: _cancelArrangement,
              ),
              if (_publishing) const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  children: [
                    // Author, title and activities are one card: they all
                    // describe the post, while everything under Trip Detail
                    // describes a spot. The plan link is not here any more —
                    // it is the Next step's own screen.
                    PostIdentityCard(
                      session: session,
                      audience: _audience,
                      onChangeAudience: _pickAudience,
                      title: _postTitle.text,
                      styles: _styles,
                      customStyles: _customStyles,
                      onEditTitle: _editTitle,
                    ),
                    const SizedBox(height: 10),
                    PostAboutTripRow(about: _about, onTap: _editAbout),
                    const SizedBox(height: 10),
                    // The spots are one section of the page now, not the whole
                    // of it, so they get a heading of their own.
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Trip Detail',
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    PostWarnings(
                      warnings: _warnings,
                      onDismiss: () => setState(() => _warnings = const []),
                    ),
                    for (var index = 0; index < _blocks.length; index++) ...[
                      if (index > 0) const SizedBox(height: 18),
                      if (_blocks.length > 1)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('จุด ${index + 1}',
                                  style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                              IconButton(
                                  tooltip: 'เลื่อนขึ้น',
                                  icon:
                                      const Icon(Icons.arrow_upward, size: 18),
                                  onPressed: index == 0
                                      ? null
                                      : () => setState(() {
                                            final block =
                                                _blocks.removeAt(index);
                                            _blocks.insert(index - 1, block);
                                          })),
                              IconButton(
                                  tooltip: 'เลื่อนลง',
                                  icon: const Icon(Icons.arrow_downward,
                                      size: 18),
                                  onPressed: index == _blocks.length - 1
                                      ? null
                                      : () => setState(() {
                                            final block =
                                                _blocks.removeAt(index);
                                            _blocks.insert(index + 1, block);
                                          })),
                            ]),
                      PostBlock(
                        key: ValueKey(_blocks[index]),
                        titleController: _blocks[index].title,
                        titleFocus: _blocks[index].titleFocus,
                        bodyController: _blocks[index].body,
                        imagePath: null,
                        items: _blocks[index]
                            .items
                            .map((item) => PostBlockItem(
                                bodyController: item.body,
                                imagePaths: item.imagePaths,
                                place: item.place,
                                location: item.location,
                                legacyMapId: item.legacyMapId))
                            .toList(growable: false),
                        imagePaths: _blocks[index].imagePaths,
                        unavailableImages: _unavailablePaths,
                        coverPath: _coverPath,
                        onMoveImage: (photoIndex) =>
                            _movePhoto(index, photoIndex),
                        onDropImage: (move) =>
                            _transferPhoto(move.$1, move.$2, index),
                        onDropBeforeImage: (move, position) =>
                            _transferPhoto(move.$1, move.$2, index, position),
                        onAddItem: () => _addItem(index),
                        onRemoveItem: (itemIndex) =>
                            _removeItem(index, itemIndex),
                        onPickImageInItem: (itemIndex) =>
                            _pickPhoto(index, itemIndex),
                        onClearImagesInItem: (itemIndex) => setState(() {
                          _blocks[index].items[itemIndex].imagePaths.clear();
                          _syncCover();
                        }),
                        onRemoveImageInItem: (itemIndex, photoIndex) =>
                            setState(() {
                          _blocks[index]
                              .items[itemIndex]
                              .imagePaths
                              .removeAt(photoIndex);
                          _syncCover();
                        }),
                        onMoveImageInItem: (itemIndex, photoIndex) =>
                            _movePhotoFrom((
                          block: index,
                          item: itemIndex,
                          photo: photoIndex
                        )),
                        onDropImageInItem: (move, itemIndex) =>
                            _transferPhotoFrom(move, index, itemIndex),
                        blockIndex: index,
                        onDropBeforeImageInItem: (move, itemIndex, position) =>
                            _transferPhotoFrom(
                                move, index, itemIndex, position),
                        onPickPlaceInItem: (itemIndex) =>
                            _pickPlace(index, itemIndex),
                        onClearPlaceInItem: (itemIndex) => setState(() {
                          final item = _blocks[index].items[itemIndex];
                          item.place = null;
                          item.location = const ContentLocation(
                              status: ContentLocationStatus.none);
                          item.legacyMapId = null;
                        }),
                        onConfirmLocationInItem: (itemIndex) => setState(() {
                          final item = _blocks[index].items[itemIndex];
                          final location = item.location;
                          if (location == null) return;
                          item.location = ContentLocation(
                              status: ContentLocationStatus.confirmed,
                              name: location.name,
                              placeId: location.placeId,
                              latitude: location.latitude,
                              longitude: location.longitude);
                        }),
                        onSelectCover: (path) {
                          if (_legacyUrls.contains(path)) {
                            _message(
                                'รูปเดิมนี้ไม่มี mediaId สำหรับตั้งปก กรุณาเลือกรูปใหม่ในส่วนใหม่');
                            return;
                          }
                          setState(() => _coverPath = path);
                        },
                        onRemoveImage: (photoIndex) => setState(() {
                          _blocks[index]
                              .items
                              .first
                              .imagePaths
                              .removeAt(photoIndex);
                          _syncCover();
                        }),
                        place: _blocks[index].items.first.place,
                        onPickImage: () => _pickPhoto(index),
                        details: _blocks[index].details,
                        onExtra: (extra) => _editExtra(index, extra),
                        onClearImage: () => setState(() {
                          _blocks[index].items.first.imagePaths.clear();
                          _syncCover();
                        }),
                        onPickPlace: () => _pickPlace(index),
                        onClearPlace: () => setState(() {
                          final item = _blocks[index].items.first;
                          item.place = null;
                          item.location = const ContentLocation(
                              status: ContentLocationStatus.none);
                          item.legacyMapId = null;
                        }),
                        onRemove: _blocks.length == 1
                            ? null
                            : () => _removeBlock(index),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AddSpotButton(onTap: _addBlock),
                  ],
                ),
              ),
              PostActionBar(
                onSaveDraft: _saveDraftAndClose,
                onShare: _next,
                canShare: !_publishing && !_arranging && _draft.isPublishable,
                busy: _publishing || _arranging,
              ),
            ],
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
  final FocusNode titleFocus = FocusNode();
  final List<_BlockItemFields> items = [_BlockItemFields()];

  /// The three extras. They never leave the app — no content field holds
  /// them — so they live here and in the local draft only.
  PostSpotDetails details = const PostSpotDetails();

  TextEditingController get body => items.first.body;
  List<String> get imagePaths => items.length == 1
      ? items.first.imagePaths
      : items.expand((item) => item.imagePaths).toList(growable: false);

  PostTopic toTopic() => PostTopic(
        details: details,
        title: title.text,
        body: body.text,
        imagePaths: List.of(items.first.imagePaths),
        items: items
            .map((item) => PostTopicItem(
                  body: item.body.text,
                  imagePaths: List.of(item.imagePaths),
                  place: item.place,
                  location: item.location,
                  legacyMapId: item.legacyMapId,
                ))
            .toList(growable: false),
        place: items.first.place,
        location: items.first.location,
        legacyMapId: items.first.legacyMapId,
      );

  void replaceItems(List<PostTopicItem> topics) {
    for (final item in items) {
      item.dispose(null);
    }
    items
      ..clear()
      ..addAll(topics.map((topic) => _BlockItemFields()
        ..body.text = topic.body
        ..imagePaths.addAll(topic.photos)
        ..place = topic.place
        ..location = topic.location
        ..legacyMapId = topic.legacyMapId));
    if (items.isEmpty) items.add(_BlockItemFields());
  }

  void copyLegacyPlaceToFirstItem(PostTopic topic) {
    if (topic.items.isNotEmpty) return;
    items.first
      ..place = topic.place
      ..location = topic.location
      ..legacyMapId = topic.legacyMapId;
  }

  void collapseToSingleItem(VoidCallback onChanged) {
    if (items.length == 1) return;
    final first = items.first;
    for (final item in items.skip(1)) {
      first.imagePaths.addAll(item.imagePaths);
      if (first.body.text.trim().isEmpty && item.body.text.trim().isNotEmpty) {
        first.body.text = item.body.text;
      }
      if (first.place == null &&
          first.location == null &&
          first.legacyMapId == null) {
        first.place = item.place;
        first.location = item.location;
        first.legacyMapId = item.legacyMapId;
      }
      item.dispose(onChanged);
    }
    items.removeRange(1, items.length);
  }

  void listen(VoidCallback onChanged) {
    title.addListener(onChanged);
    for (final item in items) {
      item.listen(onChanged);
    }
  }

  void dispose(VoidCallback onChanged) {
    title.removeListener(onChanged);
    title.dispose();
    for (final item in items) {
      item.dispose(onChanged);
    }
    titleFocus.dispose();
  }
}

class _BlockItemFields {
  final TextEditingController body = TextEditingController();
  final List<String> imagePaths = [];
  PostPlace? place;
  ContentLocation? location;
  String? legacyMapId;

  void listen(VoidCallback onChanged) => body.addListener(onChanged);

  void dispose(VoidCallback? onChanged) {
    if (onChanged != null) body.removeListener(onChanged);
    body.dispose();
  }
}

Future<TripPhoto> _readPhoto((Uint8List, String) input) =>
    readTripPhoto(input.$1, input.$2);
