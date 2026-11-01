import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/formatting/spot_detail_text.dart';
import '../../../../shared/layout/screen_class.dart';
import '../../../../shared/widgets/action_sheet.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../../shared/widgets/full_image_viewer.dart';
import '../../../trips/presentation/itinerary_display.dart';
import 'trip_content_sections.dart';

/// The blue the design gives a stop's way-there chip ("MRT", "Car").
const _legBlue = Color(0xFF2F6BE8);

/// What the ⋮ menu on a stop offers.
enum PlanStopAction { map, save, addToTrip }

/// One stop of a plan under ตารางแผน: photo and position, the time, the name
/// and how you get there, what the planner wrote, then — behind
/// "ดูรายละเอียด" — the place's hours, the way there and its phone and website.
///
/// The hours, phone and website are Google's, read through the stop's own
/// place. A stop typed by hand has none of them. The design's Trip Hack row
/// has no field on [Activity], so it is not drawn.
class PlanStopCard extends ConsumerStatefulWidget {
  const PlanStopCard({
    super.key,
    required this.stop,
    required this.position,
    required this.segment,
    required this.onAction,
  });

  final Activity stop;
  final int position;
  final TravelSegment? segment;
  final ValueChanged<PlanStopAction> onAction;

  @override
  ConsumerState<PlanStopCard> createState() => _PlanStopCardState();
}

class _PlanStopCardState extends ConsumerState<PlanStopCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    final screen = ScreenClass.of(context);
    final placeId = stop.location?.placeId?.trim();
    final live = placeId == null || placeId.isEmpty
        ? null
        : ref.watch(placeDetailsProvider(placeId)).valueOrNull;

    final hours = _hours(live);
    final way = _wayThere();
    final phone = live?.nationalPhoneNumber ?? live?.internationalPhoneNumber;
    final dial = live?.internationalPhoneNumber ?? live?.nationalPhoneNumber;
    final website = live?.websiteUri?.trim();
    final hasPhone = phone != null && phone.trim().isNotEmpty;
    final hasSite = website != null && website.isNotEmpty;
    final notes = stop.notes?.trim() ?? '';
    final hasDetails =
        hours != null || way.isNotEmpty || hasPhone || hasSite;

    return Container(
      padding: EdgeInsets.all(screen.pick(compact: 14.0, medium: 18.0)),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(stop: stop, position: widget.position),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: stop.time == null
                              ? const SizedBox.shrink()
                              : Text(
                                  clockLabel(stop.time!),
                                  style: const TextStyle(
                                    color: AppColors.brandOrange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                        _StopMenu(title: stop.title, onSelected: widget.onAction),
                      ],
                    ),
                    Text(
                      stop.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: screen.pick(
                          compact: 17.0,
                          medium: 19.0,
                          expanded: 20.0,
                        ),
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LegChip(stop: stop, segment: widget.segment),
                  ],
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              notes,
              style: const TextStyle(
                color: Color(0xFF5F6864),
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ],
          if (_open) ...[
            if (hours != null) ...[
              const SizedBox(height: 12),
              SpotInfoRow(icon: Icons.schedule, text: hours),
            ],
            if (way.isNotEmpty) ...[
              const SizedBox(height: 8),
              SpotInfoRow(
                icon: Icons.directions_transit_outlined,
                text: way,
              ),
            ],
            if (hasPhone || hasSite) ...[
              const SizedBox(height: 8),
              SpotLinkRow(
                phone: hasPhone ? phone.trim() : null,
                dial: dial,
                website: hasSite ? website : null,
              ),
            ],
          ],
          if (hasDetails) ...[
            const SizedBox(height: 12),
            SpotDetailsToggle(
              open: _open,
              onTap: () => setState(() => _open = !_open),
            ),
          ],
        ],
      ),
    );
  }

  /// "จ - อา : 06.00 - 14.30 น." from Google's week, or whether it is open
  /// right now when the week is not one Google spelled out.
  static String? _hours(PlaceDetails? live) {
    final week = live?.regularOpeningHours?.weekdayDescriptions ??
        live?.currentOpeningHours?.weekdayDescriptions ??
        const <String>[];
    final openNow =
        live?.currentOpeningHours?.openNow ?? live?.regularOpeningHours?.openNow;
    return weeklyHoursText(week) ??
        switch (openNow) {
          true => 'เปิดอยู่ตอนนี้',
          false => 'ปิดอยู่ตอนนี้',
          null => null,
        };
  }

  /// "MRT สนามเอก exit.3 · 8 นาที · 1.2 กม." — the planner's own note on the
  /// leg first, then the mode and what it takes. The first stop of a day has
  /// nothing to travel from.
  String _wayThere() {
    final stop = widget.stop;
    final note = stop.travelFromPrevious?.notes?.trim();
    final parts = <String>[
      if (note != null && note.isNotEmpty) note,
      ...legParts(stop, widget.segment, withDistance: true, withCost: true),
    ];
    return parts.join(' · ');
  }
}

