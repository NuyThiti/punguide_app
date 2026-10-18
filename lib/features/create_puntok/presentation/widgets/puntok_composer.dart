import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../create_post/domain/models/post_draft.dart';
import '../../../create_post/presentation/widgets/trip_link_picker.dart';
import '../../../create_trip/domain/plan_labels.dart';
import '../../domain/puntok_clip.dart';
import 'create_puntok_chrome.dart';
import 'puntok_sheets.dart';

/// "New Puntok" — the last step: caption, cover, and everything the clip
/// carries with it. Holds no state of its own; the screen owns the draft.
class PuntokComposer extends StatelessWidget {
  const PuntokComposer({
    super.key,
    required this.caption,
    required this.cover,
    required this.activities,
    required this.place,
    required this.trip,
    required this.visibility,
    required this.remixOn,
    required this.remixAudience,
    required this.onBack,
    required this.onEditCover,
    required this.onActivity,
    required this.onTagFriend,
    required this.onLocation,
    required this.onSyncPlan,
    required this.onVisibility,
    required this.onRemixChanged,
    required this.onRemixAudience,
    required this.onSaveDraft,
    required this.onPublish,
  });

  final TextEditingController caption;
  final PuntokClip cover;
  final PuntokActivities activities;
  final PostPlace? place;
  final PostTripLink? trip;
  final PuntokVisibility visibility;
  final bool remixOn;
  final PuntokRemixAudience remixAudience;

  final VoidCallback onBack;
  final VoidCallback onEditCover;
  final VoidCallback onActivity;
  final VoidCallback onTagFriend;
  final VoidCallback onLocation;
  final VoidCallback onSyncPlan;
  final VoidCallback onVisibility;
  final ValueChanged<bool> onRemixChanged;
  final ValueChanged<PuntokRemixAudience> onRemixAudience;
  final VoidCallback onSaveDraft;

