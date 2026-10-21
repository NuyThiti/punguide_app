import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/models/trip_content.dart';
import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../create_post/domain/models/post_draft.dart';
import '../../create_post/presentation/widgets/place_pin_picker.dart';
import '../../create_post/presentation/widgets/trip_link_picker.dart';
import '../../puntok/domain/models/puntok_post.dart';
import '../../puntok/presentation/providers/puntok_providers.dart';
import '../domain/puntok_clip.dart';
import 'providers/puntok_clip_stills.dart';
import 'widgets/puntok_clip_editor.dart';
import 'widgets/puntok_clip_picker.dart';
import 'widgets/puntok_composer.dart';
import 'widgets/puntok_sheets.dart';

enum _Step { pick, edit, compose }

/// The post's title when the caption gives none.
const _defaultTitle = 'Puntok';

/// The post's destination when no place was pinned — the same placeholder
/// the post composer sends.
const _defaultDestination = 'ยังไม่ระบุ';

/// Opens the system picker on videos and photos alike — `image_picker` has
/// no videos-only multi-pick — and the screen keeps only the videos.
Future<List<XFile>> _pickFromLibrary() => ImagePicker().pickMultipleMedia();

/// Create Puntok (Figma 2532-98219): pick clips → cut them → write it up.
///
/// One route with three faces rather than three routes, so backing out of a
/// step keeps everything chosen on it — the draft lives here, not in a
/// provider, and goes when the screen does.
///
/// A Puntok is a post (`type: content`): Save Draft and Puntok upload each
/// picked clip to `POST /media` as it is, then save one section carrying
/// their `mediaIds` in cut order through `POST /trips/posts` (and
/// `PUT /trips/posts/:id` after the first save). The editor's cut is not
/// exported — the server does no editing and the app has no encoder yet.
///
/// The Puntok feed reads the same posts back from `GET /trips`; a shared clip
/// is also put at the head of For you by hand, so it shows before the list
/// has caught up with it.
class CreatePuntokScreen extends ConsumerStatefulWidget {
  const CreatePuntokScreen({
    super.key,
    this.clips = const [],
    this.pickVideos = _pickFromLibrary,
  });

  /// Clips already in the grid when it opens.
  final List<PuntokClip> clips;

  /// The system picker; tests hand in their own files.
  final Future<List<XFile>> Function() pickVideos;

  @override
  ConsumerState<CreatePuntokScreen> createState() => _CreatePuntokScreenState();
}

class _CreatePuntokScreenState extends ConsumerState<CreatePuntokScreen> {
  _Step _step = _Step.pick;

  late final _library = <PuntokClip>[...widget.clips];
  final _selected = <PuntokClip>[];
  bool _adding = false;

  final _caption = TextEditingController();
  PuntokClip? _cover;
  PuntokActivities _activities = const PuntokActivities();
  PostPlace? _place;
  PostTripLink? _trip;
  PuntokVisibility _visibility = PuntokVisibility.public;
  bool _remixOn = false;
  PuntokRemixAudience _remixAudience = PuntokRemixAudience.everyone;

  /// Uploads by clip id, kept across saves so a retry or a second save never
  /// sends the same file twice.
  final _uploaded = <String, Media>{};

  /// Media a saved post now carries — the server owns those; anything else
  /// in [_uploaded] is ours to clean up.
  final _saved = <String>{};

  /// Set by the first save; every later one updates the same post.
  String? _postId;

  /// Replaying the first save with this key returns the post it made rather
  /// than a second one.
  final _createKey = uuidV4();

