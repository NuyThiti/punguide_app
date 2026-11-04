import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../create_post/presentation/widgets/trip_link_picker.dart';
import '../../../trips/presentation/itinerary_display.dart';
import '../../../trips/presentation/providers/trip_providers.dart';

/// What a finished Remix copied, and where to.
class RemixedStops {
  const RemixedStops({
    required this.tripId,
    required this.tripTitle,
    required this.added,
    required this.skipped,
    required this.replayed,
  });

  final String tripId;
  final String tripTitle;

  /// Stops newly put on the target's shelf.
  final int added;

  /// Picked stops left out because the place was already on the shelf.
  final int skipped;

  /// A retry the server had already done: nothing new was copied.
  final bool replayed;
}

/// Remix, in two steps on one sheet: "เลือกสถานที่จะ Remix" — which of
/// [stops] to take — then "Remix ไปลงทริปไหน?" — which of your own plans gets
/// them. Returns null when dismissed.
///
/// ตกลง calls `POST /trips/:sourceTripId/remix/items/into/:targetTripId`
/// ([TripsApi.remixItemsInto]): the picks land on the target's staging shelf
/// ("From Remix Trip"), not on a day, and the source's remix count goes up.
/// [sourceTripId] may be a post — [stops] are then its linked plan's.
Future<RemixedStops?> showRemixSheet(
  BuildContext context, {
  required String sourceTripId,
  required List<Activity> stops,
}) {
  return showModalBottomSheet<RemixedStops>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => _RemixSheet(sourceTripId: sourceTripId, stops: stops),
  );
}

class _RemixSheet extends ConsumerStatefulWidget {
  const _RemixSheet({required this.sourceTripId, required this.stops});

  final String sourceTripId;
  final List<Activity> stops;

  @override
  ConsumerState<_RemixSheet> createState() => _RemixSheetState();
}

class _RemixSheetState extends ConsumerState<_RemixSheet> {
  /// Indexes into [_RemixSheet.stops] — two stops can share an id-less row.
  final _picked = <int>{};
  bool _choosingTrip = false;
  String? _target;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.screen,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          18 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D6D1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            _Header(
              title:
                  _choosingTrip ? 'Remix ไปลงทริปไหน?' : 'เลือกสถานที่จะ Remix',
              onBack: _choosingTrip && !_saving ? _backToStops : null,
              onClose: _saving ? null : () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: _choosingTrip ? _tripStep() : _stopStep(),
            ),
          ],
        ),
      ),
    );
  }

  void _backToStops() => setState(() {
        _choosingTrip = false;
        _error = null;
      });

  // ── Step 1: which stops ────────────────────────────────────────────────

  Widget _stopStep() {
    final stops = widget.stops;
    final all = stops.isNotEmpty && _picked.length == stops.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SelectAllRow(
          checked: all,
          onTap: () => setState(() {
            if (all) {
              _picked.clear();
            } else {
              _picked.addAll(List.generate(stops.length, (i) => i));
            }
          }),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: stops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _StopPickRow(
              stop: stops[index],
              checked: _picked.contains(index),
              onTap: () => setState(() {
                if (!_picked.remove(index)) _picked.add(index);
              }),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${_picked.length} / ',
                    style: TextStyle(
                      color: _picked.isEmpty
                          ? AppColors.muted
                          : AppColors.postPurple,
                    ),
                  ),
                  TextSpan(
                    text: '${stops.length}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  TextSpan(
                    text: ' รายการ',
                    style: TextStyle(
                      color: _picked.isEmpty
                          ? AppColors.muted
                          : AppColors.postPurple,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(_picked.clear),
              behavior: HitTestBehavior.opaque,
              child: const Text(
                'ล้างที่เลือก',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.line),
        const SizedBox(height: 14),
        _Buttons(
          secondary: 'ยกเลิก',
          onSecondary: () => Navigator.of(context).pop(),
          primary: 'ถัดไป',
          primaryColor: AppColors.foreground,
          onPrimary: _picked.isEmpty
              ? null
              : () => setState(() => _choosingTrip = true),
        ),
      ],
    );
  }

  // ── Step 2: which trip ─────────────────────────────────────────────────

  Widget _tripStep() {
    final trips = ref.watch(myPlansProvider);
    // Remixing a plan into itself would only duplicate its own stops.
    final rows = (trips.valueOrNull ?? const <TripListItem>[])
        .where((trip) => trip.id != widget.sourceTripId)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: trips.isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : trips.hasError
                  ? const _Note('อ่านทริปของคุณไม่สำเร็จ')
                  : rows.isEmpty
                      ? const _Note('ยังไม่มีทริปของคุณให้ Remix ลง')
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => PlanPickerRow(
                            trip: rows[index],
                            selected: rows[index].id == _target,
                            onTap: _saving
                                ? () {}
                                : () => setState(() {
                                      _target = rows[index].id;
                                      _error = null;
                                    }),
                          ),
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
        const SizedBox(height: 18),
        _Buttons(
          secondary: 'ย้อนกลับ',
          onSecondary: _saving ? null : _backToStops,
          primary: 'ตกลง',
          primaryColor: AppColors.sheetConfirm,
          busy: _saving,
          onPrimary: _target == null || _saving ? null : () => _remix(rows),
        ),
      ],
    );
  }

  /// One key per distinct ตกลง: a retry after a failure, with the same
  /// trip and the same picks, reuses it so the server replays rather than
  /// copying twice; changing either mints a new one. The server only
  /// remembers which trip a key went to, not what was picked, so a changed
  /// selection under an old key would replay the first attempt.
  String? _key;
  String? _keyFor;

  String _idempotencyKey(String targetId, List<String> itemIds) {
    final signature = '$targetId|${itemIds.join(',')}';
    if (_key == null || _keyFor != signature) {
      _key = uuidV4();
      _keyFor = signature;
    }
    return _key!;
  }

  Future<void> _remix(List<TripListItem> rows) async {
    final target = rows.where((trip) => trip.id == _target).firstOrNull;
    if (target == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    // The server lands them in the plan's own order whatever is sent; sent in
    // that order anyway so the key's signature does not depend on tick order.
    final itemIds = <String>{
      for (var i = 0; i < widget.stops.length; i++)
        if (_picked.contains(i)) widget.stops[i].id,
    }.toList();

    try {
      final api = await ref.read(plunoApiProvider.future);
      final result = await api.trips.remixItemsInto(
        widget.sourceTripId,
        target.id,
        itemIds: itemIds,
        idempotencyKey: _idempotencyKey(target.id, itemIds),
      );
      // The target's shelf, the source's remix count and the lists that
      // count places have all moved.
      ref
        ..invalidate(myPlansProvider)
        ..invalidate(apiTripProvider(target.id))
        ..invalidate(apiTripProvider(widget.sourceTripId));
      if (!mounted) return;
      Navigator.of(context).pop(
        RemixedStops(
          tripId: target.id,
          tripTitle: target.title,
          added: result.addedItemIds.length,
          skipped: result.skippedItemIds.length,
          replayed: result.replayed,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (error.statusCode) {
          // The server's own reason: remix switched off, followers only…
          403 => error.message,
          401 => 'เข้าสู่ระบบก่อน จึงจะ Remix ได้',
          404 => 'ไม่พบทริปนี้แล้ว',
          _ => 'Remix ไม่สำเร็จ ลองอีกครั้ง',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Remix ไม่สำเร็จ ลองอีกครั้ง';
      });
    }
  }

}

/// The title between an optional back chip and the ✕.
class _Header extends StatelessWidget {
  const _Header({required this.title, this.onBack, this.onClose});

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: onBack == null
              ? null
              : _RoundChip(
                  icon: Icons.chevron_left,
                  tooltip: 'ย้อนกลับ',
                  onTap: onBack!,
                ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: _RoundChip(
            icon: Icons.close,
            tooltip: 'ปิด',
            onTap: onClose ?? () {},
          ),
        ),
      ],
    );
  }
}