/// The stop's photo, its position pinned top-left and an expand mark
/// bottom-right that opens it full size.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.stop, required this.position});

  final Activity stop;
  final int position;

  @override
  Widget build(BuildContext context) {
    final image = stop.location?.imageUrl;
    final hasImage = image != null && image.isNotEmpty;
    final scale =
        ScreenClass.of(context).pick(compact: 1.0, medium: 1.2, expanded: 1.32);

    return SizedBox(
      width: 112 * scale,
      height: 102 * scale,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned.fill(
              child: hasImage
                  ? CoverImage(source: image, fit: BoxFit.cover)
                  : ColoredBox(
                      color: AppColors.createBg,
                      child: Center(
                        child: Icon(
                          categoryIcon(stop.category),
                          size: 28,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 7,
              left: 7,
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                child: Text(
                  '$position',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (hasImage)
              Positioned(
                right: 2,
                bottom: 2,
                child: IconButton(
                  tooltip: 'ดูรูปเต็ม',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showFullImages(context, urls: [image]),
                  icon: const Icon(
                    Icons.open_in_full,
                    size: 17,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// How you reach the stop — "MRT", "Car" — or, for a day's first stop, what
/// kind of place it is.
class _LegChip extends StatelessWidget {
  const _LegChip({required this.stop, required this.segment});

  final Activity stop;
  final TravelSegment? segment;

  @override
  Widget build(BuildContext context) {
    final mode = legParts(stop, segment, withDistance: false, withCost: false);
    final hasLeg = mode.isNotEmpty &&
        (stop.travelFromPrevious != null || segment != null);
    final icon = hasLeg ? legIcon(stop, segment) : categoryIcon(stop.category);
    // The chip names the mode only; minutes and distance are in the details.
    final label = hasLeg ? mode.first : categoryLabel(stop.category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.createBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _legBlue),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _legBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ⋮ — นำทางบน Map, บันทึก, เพิ่มลงทริป, on a bottom sheet headed by the
/// stop's name so it is clear which of the day's stops it acts on.
class _StopMenu extends StatelessWidget {
  const _StopMenu({required this.title, required this.onSelected});

  final String title;
  final ValueChanged<PlanStopAction> onSelected;

  Future<void> _open(BuildContext context) async {
    final action = await showActionSheet<PlanStopAction>(
      context,
      title: title,
      items: const [
        ActionSheetItem(
          value: PlanStopAction.map,
          icon: Icons.near_me_outlined,
          label: 'นำทางบน Map',
        ),
        ActionSheetItem(
          value: PlanStopAction.save,
          icon: Icons.bookmark_border,
          label: 'บันทึก',
        ),
        ActionSheetItem(
          value: PlanStopAction.addToTrip,
          icon: Icons.add,
          label: 'เพิ่มลงทริป',
        ),
      ],
    );
    if (action != null) onSelected(action);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        tooltip: 'ตัวเลือก',
        padding: EdgeInsets.zero,
        iconSize: 20,
        onPressed: () => _open(context),
        icon: const Icon(Icons.more_vert, color: AppColors.muted),
      ),
    );
  }
}