  /// Null while publishing.
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.screen,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top),
          PuntokStepHeader(title: 'New Puntok', onBack: onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: caption,
                            minLines: 3,
                            maxLines: 8,
                            maxLength: 2200,
                            style: const TextStyle(
                              color: AppColors.foreground,
                              fontSize: 15,
                              height: 1.45,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Add a caption...',
                              hintStyle: TextStyle(
                                color: AppColors.aiHint,
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                              counterText: '',
                            ),
                          ),
                          if (!activities.isEmpty) ...[
                            const SizedBox(height: 10),
                            _ChosenActivities(activities: activities),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CoverPreview(clip: cover, onEdit: onEditCover),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    DashedPill(
                      icon: Icons.tag,
                      label: 'Activity',
                      onTap: onActivity,
                    ),
                    const SizedBox(width: 12),
                    DashedPill(
                      icon: Icons.account_box_outlined,
                      label: 'Tag Friend',
                      onTap: onTagFriend,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.line),
                _FieldRow(
                  icon: Icons.location_on_outlined,
                  onTap: onLocation,
                  child: place == null
                      ? const _Placeholder('Add Location')
                      : _TwoLine(
                          title: place!.name,
                          subtitle: place!.address ?? place!.area,
                        ),
                ),
                const Divider(height: 1, color: AppColors.line),
                _FieldRow(
                  icon: Icons.sync_alt,
                  onTap: onSyncPlan,
                  child: const _Placeholder('Sync แผนทริปของฉัน'),
                ),
                if (trip != null) ...[
                  _LinkedPlanCard(trip: trip!, onTap: onSyncPlan),
                  const SizedBox(height: 12),
                ],
                const Divider(height: 1, color: AppColors.line),
                _FieldRow(
                  icon: Icons.visibility_outlined,
                  onTap: onVisibility,
                  trailing: _VisibilityPill(
                    visibility: visibility,
                    onTap: onVisibility,
                  ),
                  child: const _Placeholder('การมองเห็นโพส'),
                ),
                const SizedBox(height: 8),
                _RemixCard(
                  on: remixOn,
                  audience: remixAudience,
                  onChanged: onRemixChanged,
                  onAudience: onRemixAudience,
                ),
              ],
            ),
          ),
          PuntokActionBar(
            onSaveDraft: onSaveDraft,
            primaryLabel: 'Puntok',
            onPrimary: onPublish,
            primaryColor: AppColors.puntokPublish,
          ),
        ],
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.clip, required this.onEdit});

  final PuntokClip clip;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 116,
        height: 206,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(clip.poster, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0x59000000), Colors.transparent],
                ),
              ),
            ),
            const Positioned(
              top: 10,
              left: 12,
              child: Text(
                'Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 10,
              child: Center(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.72),
                  shape: const StadiumBorder(),
                  child: InkWell(
                    onTap: onEdit,
                    customBorder: const StadiumBorder(),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Text(
                        'Edit cover',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The activities read back under the caption, as small purple tags.
class _ChosenActivities extends StatelessWidget {
  const _ChosenActivities({required this.activities});

  final PuntokActivities activities;

  @override
  Widget build(BuildContext context) {
    final tags = [
      for (final style in activities.styles)
        (styleLabel(style) ?? style.name, styleIcon(style)),
      for (final label in activities.custom)
        (label, Icons.local_activity_outlined),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final (label, icon) in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.postPurpleWell,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: AppColors.postPurple),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.postPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.child,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Widget child;
  final VoidCallback onTap;

  /// Replaces the chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.postPurpleWell,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: AppColors.postPurple),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
            const SizedBox(width: 8),
            trailing ??
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AppColors.muted, fontSize: 14),
    );
  }
}

class _TwoLine extends StatelessWidget {
  const _TwoLine({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

/// The plan the clip links to, under "Sync แผนทริปของฉัน". The picker only
/// hands back an id and a title, so the cover and length come from the same
/// `GET /trips/mine` list the picker read — absent while that is loading.
class _LinkedPlanCard extends ConsumerWidget {
  const _LinkedPlanCard({required this.trip, required this.onTap});

  final PostTripLink trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TripListItem? row;
    for (final item in ref.watch(myPlansProvider).valueOrNull ?? const []) {
      if (item.id == trip.id) row = item;
    }
    final summary = [
      if ((row?.schedule.durationDays ?? 0) > 0)
        '${row!.schedule.durationDays} วัน',
      if ((row?.placeCount ?? 0) > 0) '${row!.placeCount} สถานที่',
    ].join(' • ');

    return Material(
      color: AppColors.postPurpleWell,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.postPurpleSoft),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 60,
                child: CoverImage(
                  source: row?.coverImage?.urls.large ?? '',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.postPurple,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.chevron_right,
                    size: 20, color: AppColors.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilityPill extends StatelessWidget {
  const _VisibilityPill({required this.visibility, required this.onTap});

  final PuntokVisibility visibility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.postDraftBg,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(visibility.icon, size: 13, color: AppColors.foreground),
              const SizedBox(width: 4),
              Text(
                visibility.label,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down,
                  size: 16, color: AppColors.foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/// "เปิดให้ remix" — off by default; on, it asks who may remix.
class _RemixCard extends StatelessWidget {
  const _RemixCard({
    required this.on,
    required this.audience,
    required this.onChanged,
    required this.onAudience,
  });

  final bool on;
  final PuntokRemixAudience audience;
  final ValueChanged<bool> onChanged;
  final ValueChanged<PuntokRemixAudience> onAudience;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.postPurpleWell,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shuffle,
                    size: 18, color: AppColors.postPurple),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เปิดให้ remix',
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'เปิดการรีมิกซ์แผนทริปนี้',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: on,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.postPurple,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: AppColors.postCloseChip,
                trackOutlineColor:
                    const WidgetStatePropertyAll(Colors.transparent),
              ),
            ],
          ),
          if (on) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.puntokRemixPanel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (final option in PuntokRemixAudience.values)
                    _RemixOption(
                      option: option,
                      selected: option == audience,
                      onTap: () => onAudience(option),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RemixOption extends StatelessWidget {
  const _RemixOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PuntokRemixAudience option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? AppColors.postPurple : AppColors.muted,
              ),
              const SizedBox(width: 10),
              Icon(option.icon, size: 18, color: AppColors.foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      option.hint,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
