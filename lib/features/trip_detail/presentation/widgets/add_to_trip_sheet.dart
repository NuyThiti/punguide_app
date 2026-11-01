import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../create_post/presentation/widgets/composer_sheet.dart';
import '../../../create_post/presentation/widgets/trip_link_picker.dart';

/// What the "เพิ่มลงทริป" sheet ended with.
sealed class AddToTripResult {
  const AddToTripResult();
}

/// The stop was copied onto [tripTitle].
class AddedToTrip extends AddToTripResult {
  const AddedToTrip(this.tripTitle);

  final String tripTitle;
}

/// "เพิ่มลงทริปใหม่" — the caller opens the plan wizard.
class AddToNewTrip extends AddToTripResult {
  const AddToNewTrip();
}

/// "เพิ่มลงทริป" — copies one stop of somebody's plan onto one of yours.
///
/// Returns null when dismissed. The stop lands at the end of the chosen
/// plan's **last** day: the API has no unscheduled shelf to drop it on, and the
/// end of the trip is where a reader adding "one more place" expects it. A plan
/// with no days yet gets its วันที่ 1 created first.
Future<AddToTripResult?> showAddToTripSheet(
  BuildContext context, {
  required Activity stop,
}) {
  return showModalBottomSheet<AddToTripResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => _AddToTripSheet(stop: stop),
  );
}

class _AddToTripSheet extends ConsumerStatefulWidget {
  const _AddToTripSheet({required this.stop});

  final Activity stop;

  @override
  ConsumerState<_AddToTripSheet> createState() => _AddToTripSheetState();
}

class _AddToTripSheetState extends ConsumerState<_AddToTripSheet> {
  String? _selected;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(myPlansProvider);
    final rows = trips.valueOrNull ?? const <TripListItem>[];

    return ComposerSheet(
      title: 'เพิ่มลงทริป',
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NewTripButton(
            onTap: _saving
                ? null
                : () => Navigator.of(context).pop(const AddToNewTrip()),
          ),
          const SizedBox(height: 14),
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
              error: (_, __) => const _SheetNote('อ่านทริปของคุณไม่สำเร็จ'),
              data: (rows) {
                if (rows.isEmpty) {
                  return const _SheetNote('ยังไม่มีทริป เพิ่มลงทริปใหม่ได้เลย');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => PlanPickerRow(
                    trip: rows[index],
                    selected: rows[index].id == _selected,
                    onTap: _saving
                        ? () {}
                        : () => setState(() {
                              _selected = rows[index].id;
                              _error = null;
                            }),
                  ),
                );
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.brandOrangeDeep,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    child: const Text(
                      'ย้อนกลับ',
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
                    // Greyed until a trip is picked, as the design draws it.
                    onPressed: _selected == null || _saving
                        ? null
                        : () => _add(rows),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sheetConfirm,
                      disabledBackgroundColor: AppColors.line,
                      disabledForegroundColor: AppColors.muted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
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

  Future<void> _add(List<TripListItem> rows) async {
    final target = rows.where((trip) => trip.id == _selected).firstOrNull;
    if (target == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final api = await ref.read(plunoApiProvider.future);
      final trip = await api.trips.byId(target.id);
      final days = [...trip.days]
        ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
      final dayId = days.isEmpty
          ? (await api.itinerary.addDay(target.id, dayNumber: 1)).id
          : days.last.id;

      final stop = widget.stop;
      final placeId = stop.location?.placeId?.trim();
      final linked = placeId != null && placeId.isNotEmpty;
      final notes = stop.notes?.trim();
      await api.itinerary.addItem(
        dayId,
        // A stop linked to a place is copied as that place, so the new plan
        // gets its photo and hours too; a hand-typed one keeps its name.
        placeId: linked ? placeId : null,
        customName: linked ? null : stop.title,
        category: stop.category,
        notes: notes == null || notes.isEmpty ? null : notes,
      );

      // The trip's own page and the lists that count its places are stale.
      ref.invalidate(myPlansProvider);
      if (!mounted) return;
      Navigator.of(context).pop(AddedToTrip(target.title));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'เพิ่มลงทริปไม่สำเร็จ ลองอีกครั้ง';
      });
    }
  }
}

/// "+ เพิ่มลงทริปใหม่" — the lavender bar above the list.
class _NewTripButton extends StatelessWidget {
  const _NewTripButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.postPurpleSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(
          width: double.infinity,
          height: 52,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.add, size: 22, color: AppColors.postPurple),
                SizedBox(width: 10),
                Text(
                  'เพิ่มลงทริปใหม่',
                  style: TextStyle(
                    color: AppColors.postPurple,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
