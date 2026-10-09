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
import '../../location_access/data/location_sync.dart';
import '../domain/models/post_draft.dart';
import 'providers/place_pin_providers.dart';
import 'widgets/create_post_header.dart';
import 'widgets/create_from_photos_sheet.dart';
import 'widgets/photo_source_sheet.dart';
import 'widgets/place_pin_picker.dart';
import 'widgets/post_audience_chip.dart';
import 'widgets/post_about_trip.dart';
import 'widgets/post_action_bar.dart';
import 'widgets/post_spot_details.dart';
import 'widgets/post_title_field.dart';
import 'widgets/post_warnings.dart';
import 'widgets/post_block.dart';
import 'widgets/trip_spot_pagination.dart';
import 'widgets/trip_spot_reorder_sheet.dart';

/// What `POST /trips/:id/contents/generate` takes in one call. A cost ceiling
/// billed per photo, not a limit on the post, which still holds 200.
const _assistantPhotoLimit = 20;

/// The stand-in title `_ensureDraftTrip` sends when nothing else names the
/// post yet. It is not the traveller's own words, so the assistant is still
/// free to overwrite it later — unlike anything they typed themselves.
const _placeholderPostTitle = 'ร่างจากรูป';

/// The post's own title, once publishing has exhausted every other answer —
/// a manual one, every content's own heading, every content's own location.
/// Post Title is optional by design; this is what "optional" resolves to,
/// never a reason to stop the traveller and ask.
const _defaultPostTitle = 'ทริปของฉัน';