class _RoundChip extends StatelessWidget {
  const _RoundChip({
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
      child: Material(
        color: AppColors.postCloseChip,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: AppColors.foreground),
          ),
        ),
      ),
    );
  }
}

/// "เลือก Remix ทั้งหมด" — the cream bar that ticks or clears every stop.
class _SelectAllRow extends StatelessWidget {
  const _SelectAllRow({required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.createBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'เลือก Remix ทั้งหมด',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _CheckBox(checked: checked),
            ],
          ),
        ),
      ),
    );
  }
}

/// One stop: its photo, its category, its name and — when Google has one —
/// its address.
class _StopPickRow extends ConsumerWidget {
  const _StopPickRow({
    required this.stop,
    required this.checked,
    required this.onTap,
  });

  final Activity stop;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeId = stop.location?.placeId?.trim();
    final address = placeId == null || placeId.isEmpty
        ? null
        : ref.watch(placeDetailsProvider(placeId)).valueOrNull?.address?.trim();
    final image = stop.location?.imageUrl;

    return Material(
      color: checked ? AppColors.postPurpleWell : AppColors.screen,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: checked ? AppColors.postPurpleSoft : AppColors.line,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 92,
                child: image != null && image.isNotEmpty
                    ? CoverImage(source: image, fit: BoxFit.cover)
                    : ColoredBox(
                        color: AppColors.createBg,
                        child: Icon(
                          categoryIcon(stop.category),
                          color: AppColors.muted,
                        ),
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
                      _CategoryChip(category: stop.category),
                      const SizedBox(height: 6),
                      Text(
                        stop.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (address != null && address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 14),
                child: _CheckBox(checked: checked),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final ActivityCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.postPurpleSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(categoryIcon(category), size: 13, color: AppColors.postPurple),
          const SizedBox(width: 4),
          Text(
            categoryLabel(category),
            style: const TextStyle(
              color: AppColors.postPurple,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The square tick box the design uses — purple filled when on.
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? AppColors.postPurple : AppColors.screen,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? AppColors.postPurple : AppColors.postDashed,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.secondary,
    required this.onSecondary,
    required this.primary,
    required this.primaryColor,
    required this.onPrimary,
    this.busy = false,
  });

  final String secondary;
  final VoidCallback? onSecondary;
  final String primary;
  final Color primaryColor;
  final VoidCallback? onPrimary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: onSecondary,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: Text(
                secondary,
                style: const TextStyle(
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
            height: 50,
            child: FilledButton(
              onPressed: busy ? () {} : onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                disabledBackgroundColor: AppColors.line,
                disabledForegroundColor: AppColors.muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      primary,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

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
