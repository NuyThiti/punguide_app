import 'package:flutter/material.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';

/// The cards a turn's blocks become.
///
/// Figma 2281-46309 draws the empty state only — frames past it are still
/// blank — so nothing here is traced from a design. These follow the app's
/// existing card language (ไปกัน and Home) and show exactly the fields the
/// API sends, with "unknown" drawn as absence rather than as a zero.

/// Shared shell: white, rounded, softly lifted off the page.
class _ChatCard extends StatelessWidget {
  const _ChatCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Trips other travellers published. Badged, because the difference between
/// this and a draft the assistant just wrote is the most important thing on
/// the page.
class AiChatTripResults extends StatelessWidget {
  const AiChatTripResults({
    super.key,
    required this.block,
    required this.onOpenTrip,
  });

  final TripResultsBlock block;
  final ValueChanged<String> onOpenTrip;

  @override
  Widget build(BuildContext context) {
    if (block.trips.isEmpty) return const SizedBox.shrink();

    return _BlockFrame(
      label: 'ทริปที่คนอื่นแชร์ไว้',
      trailing: _countLabel(block.trips.length, block.totalMatches),
      child: SizedBox(
        height: 214,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemCount: block.trips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final trip = block.trips[index];
            return SizedBox(
              width: 210,
              child: _ChatCard(
                onTap: () => onOpenTrip(trip.tripId),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 108,
                      width: double.infinity,
                      child: trip.imageUrl == null
                          ? const ColoredBox(color: AppColors.optionIconBg)
                          : CoverImage(
                              source: trip.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _FactLine(facts: _tripFacts(trip)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Only the facts the API actually sent. A missing count is left out, not
  /// printed as "0 สถานที่".
  static List<String> _tripFacts(ChatTripResult trip) => <String>[
        if (trip.destination != null) trip.destination!,
        if (trip.durationDays != null) '${trip.durationDays} วัน',
        if (trip.placeCount != null) '${trip.placeCount} ที่',
      ];
}

/// Places, with the two honesty notes the API insists on: a straight-line
/// distance, and hours that describe a normal week rather than right now.
class AiChatPlaceResults extends StatelessWidget {
  const AiChatPlaceResults({
    super.key,
    required this.block,
    required this.onOpenPlace,
  });

  final PlaceResultsBlock block;
  final ValueChanged<String> onOpenPlace;

  @override
  Widget build(BuildContext context) {
    if (block.places.isEmpty) return const SizedBox.shrink();

    return _BlockFrame(
      label: block.nearLabel == null ? 'สถานที่' : 'ใกล้ ${block.nearLabel}',
      trailing: _countLabel(block.places.length, block.totalMatches),
      child: Column(
        children: [
          for (final place in block.places)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChatCard(
                onTap: () => onOpenPlace(place.placeId),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: place.imageUrl == null
                              ? const ColoredBox(color: AppColors.optionIconBg)
                              : CoverImage(
                                  source: place.imageUrl!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _FactLine(facts: _placeFacts(place)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// `rating: null` means Google's ratings field is off, not zero stars — so
  /// the star only appears when there is a number behind it. The distance says
  /// "ตรง" because it is straight-line, not a driving estimate.
  static List<String> _placeFacts(ChatPlaceResult place) => <String>[
        if (place.rating != null) '★ ${place.rating!.toStringAsFixed(1)}',
        if (place.distanceKm != null)
          'ห่าง ${place.distanceKm!.toStringAsFixed(1)} กม. (ตรง)',
        if (place.category != null) place.category!,
      ];
}

/// A plan the assistant wrote. Not a trip until it is saved, and the card says
/// so in three places: the badge, the unverified notice, and the button.
class AiChatItineraryPreview extends StatelessWidget {
  const AiChatItineraryPreview({
    super.key,
    required this.block,
    required this.onSave,
    this.saving = false,
    this.savedTripId,
  });

  final ItineraryPreviewBlock block;
  final VoidCallback onSave;
  final bool saving;

  /// Set once this revision has been written to the planner.
  final String? savedTripId;

  @override
  Widget build(BuildContext context) {
    return _BlockFrame(
      label: 'ร่างแผนจากผู้ช่วย',
      trailing: 'ยังไม่ได้บันทึก',
      child: _ChatCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                block.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 6),
              _FactLine(facts: _planFacts(block)),
              if (block.feasibilityUnverified) ...[
                const SizedBox(height: 10),
                const _Notice(
                  icon: Icons.schedule,
                  text: 'เวลาเดินทางและเวลาเปิด-ปิดยังไม่ได้ตรวจครบทุกช่วง',
                ),
              ],
              for (final assumption in block.assumptions) ...[
                const SizedBox(height: 6),
                _Notice(icon: Icons.tune, text: assumption),
              ],
              const SizedBox(height: 12),
              for (final day in block.days) _DayRow(day: day),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving || savedTripId != null ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sheetConfirm,
                    disabledBackgroundColor: AppColors.postActionIdle,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    savedTripId != null
                        ? 'บันทึกแล้ว'
                        : saving
                            ? 'กำลังบันทึก…'
                            : 'บันทึกลง Trip Planner',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The cost is always an estimate and usually per person, so it is labelled
  /// both ways rather than printed as a price.
  static List<String> _planFacts(ItineraryPreviewBlock block) => <String>[
        if (block.destination != null) block.destination!,
        if (block.durationDays != null) '${block.durationDays} วัน',
        if (block.estimatedCost != null)
          'ประมาณ ${block.estimatedCost!.round()} ${block.currency ?? ''}'
              '${block.isPerPerson ? '/คน' : ''}'.trim(),
      ];
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});

  final ChatItineraryDay day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'วันที่ ${day.dayNumber}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          for (final stop in day.stops)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      stop.startTime ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.aiGreeting,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      stop.name,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A question the assistant needs answered before it can go on. Options become
/// taps; an open question leaves the composer to do the work.
class AiChatClarification extends StatelessWidget {
  const AiChatClarification({
    super.key,
    required this.block,
    required this.onAnswer,
  });

  final ClarificationBlock block;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    if (block.options.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in block.options)
            GestureDetector(
              onTap: () => onAnswer(option),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.chipBorder),
                ),
                child: Text(
                  option,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Section label above a group of cards, indented to the bubbles' column.
class _BlockFrame extends StatelessWidget {
  const _BlockFrame({
    required this.label,
    required this.child,
    this.trailing,
  });

  final String label;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Both halves flex: a long label and a long note together overrun
          // the bubbles' column at phone width.
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.aiGreeting,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    trailing!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.aiGreeting,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.facts});

  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();
    return Text(
      facts.join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12,
        height: 1.3,
        color: AppColors.aiGreeting,
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 13, color: AppColors.aiGreeting),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.aiGreeting,
            ),
          ),
        ),
      ],
    );
  }
}

/// "3 จาก 9" when the server matched more than it sent, otherwise nothing —
/// a total equal to the shown count adds no information.
String? _countLabel(int shown, int? total) =>
    total != null && total > shown ? '$shown จาก $total' : null;
