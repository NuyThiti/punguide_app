import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_frame.dart';
import '../domain/models/puntok_post.dart';
import 'widgets/puntok_player_pager.dart';

/// What a wall hands the viewer: the clips it was showing, and which one was
/// tapped. Passed as go_router `extra` — the viewer is opened from a wall, not
/// deep-linked, and the list is exactly the one the traveller was looking at.
@immutable
class PuntokViewerArgs {
  const PuntokViewerArgs({required this.posts, required this.initialIndex});

  final List<PuntokPost> posts;
  final int initialIndex;
}

/// A clip opened from a wall, full screen, with the rest of that wall still
/// swipeable underneath it.
///
/// The Puntok tab is the same player over the feed; this one carries no tab
/// bar and no bottom nav, because it is a place you came *to* rather than a
/// place you browse from.
class PuntokViewerScreen extends ConsumerStatefulWidget {
  const PuntokViewerScreen({super.key, this.args});

  final PuntokViewerArgs? args;

  @override
  ConsumerState<PuntokViewerScreen> createState() => _PuntokViewerScreenState();
}

class _PuntokViewerScreenState extends ConsumerState<PuntokViewerScreen> {
  late List<PuntokPost> _posts = widget.args?.posts ?? const <PuntokPost>[];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 12;

    return AppFrame(
      background: Colors.black,
      child: Stack(
        children: [
          if (_posts.isEmpty)
            const Center(
              child: Text(
                'ไม่พบคลิปนี้',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            )
          else
            PuntokPlayerPager(
              posts: _posts,
              initialIndex: (widget.args?.initialIndex ?? 0)
                  .clamp(0, _posts.length - 1),
              bottomInset: bottomInset,
              onLike: _toggleLike,
              onSave: _toggleSave,
              onFollow: () => _notYet('ติดตาม'),
              onOpenPlan: (planId) => context.pushNamed(
                AppRoute.tripDetail.name,
                params: {'tripId': planId},
              ),
              onComment: () => _notYet('คอมเมนต์'),
              onShare: () => _notYet('แชร์'),
              onCreator: () => _notYet('โปรไฟล์ครีเอเตอร์'),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ViewerTopBar(
              onBack: _goBack,
              onCreate: () => context.pushNamed(AppRoute.createPuntok.name),
            ),
          ),
        ],
      ),
    );
  }

  /// Flips the clip before the request so the tap feels instant, and flips it
  /// back if the server refuses. The wall behind is left alone: it re-reads
  /// its own rows when the traveller returns to it.
  Future<void> _toggleLike(PuntokPost post) async {
    final wasLiked = post.liked;
    _replace(post.copyWith(
      liked: !wasLiked,
      likes: post.likes + (wasLiked ? -1 : 1),
    ));

    await _call(() async {
      final api = await ref.read(plunoApiProvider.future);
      wasLiked ? await api.trips.unlike(post.id) : await api.trips.like(post.id);
    }, onFailure: () => _replace(post));
  }

  Future<void> _toggleSave(PuntokPost post) async {
    final wasSaved = post.saved;
    _replace(post.copyWith(saved: !wasSaved));

    await _call(() async {
      final api = await ref.read(plunoApiProvider.future);
      wasSaved ? await api.trips.unsave(post.id) : await api.trips.save(post.id);
    }, onFailure: () => _replace(post));
  }

  Future<void> _call(
    Future<void> Function() action, {
    required VoidCallback onFailure,
  }) async {
    try {
      await action();
    } on ApiException catch (error) {
      onFailure();
      _showMessage(error.statusCode == 401
          ? 'เข้าสู่ระบบก่อน จึงจะกดถูกใจหรือบันทึกได้'
          : 'ทำรายการไม่สำเร็จ ลองอีกครั้ง');
    } catch (_) {
      onFailure();
      _showMessage('ทำรายการไม่สำเร็จ ลองอีกครั้ง');
    }
  }

  void _replace(PuntokPost post) {
    if (!mounted) return;
    setState(() {
      _posts = [
        for (final existing in _posts)
          existing.id == post.id ? post : existing,
      ];
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.profile.name);
    }
  }

  void _notYet(String label) => _showMessage('$label — เร็วๆ นี้');

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ViewerTopBar extends StatelessWidget {
  const _ViewerTopBar({required this.onBack, required this.onCreate});

  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        6,
        MediaQuery.of(context).padding.top + 4,
        6,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlyphButton(
            icon: Icons.chevron_left,
            tooltip: 'ย้อนกลับ',
            onTap: onBack,
          ),
          _GlyphButton(
            icon: Icons.add,
            tooltip: 'สร้าง Puntok',
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

class _GlyphButton extends StatelessWidget {
  const _GlyphButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          // A shadow rather than a disc: the clip behind can be any colour,
          // and the reference leaves both glyphs bare on the video.
          child: Icon(
            icon,
            color: Colors.white,
            size: 30,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}
