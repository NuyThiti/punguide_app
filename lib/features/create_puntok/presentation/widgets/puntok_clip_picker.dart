import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/puntok_clip.dart';
import '../providers/puntok_clip_stills.dart';
import 'create_puntok_chrome.dart';

/// "เลือก วดอ" — the first step: a grid of clips, picked in order.
///
/// The grid holds what the traveller has brought in from the system picker
/// this session — its first tile opens that picker again — rather than the
/// whole camera roll, which would need a device-library plugin.
///
/// The order is the cut's order, which is why a picked tile shows its number
/// rather than a tick, and why the tray underneath reads left to right.
class PuntokClipPicker extends StatelessWidget {
  const PuntokClipPicker({
    super.key,
    required this.clips,
    required this.selected,
    required this.onToggle,
    required this.onClear,
    required this.onBack,
    required this.onNext,
    required this.onAddVideos,
    this.adding = false,
  });

  final List<PuntokClip> clips;
  final List<PuntokClip> selected;
  final ValueChanged<PuntokClip> onToggle;
  final VoidCallback onClear;
  final VoidCallback onBack;
  final VoidCallback onNext;

  /// The first tile, and "Videos ⌄": opens the system video picker.
  final VoidCallback onAddVideos;

  /// The system picker is open, or its picks are being read.
  final bool adding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.puntokCreateCanvas,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top),
          PuntokStepHeader(title: 'Puntok', onBack: onBack),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                InkWell(
                  onTap: adding ? null : onAddVideos,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Videos',
                          style: TextStyle(
                            color: AppColors.foreground,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down,
                            size: 20, color: AppColors.foreground),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Material(
                  color: AppColors.postCloseChip,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    onTap: selected.isEmpty ? null : onClear,
                    customBorder: const StadiumBorder(),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_box_outline_blank,
                              size: 16, color: AppColors.foreground),
                          SizedBox(width: 6),
                          Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.foreground,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
                childAspectRatio: 0.75,
              ),
              itemCount: clips.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _AddTile(
                    busy: adding,
                    onTap: adding ? null : onAddVideos,
                  );
                }
                final clip = clips[index - 1];
                final order = selected.indexOf(clip);
                return _ClipTile(
                  clip: clip,
                  order: order < 0 ? null : order + 1,
                  onTap: () => onToggle(clip),
                );
              },
            ),
          ),
          if (selected.isNotEmpty)
            _SelectionTray(
              selected: selected,
              onRemove: onToggle,
              onNext: onNext,
            ),
        ],
      ),
    );
  }
}

/// Leads the grid: brings more clips in from the system picker.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.postPurpleWell,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.postPurple,
                ),
              )
            else
              const Icon(Icons.video_library_outlined,
                  size: 30, color: AppColors.postPurple),
            const SizedBox(height: 8),
            const Text(
              'เพิ่มวิดีโอ',
              style: TextStyle(
                color: AppColors.postPurple,
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

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.clip,
    required this.order,
    required this.onTap,
  });

  final PuntokClip clip;

  /// 1-based place in the cut, or null when the clip is not picked.
  final int? order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final picked = order != null;
    return Semantics(
      button: true,
      selected: picked,
      label: clip.duration == null
          ? 'คลิป'
          : 'คลิป ${clipTimeLabel(clip.duration!)}',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PuntokClipStill(clip: clip),
            // Lifts the duration off bright footage.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x73000000)],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: picked
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.25),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: picked
                    ? Text(
                        '$order',
                        style: const TextStyle(
                          color: AppColors.foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
            ),
            if (clip.duration != null)
              Positioned(
                right: 8,
                bottom: 6,
                child: Text(
                  clipTimeLabel(clip.duration!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The picked clips in cut order, each removable, and the way on.
class _SelectionTray extends StatelessWidget {
  const _SelectionTray({
    required this.selected,
    required this.onRemove,
    required this.onNext,
  });

  final List<PuntokClip> selected;
  final ValueChanged<PuntokClip> onRemove;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: selected.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final clip = selected[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 42,
                            height: 50,
                            child: PuntokClipStill(clip: clip),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Semantics(
                            button: true,
                            label: 'เอาคลิปออก',
                            child: GestureDetector(
                              onTap: () => onRemove(clip),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: AppColors.foreground,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(Icons.close,
                                    size: 11, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sheetConfirm,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'ถัดไป',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
