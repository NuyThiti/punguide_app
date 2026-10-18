import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../create_post/domain/models/post_draft.dart';
import '../../create_post/presentation/widgets/place_pin_picker.dart';
import '../../create_post/presentation/widgets/trip_link_picker.dart';
import '../../puntok/domain/models/puntok_post.dart';
import '../../puntok/presentation/providers/puntok_providers.dart';
import '../domain/puntok_clip.dart';
import 'widgets/puntok_clip_editor.dart';
import 'widgets/puntok_clip_picker.dart';
import 'widgets/puntok_composer.dart';
import 'widgets/puntok_sheets.dart';

enum _Step { pick, edit, compose }

/// Create Puntok (Figma 2532-98219): pick clips → cut them → write it up.
///
/// One route with three faces rather than three routes, so backing out of a
/// step keeps everything chosen on it — the draft lives here, not in a
/// provider, and goes when the screen does.
///
/// Puntok has no endpoint. "Puntok" puts the clip at the head of the
/// session's mock feed and opens it there; location, plan, visibility and
/// remix are collected but have nowhere to go yet.
class CreatePuntokScreen extends ConsumerStatefulWidget {
  const CreatePuntokScreen({super.key, this.clips = puntokSampleClips});

  /// What the picker offers.
  final List<PuntokClip> clips;

  @override
  ConsumerState<CreatePuntokScreen> createState() => _CreatePuntokScreenState();
}

class _CreatePuntokScreenState extends ConsumerState<CreatePuntokScreen> {
  _Step _step = _Step.pick;

  final _selected = <PuntokClip>[];
  final _caption = TextEditingController();
  PuntokClip? _cover;
  PuntokActivities _activities = const PuntokActivities();
  PostPlace? _place;
  PostTripLink? _trip;
  PuntokVisibility _visibility = PuntokVisibility.public;
  bool _remixOn = false;
  PuntokRemixAudience _remixAudience = PuntokRemixAudience.everyone;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _toggle(PuntokClip clip) {
    setState(() {
      if (!_selected.remove(clip)) _selected.add(clip);
      // A cover that is no longer in the cut falls back to the first clip.
      if (!_selected.contains(_cover)) _cover = null;
    });
  }

  void _back() {
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
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.puntok.name);
    }
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

  void _publish() {
    final session = ref.read(authSessionProvider);
    final handle = session?.handle.replaceFirst('@', '').trim() ?? '';
    final cover = _cover ?? _selected.first;

    ref.read(puntokFeedProvider.notifier).publish(
          PuntokPost(
            id: 'puntok-mine-${DateTime.now().microsecondsSinceEpoch}',
            video: _selected.first.video,
            poster: cover.poster,
            author: handle.isEmpty ? 'you' : handle,
            authorAvatar: 'assets/images/puntok_avatar_1.jpg',
            caption: _caption.text.trim(),
            likes: 0,
            comments: 0,
            saves: 0,
            shares: 0,
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
    final Widget body;
    switch (_step) {
      case _Step.pick:
        body = PuntokClipPicker(
          clips: widget.clips,
          selected: _selected,
          onToggle: _toggle,
          onClear: () => setState(() {
            _selected.clear();
            _cover = null;
          }),
          onBack: _back,
          onNext: () => setState(() => _step = _Step.edit),
          onAlbum: () => _notYet('คลังวิดีโอในเครื่อง'),
        );
      case _Step.edit:
        body = PuntokClipEditor(
          // A new cut is a new playback, not a resumed one.
          key: ValueKey(_selected.map((clip) => clip.id).join(',')),
          clips: List.unmodifiable(_selected),
          onBack: _back,
          onSaveDraft: () => _notYet('บันทึกแบบร่าง'),
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
          onSaveDraft: () => _notYet('บันทึกแบบร่าง'),
          onPublish: _publish,
        );
    }

    return AppFrame(
      child: PopScope(
        // A back gesture past the first step goes back a step, not out.
        canPop: _step == _Step.pick,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: body,
      ),
    );
  }
}
