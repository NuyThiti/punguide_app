import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../puntok/presentation/widgets/puntok_video_layer.dart';
import '../../domain/puntok_clip.dart';
import 'create_puntok_chrome.dart';

/// "Edit ตัด cut / switch timeline" — the picked clips played back as one
/// cut, with the timeline underneath to jump between them.
///
/// Plays each clip once and moves on to the next, looping the whole cut. Under
/// `flutter test` there is no video plugin, so `initialize()` throws and the
/// clip's poster stands in, as it does in the feed.
class PuntokClipEditor extends StatefulWidget {
  const PuntokClipEditor({
    super.key,
    required this.clips,
    required this.onBack,
    required this.onSaveDraft,
    required this.onNext,
    required this.onTool,
  });

  final List<PuntokClip> clips;
  final VoidCallback onBack;
  final VoidCallback onSaveDraft;
  final VoidCallback onNext;

  /// Audio, Text or Sub — named by its label.
  final ValueChanged<String> onTool;

  @override
  State<PuntokClipEditor> createState() => _PuntokClipEditorState();
}

class _PuntokClipEditorState extends State<PuntokClipEditor> {
  int _current = 0;
  VideoPlayerController? _player;
  bool _disposed = false;

  Duration get _total => widget.clips
      .fold(Duration.zero, (sum, clip) => sum + clip.duration);

  /// Where the cut is: every clip before this one, plus this one's progress.
  Duration get _position {
    final before = widget.clips
        .take(_current)
        .fold(Duration.zero, (sum, clip) => sum + clip.duration);
    final player = _player;
    final within = player != null && player.value.isInitialized
        ? player.value.position
        : Duration.zero;
    return before + within;
  }

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  @override
  void didUpdateWidget(PuntokClipEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_current >= widget.clips.length) _load(0);
  }

  Future<void> _load(int index) async {
    final previous = _player;
    _player = null;
    previous?.removeListener(_onTick);
    await previous?.dispose();
    if (_disposed || widget.clips.isEmpty) return;

    setState(() => _current = index);
    final player = VideoPlayerController.asset(widget.clips[index].video);
    try {
      await player.initialize();
      await player.setVolume(0);
    } catch (_) {
      // No decodable clip keeps the poster rather than an error box.
      await player.dispose();
      return;
    }
    if (_disposed || _current != index) {
      await player.dispose();
      return;
    }
    player.addListener(_onTick);
    _player = player;
    await player.play();
    if (mounted) setState(() {});
  }

  void _onTick() {
    final player = _player;
    if (player == null || !mounted) return;
    final value = player.value;
    if (value.isInitialized &&
        !value.isPlaying &&
        value.position >= value.duration) {
      _load((_current + 1) % widget.clips.length);
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _disposed = true;
    _player?.removeListener(_onTick);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clips[_current];
    final top = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PuntokVideoLayer(poster: clip.poster, controller: _player),
                Positioned(
                  top: top + 10,
                  left: 16,
                  child: PuntokBackDisc(onTap: widget.onBack),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Row(
                    children: [
                      for (final (icon, label) in const [
                        (Icons.music_note_outlined, 'Audio'),
                        (Icons.title, 'Text'),
                        (Icons.closed_caption_outlined, 'Sub'),
                      ]) ...[
                        if (label != 'Audio') const SizedBox(width: 8),
                        Expanded(
                          child: _ToolPill(
                            icon: icon,
                            label: label,
                            onTap: () => widget.onTool(label),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              14 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.screen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(clipTimeLabel(_position), style: _timeStyle),
                    const Spacer(),
                    Text(clipTimeLabel(_total), style: _timeStyle),
                  ],
                ),
                const SizedBox(height: 8),
                _Timeline(
                  clips: widget.clips,
                  current: _current,
                  progress: _total == Duration.zero
                      ? 0
                      : _position.inMilliseconds / _total.inMilliseconds,
                  onPick: (index) {
                    if (index != _current) _load(index);
                  },
                ),
                const SizedBox(height: 16),
                PuntokActionBar(
                  decorated: false,
                  onSaveDraft: widget.onSaveDraft,
                  primaryLabel: 'ถัดไป',
                  onPrimary: widget.onNext,
                  primaryColor: AppColors.sheetConfirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _timeStyle = TextStyle(
    color: AppColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );
}

class _ToolPill extends StatelessWidget {
  const _ToolPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One strip of stills, each clip as wide as it is long, with the playhead
/// over wherever the cut has got to.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.clips,
    required this.current,
    required this.progress,
    required this.onPick,
  });

  final List<PuntokClip> clips;
  final int current;

  /// 0–1 across the whole cut.
  final double progress;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    for (var i = 0; i < clips.length; i++)
                      Expanded(
                        flex: clips[i].duration.inMilliseconds.clamp(1, 1 << 30),
                        child: GestureDetector(
                          onTap: () => onPick(i),
                          child: Container(
                            margin: EdgeInsets.only(
                                right: i == clips.length - 1 ? 0 : 2),
                            foregroundDecoration: i == current
                                ? null
                                : BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                            child: Image.asset(
                              clips[i].poster,
                              fit: BoxFit.cover,
                              height: 48,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: (constraints.maxWidth * progress.clamp(0.0, 1.0)) - 1.5,
                top: -4,
                bottom: -4,
                child: IgnorePointer(
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.puntokPlayhead,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