/// Same idea for the destination, which the API still needs some string for
/// even though Post Location itself has nothing to fall back to.
const _defaultPostDestination = 'ยังไม่ระบุ';

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

  /// One list of per-item details per block — each item in a section now
  /// answers for its own extras, not the section as a whole.
  List<List<PostSpotDetails>> spotDetails = const [];

  /// The cover media was uploaded by this composer, so it is ours to
  /// clean up once it stops being the cover.
  bool coverMediaIsOurs = false;
  bool coverOffPage = false;
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

  /// The spot on screen — kept apart from [_blocks] itself, and always by a
  /// block's own stable [_BlockFields.id] rather than its position, so an add,
  /// a delete or a drag in the reorder sheet can never leave it pointing at
  /// the wrong spot (or past the end of a shorter list).
  int _currentBlockIndex = 0;

  /// Content items "เพิ่มจุดต่อไป"/"Next" have flagged for having no
  /// location — mandatory for every item, not just a section's first — by
  /// the item's own [_BlockItemFields.id], never by page/display order,
  /// since a drag in the reorder sheet must not leave the error pointing at
  /// the wrong item. Cleared as soon as a location actually lands on that
  /// item; "Save Draft" never consults this at all.
  final Set<String> _locationErrorItemIds = {};

  /// Where "เพิ่มจุดต่อไป"/"Next" scroll to when they flag an item — one key
  /// per item id, never a single shared key: `AnimatedSwitcher` keeps the
  /// outgoing `PostBlock` mounted beside the incoming one for its crossfade,
  /// and a key shared between them collides the instant both exist at once.
  final Map<String, GlobalKey> _locationFieldKeys = {};

  GlobalKey _locationFieldKeyFor(String itemId) =>
      _locationFieldKeys.putIfAbsent(itemId, GlobalKey.new);

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

  /// The cover came from the header, so it belongs to no spot. Nothing on the
  /// page carries it, which means nothing on the page can take it away either
  /// — see [_syncCover].
  bool _coverOffPage = false;
  String? _savedCoverId;
  bool _coverMediaIsOurs = false;
  String _createKey = uuidV4();
  String? _creationTitle, _creationDestination;
  final _postTitle = TextEditingController();

  /// What the whole trip was about, and what it cost per head. Both optional.
  PostAboutTrip _about = const PostAboutTrip();
  final _postDestination = TextEditingController();

  /// Where the post is about as a whole, picked in the Title sheet. Its name
  /// is what fills `_postDestination`; the object itself is kept so the sheet
  /// can reopen on the same place.
  PostPlace? _postPlace;

  /// True once the traveller has had a say about the post's place — they chose
  /// one, or they took one off. After that the app never fills it in again.
  bool _placeIsTheirs = false;

  /// True while `_postPlace` is only the assistant's own guess — never the
  /// traveller's. A guess is fair game for the next "Create from Photos" to
  /// replace; the traveller's own answer never is.
  bool _placeSuggestedByDraft = false;

  /// The account's stored place, read once on open — kept for the Title
  /// sheet's Add Location row, which shows it as a hint and never writes it
  /// anywhere itself. `_loadAccountFix` separately adopts it as the identity
  /// card's pin — see that method — but that copy lives in `_postPlace`, not
  /// here.
  UserLocation? _accountFix;
  final Set<String> _uncertainUploads = {},
      _legacyUrls = {},
      _unavailablePaths = {};
  final Map<String, TripPhoto> _photoMetadata = {};

  /// Drops the cover when the photo it pointed at has left the page.
  ///
  /// A cover chosen from the header is not one of the page's photos, so there
  /// is nothing for it to have left — it stays until the traveller clears it.
  void _syncCover() {
    if (_coverOffPage) return;
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
        _coverMediaIsOurs = resume.coverMediaIsOurs;
        _coverOffPage = resume.coverOffPage;
        _createKey = resume.key;
        _creationTitle = resume.creationTitle;
        _creationDestination = resume.creationDestination;
        _postTitle.text = resume.title;
        _about = resume.about;
        for (var i = 0;
            i < resume.spotDetails.length && i < _blocks.length;
            i++) {
          final itemDetails = resume.spotDetails[i];
          for (var j = 0;
              j < itemDetails.length && j < _blocks[i].items.length;
              j++) {
            _blocks[i].items[j].details = itemDetails[j];
          }
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
      final linked = trip.linkedTrip;
      if (linked != null) {
        _trip = PostTripLink(id: linked.id, title: linked.title);
      }
      _about = PostAboutTrip(
        overview: trip.description ?? '',
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
        item.details = PostSpotDetails(
          visitedAt: _timeOfDay(section.visitedAt),
          opensAt: _timeOfDay(section.opensAt),
          closesAt: _timeOfDay(section.closesAt),
          transportModes: section.transportModes,
          transportCost: section.transportCost,
          tripHack: section.tripHack ?? '',
          contactInfo: section.contactInfo ?? '',
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
              _coverMediaIsOurs = true;
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

    _loadAccountFix();
  }

  /// `GET /users/me/location`, read once on open.
  ///
  /// When nothing has answered "where is this post about" yet, the stored
  /// place also seeds the identity card's pin. It goes in
  /// through `_adoptDraftPlace`, so it stays a suggestion: the traveller's own
  /// pick, or a "Create from Photos" draft's own place, still replaces it
  /// freely. [_placeAnswered] is the same "has this already been answered"
  /// check `_adoptDraftPlace` makes, checked here first too so a trip that
  /// already has a destination — reopened for editing — is left alone.
  Future<void> _loadAccountFix() async {
    final fix = await ref.read(locationSyncProvider).pull();
    if (!mounted) return;
    setState(() => _accountFix = fix);
    if (fix == null || _placeAnswered) return;
    // Already one of our places — the account stores a `places` row, not a
    // point — so it adopts as is, with no lookup to resolve it.
    _adoptDraftPlace(postPlaceFromSearchResult(fix.place));
  }

  /// True once nothing more should be guessed about the post's place: the
  /// traveller answered it themselves, or a trip opened for editing already
  /// carries a destination and no suggestion has offered anything better yet.
  bool get _placeAnswered =>
      _placeIsTheirs ||
      (!_placeSuggestedByDraft && _postDestination.text.trim().isNotEmpty);

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

  /// Whether a single item carries a location.
  bool _itemHasLocation(_BlockItemFields item) =>
      item.place != null ||
      item.location?.status == ContentLocationStatus.confirmed;

  /// Every item in [block] that still needs a location — mandatory for all
  /// of them now, not just the first.
  List<String> _invalidItemIds(_BlockFields block) => [
        for (final item in block.items)
          if (!_itemHasLocation(item)) item.id,
      ];

  /// Whether every item in a spot carries a location.
  bool _blockHasLocation(_BlockFields block) => _invalidItemIds(block).isEmpty;

  void _scrollToLocationField(String itemId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _locationFieldKeys[itemId]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    });
  }

  void _addBlock() {
    final current = _blocks[_currentBlockIndex];
    final invalid = _invalidItemIds(current);
    if (invalid.isNotEmpty) {
      setState(() => _locationErrorItemIds.addAll(invalid));
      _scrollToLocationField(invalid.first);
      return;
    }
    if (_blocks.length >= 100) {
      _message('เพิ่มเนื้อหาได้สูงสุด 100 ส่วน');
      return;
    }
    final fields = _BlockFields()..listen(_refresh);
    setState(() {
      _blocks.add(fields);
      // The point of "เพิ่มจุดต่อไป": land on the spot it just made.
      _currentBlockIndex = _blocks.length - 1;
    });
  }

  void _removeBlock(int index) {
    // The last spot never goes — same invariant the "ลบจุดนี้" row already
    // enforces by hiding itself; the reorder sheet enforces it the same way.
    if (_blocks.length <= 1) return;
    final fields = _blocks[index];
    final viewedId = _blocks[_currentBlockIndex].id;
    setState(() {
      _blocks.removeAt(index);
      for (final item in fields.items) {
        _locationErrorItemIds.remove(item.id);
        _locationFieldKeys.remove(item.id);
      }
      _syncCover();
      final stillThere = _blocks.indexWhere((block) => block.id == viewedId);
      _currentBlockIndex = stillThere >= 0
          ? stillThere
          : _currentBlockIndex.clamp(0, _blocks.length - 1);
    });
    fields.dispose(_refresh);
  }

  /// What the reorder sheet's own delete button calls — by id, since a spot's
  /// position there is a snapshot that may already have moved.
  void _removeBlockById(String id) {
    final index = _blocks.indexWhere((block) => block.id == id);
    if (index != -1) _removeBlock(index);
  }

  /// A drag in the reorder sheet. [newIndex] arrives already adjusted for
  /// [oldIndex] having been removed — `ReorderableListView.onReorderItem`'s
  /// own contract — so this is a plain remove-then-insert, the same the sheet
  /// does to its own copy.
  void _reorderBlocks(int oldIndex, int newIndex) {
    final viewedId = _blocks[_currentBlockIndex].id;
    setState(() {
      final block = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, block);
      _currentBlockIndex = _blocks.indexWhere((b) => b.id == viewedId);
    });
  }

  /// How many of a spot's items actually carry a place — "Spot 1 • 1 place"
  /// in the reorder sheet.
  int _placeCount(_BlockFields block) => block.items
      .where((item) =>
          item.place != null ||
          item.location?.status == ContentLocationStatus.confirmed)
      .length;

  Future<void> _openReorderSheet() async {
    await showTripSpotReorderSheet(
      context,
      spots: [
        for (final block in _blocks)
          ReorderableSpot(
            id: block.id,
            title: block.title.text,
            thumbnailPath:
                block.imagePaths.isEmpty ? null : block.imagePaths.first,
            placeCount: _placeCount(block),
          ),
      ],
      onReorder: _reorderBlocks,
      onDelete: _removeBlockById,
    );
  }

  /// "+ เพิ่มเนื้อหา" — another content item under this spot's own heading,
  /// never a new spot of its own.
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
      _locationErrorItemIds.remove(item.id);
      _locationFieldKeys.remove(item.id);
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
      about: _about,
      place: _postPlace,
      accountFix: _accountFix,
    );
    if (result == null || !mounted) return;
    setState(() {
      _postTitle.text = result.title;
      _styles = List.unmodifiable(result.styles);
      _customStyles = List.unmodifiable(result.customStyles);
      _about = result.about;
      // Taking the place off has to empty the destination too, or publishing
      // would keep sending the one the traveller just removed.
      if (result.clearedPlace) {
        _placeIsTheirs = true;
        _postPlace = null;
        _postDestination.clear();
      } else if (result.place != null) {
        _placeIsTheirs = true;
        _fillPlace(result.place!);
      }
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
      TripPhoto? metadata;
      try {
        final read =
            await compute(_readPhoto, (await image.readAsBytes(), image.path));
        _photoMetadata[image.path] = read;
        metadata = read;
      } catch (_) {}
      if (!mounted || !_blocks.contains(block) || !block.items.contains(item)) {
        return;
      }
      setState(() {
        item.imagePaths.add(image.path);
        _syncCover();
      });
      if (metadata != null && metadata.hasLocation) {
        await _suggestPlaceFromPhoto(block, item, metadata);
      }
    } catch (_) {
      // A denied permission, or no camera on the device.
      _message('เลือกรูปไม่สำเร็จ ลองอีกครั้ง');
    }
  }

  /// Offers a nearby place for a spot that has nothing to say about where it
  /// is yet, the moment a photo added to it turns out to carry GPS — the same
  /// lookup "Create from Photos" already runs, just reached through this door
  /// too. Still only ever `suggested`: the traveller confirms it themselves.
  Future<void> _suggestPlaceFromPhoto(
      _BlockFields block, _BlockItemFields item, TripPhoto metadata) async {
    final hasPlace = item.place != null ||
        (item.location != null &&
            item.location!.status != ContentLocationStatus.none) ||
        item.legacyMapId != null;
    if (hasPlace) return;

    try {
      final api = await ref.read(plunoApiProvider.future);
      final nearby = await api.places.suggest(
        latitude: metadata.latitude!,
        longitude: metadata.longitude!,
        radiusMeters: 150,
        limit: 1,
      );
      if (!mounted || !_blocks.contains(block) || !block.items.contains(item)) {
        return;
      }
      // Nothing must have answered this in the meantime — another photo's
      // own GPS, or the traveller picking one by hand while this was in
      // flight — either already beats a guess from a single picture.
      final stillUnanswered = item.place == null &&
          (item.location == null ||
              item.location!.status == ContentLocationStatus.none) &&
          item.legacyMapId == null;
      if (stillUnanswered && nearby.isNotEmpty) {
        final place = nearby.first;
        setState(() {
          item.location = ContentLocation(
            status: ContentLocationStatus.suggested,
            name: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
          );
        });
        _saveLocal();
      }
    } catch (_) {
      // No worse than the photo carrying no location at all.
    }
  }

  /// The header's round action: the photo the post leads with, and nothing
  /// else. It joins no spot, so it never turns up in the story as a picture
  /// the traveller did not put there.
  ///
  /// It is still uploaded at publish and pointed at with `media.setCover` —
  /// see the cover step in [_publish].
  Future<void> _pickCover() async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;
    try {
      final image = await _picker.pickImage(source: source);
      if (image == null || !mounted) return;
      // Deliberately not read for EXIF. A cover is decoration; letting its
      // coordinates stand in for the trip's destination, or its timestamp
      // order the spots, would be the picture deciding what the post says.
      setState(() {
        _coverPath = image.path;
        _coverOffPage = true;
      });
      _saveLocal();
      _message('ตั้งเป็นรูปหน้าปกแล้ว');
    } catch (_) {
      if (mounted) {
        _message(
            'เลือกรูปไม่สำเร็จ กรุณาตรวจสิทธิ์แล้วลองอีกครั้ง ร่างเดิมยังอยู่');
      }
    }
  }

  /// Takes the cover off without touching whatever spot the photo may sit in.
  void _clearCover() {
    setState(() {
      _coverPath = null;
      _coverOffPage = false;
    });
    _saveLocal();
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
    final title = derivedTitle.isEmpty ? _placeholderPostTitle : derivedTitle;
    final derivedDestination = _destinationForPublish(_draft);
    final destination = derivedDestination.isEmpty
        ? _coordinatesOfFirstPhoto() ?? _defaultPostDestination
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

  /// Fills the post's place in from where the traveller is, when they have not
  /// said anything about it themselves.
  ///
  /// Only ever fills a blank. The moment they pick a place or take one off the
  /// app stops guessing, because a post opened to be edited days later would
  /// otherwise be retagged with wherever it is being written.
  void _adoptNearbyPlace(PostPlace place) {
    if (_placeIsTheirs || _postPlace != null) return;
    // A trip opened for editing arrives with its destination already written;
    // that is an answer too, even without a place object behind it.
    if (_postDestination.text.trim().isNotEmpty) return;

    _fillPlace(place);
    if (!mounted) return;
    setState(() {});
    _saveLocal();
  }

  /// Fills the post's place in from the assistant's own draft — the place and
  /// area it just wrote the post about.
  ///
  /// Unlike [_adoptNearbyPlace], this replaces a guess already sitting there:
  /// running "Create from Photos" again means a newer suggestion, and an old
  /// one the traveller never confirmed should not survive it. It still never
  /// touches a place the traveller picked or removed themselves.
  void _adoptDraftPlace(PostPlace place) {
    if (_placeAnswered) return;

    _fillPlace(place);
    _placeSuggestedByDraft = true;
    if (!mounted) return;
    setState(() {});
    _saveLocal();
  }

  /// The one place `_postPlace` and the destination are written together, so
  /// they cannot drift apart.
  void _fillPlace(PostPlace place) {
    _postPlace = place;
    _postDestination.text = place.area?.trim().isNotEmpty == true
        ? place.area!.trim()
        : place.name.trim();
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
  /// [fromCamera] says the photos were taken just now, which is the only case
  /// where where the traveller is standing describes where the photos are of.
  /// A library photo instead falls back to the account's own fix, but only
  /// once every photo sent has turned up with no EXIF GPS of its own — see
  /// the `origin` note below.
  Future<bool> _draftWithAssistant(List<TripPhoto> photos, int token,
      {required bool fromCamera, PostPlace? selectedPlace}) async {
    // A fresh key per attempt. Replaying one returns the draft it returned
    // before, which is right for a retry and wrong for a different set of
    // photos — and the traveller may well have picked different photos.
    final assistKey = uuidV4();
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
      // Withheld for anything out of the library that says where it was
      // taken. A photo just taken is where the traveller is; one picked from
      // the library could be last year's, from a city they are not in, and
      // guessing places near the desk they are writing at would be worse than
      // offering none — but that only holds while some photo still answers
      // for itself. When none of them do, and the traveller has not either,
      // the account's own fix is the last fallback: still only a hint the
      // assistant may suggest, never one it may confirm.
      final selectedId = selectedPlace?.id;
      // Search/nearby rows carry internal UUIDs; AI/map pins may instead
      // carry a Google ID and must stay on the legacy name-based path.
      final selectedPlaceId = selectedId != null &&
              RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
                  .hasMatch(selectedId)
          ? selectedId
          : null;
      ({double lat, double lng})? origin;
      if (selectedPlaceId == null) {
        if (fromCamera) {
          origin = ref.read(placePinOriginProvider);
        } else if (!sent.any((photo) => photo.hasLocation)) {
          final fix = _accountFix;
          if (fix != null) origin = (lat: fix.latitude, lng: fix.longitude);
        }
      }
      final locationName = selectedPlaceId == null
          ? selectedPlace?.name ?? _confirmedPlaceName()
          : null;
      final tripId = _draftId!;
      final requestPhotos = List<PostAssistantPhoto>.unmodifiable(uploaded);
      final draft = await _generateWithRetry(
        () => api.trips.generateContents(
          tripId,
          photos: requestPhotos,
          language: 'th',
          notes: notes.isEmpty ? null : notes,
          selectedPlaceId: selectedPlaceId,
          locationName: locationName,
          currentLat: origin?.lat,
          currentLng: origin?.lng,
          idempotencyKey: assistKey,
        ),
        token,
      );
      if (draft == null) return false;
      if (!mounted || token != _arrangement) return false;

      await _applyAssistantDraft(api, draft, sent, extra);
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

  /// Retries a frozen request. A retry never re-reads the form or uploads.
  Future<GeneratedPostDraft?> _generateWithRetry(
    Future<GeneratedPostDraft> Function() request,
    int token,
  ) async {
    var conflictRetries = 0;
    while (mounted && token == _arrangement) {
      try {
        return await request();
      } on ApiException catch (error) {
        if (!mounted || token != _arrangement) return null;
        if (error.statusCode == 409 && conflictRetries < 4) {
          await Future<void>.delayed(Duration(seconds: 1 << conflictRetries));
          conflictRetries++;
          continue;
        }
        final retryable = error.isNetworkFailure ||
            error.statusCode == 409 ||
            (error.statusCode ?? 0) >= 500;
        if (!retryable) rethrow;
        final retry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(error.statusCode == 409
                ? 'กำลังสร้างร่างอยู่'
                : 'ยังรับร่างไม่สำเร็จ'),
            content: Text(error.statusCode == 409
                ? 'ระบบยังทำงานกับคำขอนี้อยู่ ลองตรวจอีกครั้งได้โดยไม่เริ่มสร้างร่างใหม่'
                : '${error.message}\nลองอีกครั้งด้วยรูปและสถานที่เดิม หรือใช้รูปเขียนโพสต์ต่อเอง'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('ใช้รูปเขียนต่อเอง')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('ลองอีกครั้ง')),
            ],
          ),
        );
        if (!mounted || token != _arrangement) return null;
        if (retry != true) {
          _noteAssistantFailure(_assistantFailure(error), token);
          return null;
        }
        // Another bounded polling cycle, with the same key and body.
        if (error.statusCode == 409) {
          conflictRetries = 0;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
    }
    return null;
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
    if (status == 404) {
      return 'ไม่พบทริปหรือสถานที่ที่เลือก กรุณาเลือกสถานที่ใหม่แล้วสร้างร่างอีกครั้ง';
    }
    if (status == 400) {
      return 'ข้อมูลสร้างร่างไม่ถูกต้อง: ${error.message}';
    }
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
  Future<void> _applyAssistantDraft(
    PlunoApi api,
    GeneratedPostDraft draft,
    List<TripPhoto> sent,
    List<TripPhoto> extra,
  ) async {
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

      final options = draft.optionsFor(index);
      // The traveller's own words, if the section already carries any, always
      // win — this is only ever a starting point, the same way opensAt and
      // closesAt already arrive pre-filled from the same lookup.
      final contactInfo = (section.contactInfo?.trim().isNotEmpty ?? false)
          ? section.contactInfo!
          : _contactInfoText(options?.contactInfo);
      final block = _BlockFields()
        ..title.text = section.title
        ..items.first.details = PostSpotDetails(
          visitedAt: _timeOfDay(section.visitedAt),
          opensAt: _timeOfDay(section.opensAt),
          closesAt: _timeOfDay(section.closesAt),
          transportModes: section.transportModes,
          transportCost: section.transportCost,
          tripHack: section.tripHack ?? '',
          contactInfo: contactInfo,
        )
        ..items.first.body.text = section.content
        ..items.first.imagePaths.addAll(paths)
        ..items.first.location = section.location;
      block.listen(_refresh);
      blocks.add(block);

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
      // A blank field or the app's own placeholder are both fair game; only
      // words the traveller actually typed are left alone.
      final currentTitle = _postTitle.text.trim();
      if ((currentTitle.isEmpty || currentTitle == _placeholderPostTitle) &&
          draft.title.trim().isNotEmpty) {
        _postTitle.text = draft.title.trim();
      }
      _warnings = List.unmodifiable(warnings);
      _syncCover();
    });
    // The draft's own destination — what the post is actually about — beats a
    // guess at where the traveller was standing, so it gets first refusal on
    // the identity card's pin. Resolved through a real search, the same way
    // a traveller's own pick is, so the card reads an actual place — name and
    // locality — rather than the bare label the model wrote.
    final draftArea = draft.area?.trim();
    if (draftArea != null && draftArea.isNotEmpty) {
      try {
        final results =
            await api.places.search(draftArea, limit: 1, resolvePhotos: false);
        if (mounted && results.isNotEmpty) {
          _adoptDraftPlace(postPlaceFromSearchResult(results.first));
        }
      } catch (_) {
        // A failed lookup just leaves the pin as whatever it already was.
      }
    }
    // The server ranked this by distance, which beats the nearest row of
    // whatever `/places/suggest` happened to return, so it is worth adopting
    // even when the client already filled the blank.
    final answered = draft.currentArea;
    if (answered != null && answered.isNearby) {
      _adoptNearbyPlace(PostPlace(
        id: answered.placeId ?? answered.name,
        name: answered.name,
        placeId: answered.placeId,
        latitude: answered.latitude,
        longitude: answered.longitude,
      ));
    }
    _saveLocal();
    _message('ร่างให้แล้ว ตรวจและแก้ได้ก่อนแชร์ สถานที่ต้องกดยืนยันเอง');
  }

  /// The header's Create from Photos, which reads the library.
  ///
  /// Asks where the photos come from first, because the answer decides more
  /// than which picker opens: only a shot taken now is somewhere the traveller
  /// actually is, so only that one sends a position — see
  /// [_draftWithAssistant].
  Future<void> _createFromPhotos() async {
    if (_arranging) return;
    final selection = await showCreateFromPhotosSheet(
      context,
      picker: _picker,
      remaining: 200 - _photoCount(),
      titleController: _postTitle,
    );
    if (selection == null || !mounted) return;
    final fromCamera = selection.fromCamera;
    final token = ++_arrangement;
    setState(() {
      _arranging = true;
      if (selection.place != null) {
        // Only a hint for the assistant, shown here for immediate feedback —
        // not the traveller's final answer, so the draft's own resolved area
        // is still free to replace it once generation comes back.
        _fillPlace(selection.place!);
        _placeSuggestedByDraft = true;
      }
    });
    try {
      final files = selection.files;
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
      if (await _draftWithAssistant(photos, token,
          fromCamera: fromCamera, selectedPlace: selection.place)) {
        return;
      }
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
            ..items.first.place = selection.place
            ..listen(_refresh));
        }
        _syncCover();
      });
      _saveLocal();
      _message(
          'จัดรูปแล้ว ตรวจและแก้ไขในเนื้อหาด้านล่าง กดค้างที่รูปเพื่อลาก หรือกดย้ายรูป');
    } catch (_) {
      if (mounted && token == _arrangement)
        _message(fromCamera
            ? 'เปิดกล้องไม่สำเร็จ กรุณาตรวจสิทธิ์กล้องแล้วลองอีกครั้ง ร่างเดิมยังอยู่'
            : 'เลือกรูปไม่สำเร็จ กรุณาตรวจสิทธิ์เข้าถึงรูปแล้วลองอีกครั้ง ร่างเดิมยังอยู่');
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
      // A real pick clears the error this instant — never waits for another
      // tap on "เพิ่มจุดต่อไป"/"Next" to notice.
      if (!cleared) _locationErrorItemIds.remove(item.id);
    });
    // Every item answers for its own "ติดต่อ"/time chips now.
    if (!cleared) _autoFillPlaceDetails(item, place.id);
  }

  /// "ยืนยันสถานที่" — the assistant's own suggestion becomes the spot's
  /// confirmed place, same as one picked by hand.
  void _confirmLocation(int index, int itemIndex) {
    final block = _blocks[index];
    final item = block.items[itemIndex];
    final location = item.location;
    if (location == null) return;
    setState(() {
      item.location = ContentLocation(
          status: ContentLocationStatus.confirmed,
          name: location.name,
          placeId: location.placeId,
          latitude: location.latitude,
          longitude: location.longitude);
      _locationErrorItemIds.remove(item.id);
    });
    _autoFillPlaceDetails(item, location.placeId);
  }

  /// Fills the existing "ติดต่อ" and time chips from Google's own data for
  /// [item]'s place, the moment one is actually added — never overwriting
  /// what the writer already typed, and silent (no message, no new row) for
  /// anywhere Google has nothing to add.
  ///
  /// `GET /places/:id` only answers for one of our own places — a legacy or
  /// hand-pinned spot with no internal id is left exactly as it was.
  Future<void> _autoFillPlaceDetails(
      _BlockItemFields item, String? placeId) async {
    if (placeId == null || placeId.isEmpty) return;
    final live = await ref.read(placeDetailsProvider(placeId).future);
    if (live == null ||
        !mounted ||
        !_blocks.any((block) => block.items.contains(item))) return;

    final phone = live.internationalPhoneNumber ?? live.nationalPhoneNumber;
    final hours = _todayOpenClose(live);
    final fillContact = !item.details.hasContact &&
        phone != null &&
        phone.trim().isNotEmpty;
    final fillHours = !item.details.hasTime && hours != null;
    if (!fillContact && !fillHours) return;

    setState(() {
      item.details = item.details.copyWith(
        contactInfo: fillContact ? phone.trim() : null,
        opensAt: fillHours ? hours.$1 : null,
        closesAt: fillHours ? hours.$2 : null,
      );
    });
  }

  /// Best-effort: today's line out of Google's own worded hours — "วันจันทร์:
  /// 10:00–20:00" — read as a plain open/close pair. Null for anything that
  /// does not look like exactly that (closed today, open 24 hours, a format
  /// this did not anticipate) rather than guessed at.
  (TimeOfDay, TimeOfDay)? _todayOpenClose(PlaceDetails live) {
    final hours = live.currentOpeningHours ?? live.regularOpeningHours;
    final days = hours?.weekdayDescriptions ?? const <String>[];
    // Google always orders this Monday through Sunday regardless of locale,
    // the same order `DateTime.weekday` counts in.
    if (days.length != 7) return null;
    final today = days[DateTime.now().weekday - 1];
    final clock = RegExp(r'(\d{1,2}):(\d{2})').allMatches(today).toList();
    if (clock.length < 2) return null;
    TimeOfDay at(RegExpMatch m) =>
        TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!));
    return (at(clock[0]), at(clock[1]));
  }

  /// The bar's Next: every spot's location first, then syncing the draft's
  /// content to the server, then the Post Share Settings screen — connecting
  /// a plan, choosing who sees it, and the remix toggle all live there now,
  /// not in a picker opened straight off this button. Its own "Share"
  /// finishes the post; popping back without sharing leaves the composer
  /// exactly where it was.
  Future<void> _next() async {
    final invalidIndex =
        _blocks.indexWhere((block) => !_blockHasLocation(block));
    if (invalidIndex != -1) {
      final invalid = _invalidItemIds(_blocks[invalidIndex]);
      setState(() {
        _currentBlockIndex = invalidIndex;
        _locationErrorItemIds.addAll(invalid);
      });
      _scrollToLocationField(invalid.first);
      return;
    }
    if (!await _syncForShare() || !mounted) return;
    final shared = await context.pushNamed<bool>(
      AppRoute.shareSettings.name,
      params: {'tripId': _draftId!},
    );
    if (shared == true && mounted) {
      _published = true;
      _message('บันทึกโพสต์เรียบร้อยแล้ว');
      _close();
    }
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

  /// A phone number and a website on one line, the way the spot's contact
  /// chip reads it back. Empty when Google gave neither.
  static String _contactInfoText(SuggestedContactInfo? contact) {
    if (contact == null) return '';
    return [
      if (contact.phoneNumber?.trim().isNotEmpty ?? false)
        contact.phoneNumber!.trim(),
      if (contact.website?.trim().isNotEmpty ?? false) contact.website!.trim(),
    ].join(' · ');
  }

  String _trimForTripField(String value) {
    final trimmed = value.trim();
    return trimmed.length <= 200 ? trimmed : trimmed.substring(0, 200);
  }

  /// The richest place a topic (a "content"/spot) carries — its own item 0
  /// first, then any other item inside it with one.
  PostPlace? _topicPlace(PostTopic topic) {
    if (topic.place != null) return topic.place;
    for (final item in topic.contentItems) {
      if (item.place != null) return item.place;
    }
    return null;
  }

  /// What a topic's place or location actually reads as a name — area over
  /// name for a place, same as the identity card shows it.
  String? _topicLocationName(PostTopic topic) {
    final place = _topicPlace(topic);
    if (place != null) {
      if (place.area != null && place.area!.trim().isNotEmpty) {
        return place.area!.trim();
      }
      if (place.name.trim().isNotEmpty) return place.name.trim();
    }
    final name = topic.location?.name?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  /// The post's own title: a manual one wins outright; otherwise the first
  /// content with a heading, then the first with a location name — this is
  /// the whole post's name, never a stand-in for an empty content heading or
  /// location of its own, which stay exactly as blank as the writer left them.
  String _titleForPublish(PostDraft draft) {
    final manual = _postTitle.text.trim();
    if (manual.isNotEmpty) return manual;
    if (_trip != null && _trip!.title.trim().isNotEmpty) {
      return _trimForTripField(_trip!.title);
    }
    for (final topic in draft.topics) {
      if (topic.title.trim().isNotEmpty) {
        return _trimForTripField(topic.title);
      }
    }
    for (final topic in draft.topics) {
      final name = _topicLocationName(topic);
      if (name != null) return _trimForTripField(name);
    }
    return '';
  }

  /// The post's own destination: a manual one wins outright; otherwise only
  /// the first content's own location — never the second, third, and so on,
  /// so a drag in the reorder sheet changes which content answers for it.
  String _destinationForPublish(PostDraft draft) {
    final manual = _postDestination.text.trim();
    if (manual.isNotEmpty) return manual;
    final linkedDestination = _tripDestination?.trim();
    if (linkedDestination != null && linkedDestination.isNotEmpty) {
      return _trimForTripField(linkedDestination);
    }
    if (draft.topics.isEmpty) return '';
    final name = _topicLocationName(draft.topics.first);
    return name == null ? '' : _trimForTripField(name);
  }

  /// Forgets what this run remembered of the draft.
  ///
  /// Save Draft is how a draft is kept, which is what lets leaving mean
  /// leaving. This only clears what the app held: a draft trip already created
  /// on the server, with whatever was uploaded to it, stays there and shows up
  /// under ทริปฉัน — nothing written is destroyed, it just stops following the
  /// composer around.
  void _clearLocal() {
    ref.read(_localDraftProvider(_storageKey).notifier).state = null;
    ref.read(_localCoverProvider(_storageKey).notifier).state = null;
    ref.read(_localPublishProvider(_storageKey).notifier).state = null;
  }

  void _saveLocal() {
    if (_published) {
      _clearLocal();
      return;
    }
    ref.read(_localPublishProvider(_storageKey).notifier).state =
        _PublishResume(
            _draftId, _savedCoverId, Map.of(_uploaded), _tripDestination)
          ..coverMediaIsOurs = _coverMediaIsOurs
          ..coverOffPage = _coverOffPage
          ..sourceId = widget.initialTrip?.id
          ..key = _createKey
          ..creationTitle = _creationTitle
          ..creationDestination = _creationDestination
          ..title = _postTitle.text
          ..about = _about
          ..spotDetails = _blocks
              .map((block) => block.items
                  .map((item) => item.details)
                  .toList(growable: false))
              .toList(growable: false)
          ..postDestination = _postDestination.text
          ..uncertain = Set.of(_uncertainUploads)
          ..legacy = Set.of(_legacyUrls)
          ..unavailable = Set.of(_unavailablePaths)
          ..metadata = Map.of(_photoMetadata);
    ref.read(_localDraftProvider(_storageKey).notifier).state = _draft;
    ref.read(_localCoverProvider(_storageKey).notifier).state = _coverPath;
  }

  /// Leaves the composer. [keepDraft] is Save Draft, which has just written
  /// the draft down and must not have it thrown away on the way out.
  void _close({bool keepDraft = false}) {
    if (_publishing) return;
    _arrangement++;
    if (!keepDraft) _clearLocal();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }

  /// Everything short of the step the share screen now owns: creates the
  /// draft trip if there isn't one yet, uploads every photo, writes the
  /// content and the post's own title/destination/styles/about. Deliberately
  /// leaves `linkedTripId` and `visibility` untouched (left out of the PATCH
  /// entirely, not cleared) — connecting a plan and choosing who sees the
  /// post are answered on `PostShareSettingsScreen`, not here.
  ///
  /// Returns whether it's safe to go on to that screen — `_draftId` is
  /// guaranteed set when this returns `true`.
  Future<bool> _syncForShare() async {
    if (_publishing || _arranging || !_draft.isPublishable) return false;
    if (_audience == PostAudience.followers) {
      _message('ขณะนี้รองรับสาธารณะและเฉพาะฉัน กรุณาเลือกผู้ชมอีกครั้ง');
      return false;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = _draft;
    // Post Title and Post Location are both optional — nothing here ever
    // stops to ask for them; a title that resolved to nothing becomes the
    // post's own default, the same way an empty content heading just stays
    // empty rather than being treated as missing.
    final resolvedTitle = _titleForPublish(draft);
    final title = resolvedTitle.isEmpty ? _defaultPostTitle : resolvedTitle;
    final resolvedDestination = _destinationForPublish(draft);
    final destination =
        resolvedDestination.isEmpty ? _defaultPostDestination : resolvedDestination;
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
                !await _resolveUpload(key, path)) return false;
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
              visitedAt: _hhmm(item.details.visitedAt),
              opensAt: _hhmm(item.details.opensAt),
              closesAt: _hhmm(item.details.closesAt),
              transportModes: item.details.transportModes,
              transportCost: item.details.transportCost,
              // Only alongside an amount: a currency on its own says nothing.
              transportCurrency:
                  item.details.transportCost == null ? null : 'THB',
              tripHack:
                  item.details.hasHack ? item.details.tripHack.trim() : null,
              contactInfo: item.details.hasContact
                  ? item.details.contactInfo.trim()
                  : null));
        }
      }
      TripContentRequest.serializeAll(contents);

      // A cover off the page is in no section, so the loop above never saw it.
      if (_coverPath != null && _coverOffPage) {
        await _uploadCover(api, _coverPath!);
      }
      final chosen = _coverPath == null ? null : _uploaded[_coverPath]?.mediaId;
      // Nothing chosen: lead with the post's own first picture rather than
      // ship a card with a blank where every other card has an image. Only
      // ever fills a blank — a trip that already has a cover keeps the one it
      // has, so editing an old post never silently re-covers it — and a post
      // with no pictures at all simply goes out without one.
      final coverId =
          chosen ?? (_savedCoverId == null ? _leadPhotoOf(contents) : null);
      var covered = coverId;
      if (covered != null) {
        try {
          await api.media.setCover(_draftId!, covered);
        } on ApiException {
          // A cover the traveller chose is part of what they asked for, so it
          // still stops the publish. One the app picked for them must not:
          // going out without a cover is a far smaller loss than the post not
          // going out at all.
          if (chosen != null) rethrow;
          _message('ตั้งรูปหน้าปกอัตโนมัติไม่สำเร็จ แต่โพสต์เผยแพร่แล้ว');
          covered = null;
        }
      }
      if (covered != null) {
        _savedCoverId = covered;
        // Ours only if this composer actually uploaded it. A post reopened for
        // editing can be covered with a picture it already had, and that one
        // is not ours to delete later.
        _coverMediaIsOurs =
            _uploaded.values.any((media) => media.mediaId == covered);
      } else if (_coverMediaIsOurs &&
          _savedCoverId != null &&
          !contents.any((s) => s.mediaIds?.contains(_savedCoverId) ?? false)) {
        // The server rejects deleting media still referenced by saved contents.
        await api.trips.update(_draftId!, contents: contents);
        final removed = _savedCoverId!;
        await api.media.delete(_draftId!, removed);
        _uploaded.removeWhere((_, m) => m.mediaId == removed);
        _savedCoverId = null;
        _coverMediaIsOurs = false;
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
          // About trip's overview is the post's blurb, so it goes in
          // `description`, which every reader sees. `specialNotes` beside it
          // is the owner's private note and must not carry public prose.
          description: overview.isEmpty ? null : overview,
          // Stored exactly as typed: the server does no per-head arithmetic,
          // so "ต่อคน" stays the app's reading of the same number.
          budgetLimit: _about.budget,
          budgetCurrency: _about.budget == null ? null : _about.currency,
          contents: contents);
      if (!mounted) return false;
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        _message(
            '${_uncertainUploads.isNotEmpty ? 'มีรูปที่ไม่ทราบผลอัปโหลด ครั้งถัดไปต้องตรวจ gallery ก่อนส่งซ้ำ: ' : _draftId == null ? '' : 'ยังเผยแพร่ไม่สำเร็จ ลองอีกครั้งได้: '}${error.message}');
      }
      return false;
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
      return false;
    } catch (_) {
      if (mounted) _message('บันทึกไม่สำเร็จ กรุณาลองอีกครั้ง');
      return false;
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
        _saveLocal();
      }
    }
  }


  /// The first picture the post carries, in the order it reads. Null when it
  /// carries none — sections can be all words, and the oldest posts reference
  /// pictures by URL with no media id behind them.
  static String? _leadPhotoOf(List<TripContentRequest> contents) {
    for (final section in contents) {
      final ids = section.mediaIds;
      if (ids != null && ids.isNotEmpty) return ids.first;
    }
    return null;
  }

  /// Puts the header's cover in the trip's gallery. Keyed by its own path,
  /// like every other upload, so a retry after a failure reuses it rather than
  /// sending the file twice.
  Future<void> _uploadCover(PlunoApi api, String path) async {
    if (_uncertainUploads.contains(path) && !await _resolveUpload(path, path)) {
      return;
    }
    if (_uploaded.containsKey(path)) return;
    if (_uploaded.length >= 200) {
      throw const FormatException(
          'มีไฟล์อัปโหลดครบ 200 รูปแล้ว กรุณาจัดการ gallery ก่อนเพิ่มรูป');
    }
    final prepared = await preparePostPhoto(path);
    try {
      _uploaded[path] = await api.media
          .upload(_draftId!, bytes: prepared.$1, filename: prepared.$2);
    } on ApiException catch (error) {
      // Same rule the section photos follow: a timeout or a 5xx may still have
      // stored the file, so the next attempt checks the gallery first.
      if (error.isNetworkFailure || (error.statusCode ?? 0) >= 500) {
        _uncertainUploads.add(path);
      }
      rethrow;
    }
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
  /// The filled About trip row reopens the Title sheet, which is where both
  /// halves of it are written now.
  void _editAbout() => _editTitle();

  /// Opens the sheet behind one of the three chips and keeps what it answers.
  ///
  /// These are drawn and drafted but never published: a content section holds
  /// a title, a body, media, a location and photo metadata, and `/trips`
  /// rejects any key it does not know. The warning before publishing says so.
  Future<void> _editExtra(
      int blockIndex, int itemIndex, PostSpotExtra extra) async {
    final item = _blocks[blockIndex].items[itemIndex];
    final current = item.details;
    final updated = switch (extra) {
      PostSpotExtra.recommendTime =>
        await showRecommendTimeSheet(context, current: current),
      PostSpotExtra.howToGetHere =>
        await showTransportSheet(context, current: current),
      PostSpotExtra.tripHack =>
        await showTripHackSheet(context, current: current),
      PostSpotExtra.contact =>
        await showContactSheet(context, current: current),
    };
    if (updated == null || !mounted) return;
    setState(() => item.details = updated);
    _saveLocal();
  }

  /// Keeps what has been written and leaves. The draft lives in this app run,
  /// not on the server: a post only becomes a trip when it is shared.
  void _saveDraftAndClose() {
    _saveLocal();
    _message('เก็บร่างไว้ในเครื่องแล้ว');
    _close(keepDraft: true);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return AppFrame(
      background: AppColors.screen,
      child: PopScope(
        // Back from spot 2+ first goes to spot 1 — leaving the screen itself
        // is only what a back on spot 1 does. `_close`'s own `Navigator.pop`
        // runs under this same scope, so this governs both the header's
        // close button and the system gesture alike.
        canPop: !_publishing && !_arranging && _currentBlockIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          // The system back gesture is leaving too, and leaving is leaving
          // however it is done.
          if (didPop) {
            _clearLocal();
            return;
          }
          if (_arranging) {
            _cancelArrangement();
            return;
          }
          if (_currentBlockIndex != 0) {
            setState(() => _currentBlockIndex = 0);
          }
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
                onClearCover: _clearCover,
                coverPath: _coverPath,
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
                      about: _about,
                      onEditAbout: _editAbout,
                      place: _postPlace,
                    ),
                    const SizedBox(height: 10),
                    PostWarnings(
                      warnings: _warnings,
                      onDismiss: () => setState(() => _warnings = const []),
                    ),
                    Builder(builder: (context) {
                      // One spot on screen at a time — pagination (below,
                      // outside this scroll view) is what moves between them,
                      // so this never renders more than one `PostBlock`'s
                      // worth of text fields, photo grids and map widgets at
                      // once. `index` is kept as the name the callback bodies
                      // below already use throughout.
                      final index = _currentBlockIndex;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: PostBlock(
                        key: ValueKey(_blocks[index].id),
                        titleController: _blocks[index].title,
                        titleFocus: _blocks[index].titleFocus,
                        bodyController: _blocks[index].body,
                        imagePath: null,
                        items: _blocks[index]
                            .items
                            .map((item) => PostBlockItem(
                                id: item.id,
                                bodyController: item.body,
                                imagePaths: item.imagePaths,
                                place: item.place,
                                location: item.location,
                                legacyMapId: item.legacyMapId,
                                details: item.details,
                                locationFieldKey:
                                    _locationFieldKeyFor(item.id),
                                locationHasError: _locationErrorItemIds
                                    .contains(item.id)))
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
                        onConfirmLocationInItem: (itemIndex) =>
                            _confirmLocation(index, itemIndex),
                        onSelectCover: (path) {
                          if (_legacyUrls.contains(path)) {
                            _message(
                                'รูปเดิมนี้ไม่มี mediaId สำหรับตั้งปก กรุณาเลือกรูปใหม่ในส่วนใหม่');
                            return;
                          }
                          setState(() {
                            _coverPath = path;
                            _coverOffPage = false;
                          });
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
                        onExtra: (itemIndex, extra) =>
                            _editExtra(index, itemIndex, extra),
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
                        locationErrorText: 'กรุณาเพิ่ม Location',
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    AddSpotButton(onTap: _addBlock),
                  ],
                ),
              ),
              if (_blocks.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                  child: TripSpotPagination(
                    count: _blocks.length,
                    currentIndex: _currentBlockIndex,
                    onSelect: (index) =>
                        setState(() => _currentBlockIndex = index),
                    onManage: _openReorderSheet,
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
  /// Local only — never sent, never read back. Pagination, the reorder sheet
  /// and `ValueKey`s all need a spot's identity to survive it changing
  /// position (or vanishing, for the rest of the list, when one is deleted),
  /// which a list index cannot do on its own.
  final String id = uuidV4();

  final TextEditingController title = TextEditingController();
  final FocusNode titleFocus = FocusNode();
  final List<_BlockItemFields> items = [_BlockItemFields()];

  TextEditingController get body => items.first.body;
  List<String> get imagePaths => items.length == 1
      ? items.first.imagePaths
      : items.expand((item) => item.imagePaths).toList(growable: false);

  PostTopic toTopic() => PostTopic(
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
                  details: item.details,
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
        ..legacyMapId = topic.legacyMapId
        ..details = topic.details));
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
      if (first.details.isEmpty) first.details = item.details;
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
  /// Stable across adds/removes/rebuilds — never the item's position, which
  /// changes the moment a sibling item is deleted. Local only: the server
  /// assigns its own ids, this is purely for `ValueKey`/widget identity.
  final String id = uuidV4();

  final TextEditingController body = TextEditingController();
  final List<String> imagePaths = [];
  PostPlace? place;
  ContentLocation? location;
  String? legacyMapId;

  /// When to go, how to get there, and the tip — one set per item. They
  /// never leave the app except through `TripContentRequest` — no other
  /// content field holds them — so they live here and in the local draft.
  PostSpotDetails details = const PostSpotDetails();

  void listen(VoidCallback onChanged) => body.addListener(onChanged);

  void dispose(VoidCallback? onChanged) {
    if (onChanged != null) body.removeListener(onChanged);
    body.dispose();
  }
}

Future<TripPhoto> _readPhoto((Uint8List, String) input) =>
    readTripPhoto(input.$1, input.$2);