  /// What the running save is doing, for the overlay; null when idle.
  String? _busy;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _addVideos() async {
    if (_adding) return;
    setState(() => _adding = true);
    final skipped = <String>{};
    try {
      final files = await widget.pickVideos();
      final stills = ref.read(puntokClipStillsProvider);
      for (final file in files) {
        final extension = file.path.split('.').last.toLowerCase();
        if (!PuntokClipLimits.extensions.contains(extension)) {
          skipped.add('ไม่ใช่วิดีโอ');
          continue;
        }
        final size = await File(file.path).length();
        if (size > PuntokClipLimits.maxBytes) {
          skipped.add('ใหญ่เกิน 50 MB');
          continue;
        }
        final id = 'clip-${uuidV4()}';
        // Null when it will not decode here; the server still checks it.
        final length = await stills.load(id, file.path);
        if (length != null && length > PuntokClipLimits.maxLength) {
          stills.drop(id);
          skipped.add('ยาวเกิน 60 วินาที');
          continue;
        }
        if (!mounted) return;
        final clip = PuntokClip(
          id: id,
          path: file.path,
          duration: length,
          sizeBytes: size,
        );
        setState(() {
          _library.add(clip);
          // What was just picked is what they meant to use.
          if (_selected.length < PuntokClipLimits.maxClips) {
            _selected.add(clip);
          }
        });
      }
      if (skipped.isNotEmpty) _message('ข้ามบางไฟล์: ${skipped.join(', ')}');
    } catch (_) {
      _message(
          'เปิดคลังวิดีโอไม่ได้ ตรวจสอบสิทธิ์การเข้าถึงรูปภาพในการตั้งค่า');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _toggle(PuntokClip clip) {
    if (!_selected.contains(clip) &&
        _selected.length >= PuntokClipLimits.maxClips) {
      _message('เลือกได้สูงสุด ${PuntokClipLimits.maxClips} คลิป');
      return;
    }
    setState(() {
      if (!_selected.remove(clip)) _selected.add(clip);
      // A cover that is no longer in the cut falls back to the first clip.
      if (!_selected.contains(_cover)) _cover = null;
    });
  }

  void _back() {
    if (_busy != null) return;
    switch (_step) {
      case _Step.pick:
        _leave();
      case _Step.edit:
        setState(() => _step = _Step.pick);
      case _Step.compose:
        FocusScope.of(context).unfocus();
        setState(() => _step = _Step.edit);
    }
  }

  void _leave() {
    _discardUnsaved();
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.puntok.name);
    }
  }

  /// Unattached uploads count against a per-account cap of 200, so ones no
  /// post ended up using are deleted rather than left behind. Best effort —
  /// a failure here costs the traveller nothing they can see.
  void _discardUnsaved() {
    final orphans = [
      for (final media in _uploaded.values)
        if (!_saved.contains(media.mediaId)) media.mediaId,
    ];
    if (orphans.isEmpty) return;
    ref.read(plunoApiProvider.future).then((api) {
      for (final id in orphans) {
        api.media.deleteUnattached(id).catchError((_) {});
      }
    }).catchError((_) {});
  }

  Future<void> _pickActivity() async {
    final picked = await showPuntokActivitySheet(context, _activities);
    if (picked == null || !mounted) return;
    setState(() => _activities = picked);
  }

  Future<void> _pickPlace() async {
    final picked = await showPlacePinPicker(context, hasPlace: _place != null);
    if (picked == null || !mounted) return;
    setState(() => _place = picked == clearedPlacePin ? null : picked);
  }

  Future<void> _pickPlan() async {
    final picked = await showTripLinkPicker(context, current: _trip);
    if (picked == null || !mounted) return;
    setState(() => _trip = picked == noTripLink ? null : picked);
  }

  Future<void> _pickVisibility() async {
    final picked = await showPuntokVisibilitySheet(context, _visibility);
    if (picked == null || !mounted) return;
    setState(() => _visibility = picked);
  }

  Future<void> _pickCover() async {
    final picked = await showPuntokCoverSheet(
      context,
      clips: _selected,
      current: _cover ?? _selected.first,
    );
    if (picked == null || !mounted) return;
    setState(() => _cover = picked);
  }

