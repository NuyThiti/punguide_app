import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../domain/models/post_draft.dart';
import 'composer_sheet.dart';

/// The traveller's own plans, for the link step.
///
/// `GET /trips/mine` rather than the cached local list: the design shows each
/// plan's dates and length, and only the API rows carry a schedule.
final myPlansProvider = FutureProvider<List<TripListItem>>((ref) async {
  final api = await ref.watch(plunoApiProvider.future);
  return api.trips.mine();
});

/// "เชื่อมกับแผนของฉัน" — the last step before a post goes out: which of the
/// traveller's own plans readers can open from it.
///
/// Returns null when dismissed (ยกเลิก, the ✕ or the scrim) and a
/// [PostTripLink] on ตกลง — [noTripLink] when they confirmed without picking
/// one, which is a deliberate "post it with no plan".
Future<PostTripLink?> showTripLinkPicker(
  BuildContext context, {
  String? selectedId,
}) {
  return showModalBottomSheet<PostTripLink>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => _TripLinkPicker(selectedId: selectedId),
  );
}

/// What [showTripLinkPicker] returns for "ตกลง" with nothing chosen.
const noTripLink = PostTripLink(id: '', title: '');

class _TripLinkPicker extends ConsumerStatefulWidget {
  const _TripLinkPicker({this.selectedId});

  final String? selectedId;

  @override
  ConsumerState<_TripLinkPicker> createState() => _TripLinkPickerState();
}

class _TripLinkPickerState extends ConsumerState<_TripLinkPicker> {
  late String? _selected = widget.selectedId;

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(myPlansProvider);

    return ComposerSheet(
      title: 'เชื่อมกับแผนของฉัน',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: trips.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, __) => const _SheetNote('อ่านแผนของคุณไม่สำเร็จ'),
              data: (rows) {
                if (rows.isEmpty) {
                  return const _SheetNote(
                      'ยังไม่มีแผนให้เชื่อม สร้างแพลนก่อนได้เลย');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _PlanRow(
                    trip: rows[index],
                    selected: rows[index].id == _selected,
                    // Tapping the row that is already chosen clears it, which
                    // is the only way back to "no plan" once one is picked.
                    onTap: () => setState(() => _selected =
                        rows[index].id == _selected ? null : rows[index].id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _resolve(trips.valueOrNull ?? const <TripListItem>[]),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sheetConfirm,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    child: const Text(
                      'ตกลง',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PostTripLink _resolve(List<TripListItem> rows) {
    for (final trip in rows) {
      if (trip.id == _selected) {
        return PostTripLink(id: trip.id, title: trip.title);
      }
    }
    return noTripLink;
  }
}

/// One plan: its cover, who is on it, its name, and how long it runs.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.trip,
    required this.selected,
    required this.onTap,
  });

  final TripListItem trip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.screen,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.postPurple : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 84,
                child: CoverImage(
                  source: trip.coverImage?.urls.large ?? '',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The design stacks every traveller on the plan here.
                      // The list endpoint carries only its creator, so one
                      // avatar is all there is to draw.
                      _CreatorAvatar(creator: trip.creator),
                      const SizedBox(height: 6),
                      Text(
                        trip.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _summary(trip),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 14),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.postPurple : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? AppColors.postPurple
                          : AppColors.postDashed,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "28-30 Dec 2026 • 7 วัน", dropping whichever half the plan has not got.
  ///
  /// The design also counts the plan's stops, which the trip list does not
  /// carry — that number would cost one request per row.
  static String _summary(TripListItem trip) {
    final parts = <String>[];
    final range = _dateRange(trip.schedule);
    if (range.isNotEmpty) parts.add(range);
    final days = trip.schedule.durationDays;
    if (days != null && days > 0) parts.add('$days วัน');
    if (parts.isEmpty) return trip.destination;
    return parts.join(' • ');
  }

  static String _dateRange(Schedule schedule) {
    final start = schedule.startDate;
    if (start == null) return '';
    final end = schedule.endDate;
    if (end == null || _sameDay(start, end)) return _day(start);
    if (start.year == end.year && start.month == end.month) {
      return '${start.day}-${_day(end)}';
    }
    return '${_day(start)} - ${_day(end)}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _day(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

class _CreatorAvatar extends StatelessWidget {
  const _CreatorAvatar({required this.creator});

  final TripCreator? creator;

  @override
  Widget build(BuildContext context) {
    final url = creator?.avatarUrl;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.postIconWell,
        border: Border.all(color: AppColors.screen, width: 1.5),
        image: url == null || url.isEmpty
            ? null
            : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      child: url == null || url.isEmpty
          ? const Icon(Icons.person, size: 13, color: AppColors.muted)
          : null,
    );
  }
}

class _SheetNote extends StatelessWidget {
  const _SheetNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    );
  }
}