  /// Save Draft and Puntok: upload what is not up yet, then save the post.
  Future<void> _save(PostSaveAction action) async {
    if (_busy != null || _selected.isEmpty) return;
    if (!ref.read(isSignedInProvider)) {
      _message('เข้าสู่ระบบก่อน จึงจะบันทึกหรือโพสต์ Puntok ได้');
      return;
    }
    FocusScope.of(context).unfocus();
    final clips = List.of(_selected);
    final cover = _cover ?? clips.first;

    try {
      final api = await ref.read(plunoApiProvider.future);
      for (var i = 0; i < clips.length; i++) {
        final clip = clips[i];
        if (_uploaded.containsKey(clip.id)) continue;
        setState(() => _busy = 'กำลังอัปโหลดวิดีโอ ${i + 1}/${clips.length}');
        _uploaded[clip.id] =
            await api.media.uploadUnattached(filePath: clip.path);
      }
      if (!mounted) return;
      setState(() => _busy = action == PostSaveAction.share
          ? 'กำลังโพสต์…'
          : 'กำลังบันทึกแบบร่าง…');

      final ids = [for (final clip in clips) _uploaded[clip.id]!.mediaId];
      final caption = _caption.text.trim();
      final place = _place;
      final firstSave = _postId == null;
      final result = await api.trips.savePost(
        postId: _postId,
        // `content` is what the server infers anyway, and it rejects `type`
        // values it does not know — so only a real Puntok type goes up.
        type: puntokTripType == TripType.content ? null : puntokTripType,
        action: action,
        visibility: _visibility.wire,
        title: _titleFrom(caption),
        destination: place == null
            ? _defaultDestination
            : (place.area?.trim().isNotEmpty ?? false)
                ? place.area!.trim()
                : place.name,
        description: caption.isEmpty ? null : caption,
        coverMediaId: Patch<String>.value(_uploaded[cover.id]!.mediaId),
        contents: [
          TripContentRequest(
            content: caption,
            mediaIds: ids,
            location: place == null
                ? const ContentLocation(status: ContentLocationStatus.none)
                : ContentLocation(
                    status: ContentLocationStatus.confirmed,
                    name: place.name,
                    placeId: place.placeId,
                    latitude: place.latitude,
                    longitude: place.longitude,
                  ),
          ),
        ],
        // Left out on the first save when there is nothing to link; cleared
        // on a later one, since the post may carry a link from before.
        linkedTripId: _trip != null
            ? Patch<String>.value(_trip!.id)
            : firstSave
                ? null
                : const Patch<String>.clear(),
        remixEnabled: _remixOn,
        remixAudience: _remixOn ? _remixAudience.wire : null,
        // Same rule: an empty list clears, which only matters once there is
        // a saved post to clear it on.
        travelStyles:
            _activities.styles.isEmpty && firstSave ? null : _activities.styles,
        customStyles:
            _activities.custom.isEmpty && firstSave ? null : _activities.custom,
        idempotencyKey: _createKey,
      );
      _postId = result.id;
      _saved.addAll(ids);
      if (!mounted) return;

      if (action == PostSaveAction.share) {
        _showInFeed(_uploaded[clips.first.id]!, _uploaded[cover.id]!, result);
      } else {
        _discardUnsaved();
        final messenger = ScaffoldMessenger.of(context);
        context.goNamed(AppRoute.myTrips.name);
        messenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
              content: Text('บันทึกแบบร่างแล้ว ดูต่อได้ที่ทริปฉัน')));
      }
    } on ApiException catch (error) {
      _message(_failure(error));
    } on FormatException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('บันทึกไม่สำเร็จ กรุณาลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// The caption's first line, cut to a title's length.
  static String _titleFrom(String caption) {
    final line = caption.split('\n').first.trim();
    if (line.isEmpty) return _defaultTitle;
    return line.length <= 100 ? line : '${line.substring(0, 99)}…';
  }

  static String _failure(ApiException error) {
    switch (error.statusCode) {
      case 400:
      case 413:
        return 'อัปโหลดวิดีโอไม่ได้: ต้องเป็น MP4 หรือ MOV ไม่เกิน 50 MB '
            'และยาวไม่เกิน 60 วินาที';
      case 401:
        return 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง';
      case 503:
        return 'ระบบวิดีโอยังไม่พร้อม ลองใหม่ภายหลัง';
    }
    return 'บันทึกไม่สำเร็จ ลองอีกครั้งได้: ${error.message}';
  }

  /// Opens For you with the shared clip on top, without waiting for the
  /// list to catch up with it.
  void _showInFeed(Media first, Media cover, ApiTrip post) {
    _discardUnsaved();
    final session = ref.read(authSessionProvider);

    ref.read(puntokFeedProvider.notifier).publish(
          PuntokPost(
            id: post.id,
            video: first.urls.original ?? '',
            poster: cover.stillUrl,
            // The name the feed's own rows carry (`creator.name`).
            author: session?.displayName ?? '',
            authorAvatar: session?.avatarImage,
            caption: _caption.text.trim(),
            likes: 0,
            linkedTrip: post.linkedTrip,
          ),
        );
    // It went in at the head of the corpus, which is For you's first page.
    ref.read(puntokFeedTabProvider.notifier).state = PuntokFeed.forYou;
    final messenger = ScaffoldMessenger.of(context);
    context.goNamed(AppRoute.puntok.name);
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('โพสต์ Puntok แล้ว')));
  }

  void _notYet(String label) => _message('$label — เร็วๆ นี้');

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(text),
        // Clear of the pinned bar, whose buttons it would otherwise cover.
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      ));
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the first-frame players alive for as long as the flow is open.
    ref.watch(puntokClipStillsProvider);
    final idle = _busy == null;

    final Widget body;
    switch (_step) {
      case _Step.pick:
        body = PuntokClipPicker(
          clips: _library,
          selected: _selected,
          onToggle: _toggle,
          onClear: () => setState(() {
            _selected.clear();
            _cover = null;
          }),
          onBack: _back,
          onNext: () => setState(() => _step = _Step.edit),
          onAddVideos: _addVideos,
          adding: _adding,
        );
      case _Step.edit:
        body = PuntokClipEditor(
          // A new cut is a new playback, not a resumed one.
          key: ValueKey(_selected.map((clip) => clip.id).join(',')),
          clips: List.unmodifiable(_selected),
          onBack: _back,
          onSaveDraft: idle ? () => _save(PostSaveAction.draft) : null,
          onNext: () => setState(() => _step = _Step.compose),
          onTool: _notYet,
        );
      case _Step.compose:
        body = PuntokComposer(
          caption: _caption,
          cover: _cover ?? _selected.first,
          activities: _activities,
          place: _place,
          trip: _trip,
          visibility: _visibility,
          remixOn: _remixOn,
          remixAudience: _remixAudience,
          onBack: _back,
          onEditCover: _pickCover,
          onActivity: _pickActivity,
          onTagFriend: () => _notYet('Tag Friend'),
          onLocation: _pickPlace,
          onSyncPlan: _pickPlan,
          onVisibility: _pickVisibility,
          onRemixChanged: (on) => setState(() => _remixOn = on),
          onRemixAudience: (audience) =>
              setState(() => _remixAudience = audience),
          onSaveDraft: idle ? () => _save(PostSaveAction.draft) : null,
          onPublish: idle ? () => _save(PostSaveAction.share) : null,
        );
    }

    return AppFrame(
      child: PopScope(
        // A back gesture past the first step goes back a step, not out; none
        // leaves while a save is running.
        canPop: _step == _Step.pick && idle,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            _discardUnsaved();
          } else {
            _back();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(child: body),
            if (!idle) Positioned.fill(child: _BusyOverlay(label: _busy!)),
          ],
        ),
      ),
    );
  }
}

/// Holds the screen still while clips go up — a 50 MB upload takes a while,
/// and a second tap would only start a second save.
class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
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
