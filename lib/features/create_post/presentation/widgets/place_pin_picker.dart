import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../location_access/domain/location_service.dart';
import '../../../location_access/presentation/providers/location_providers.dart';
import '../../domain/models/post_draft.dart';
import '../providers/place_pin_providers.dart';

/// What [showPlacePinPicker] returns for "ลบสถานที่": the design's row carries
/// only a chevron, so taking a pin off again happens in the sheet.
const clearedPlacePin = PostPlace(id: '', name: '');

/// Asks where the spot is. Returns null when dismissed, [clearedPlacePin] when
/// the traveller took the pin off.
Future<PostPlace?> showPlacePinPicker(
  BuildContext context, {
  bool hasPlace = false,
  SectionPlaceOptions? suggestions,
}) {
  return showModalBottomSheet<PostPlace>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) =>
        _PlacePinPicker(hasPlace: hasPlace, suggestions: suggestions),
  );
}

/// One of the assistant's candidates as a pin. It keeps Google's `placeId`,
/// which is what the confirmed location carries up.
PostPlace postPlaceFromSuggestion(SuggestedPlace place) => PostPlace(
      id: place.placeId ?? '',
      placeId: place.placeId,
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
    );

class _PlacePinPicker extends ConsumerStatefulWidget {
  const _PlacePinPicker({required this.hasPlace, this.suggestions});

  /// The spot already carries a place, so the sheet offers to remove it.
  final bool hasPlace;

  /// What the assistant thinks this spot is, when it drafted one. These lead
  /// the sheet: they are the rows the traveller came to confirm.
  final SectionPlaceOptions? suggestions;

  @override
  ConsumerState<_PlacePinPicker> createState() => _PlacePinPickerState();
}

class _PlacePinPickerState extends ConsumerState<_PlacePinPicker> {
  final _controller = TextEditingController();
  bool _asking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Runs the OS dialog. The map is still offered as the way out, because the
  /// answer can be a refusal — or the device can simply fail to produce a fix
  /// indoors — and a traveller must never be stuck on a prompt.
  Future<void> _turnOnLocation() async {
    setState(() => _asking = true);
    final status = await ref.read(locationServiceProvider).requestPermission();
    if (!mounted) return;

    await ref.read(locationPermissionProvider.notifier).record(status);
    if (!mounted) return;

    if (status == LocationPermissionStatus.granted) {
      final fix = await ref.read(locationServiceProvider).currentFix();
      if (!mounted) return;
      // observe, not capture: this reading is only to centre the map and
      // find spots nearby, not the traveller reporting where they are, so it
      // must not be mirrored onto the account's `/users/me/location`.
      if (fix != null) ref.read(locationFixProvider.notifier).observe(fix);
    }
    setState(() => _asking = false);

    if (status != LocationPermissionStatus.granted) _openMap();
  }

  /// Hands over to the map, where the traveller sets the point by hand. The
  /// sheet closes first so the map is not buried under it.
  void _openMap() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.pushNamed(AppRoute.locationPicker.name);
  }

  /// What fills the sheet: the assistant's candidates first when it drafted
  /// any, then whatever the traveller is searching for or standing near.
  Widget _body({
    required bool searching,
    required List<SuggestedPlace> suggested,
    required ({double lat, double lng})? origin,
    required AsyncValue<List<PostPlace>> results,
    required List<PostPlace> rows,
  }) {
    if (!searching && suggested.isNotEmpty) {
      return _SuggestedList(
        options: widget.suggestions!,
        onPick: (place) =>
            Navigator.of(context).pop(postPlaceFromSuggestion(place)),
        nearby: origin == null ||
                widget.suggestions?.source == PlaceSource.confirmedPlace
            ? null
            : _Results(
                searching: false,
                results: results,
                rows: rows,
                showCurrent: ref.watch(hasDeviceFixProvider),
                onPick: (place) => Navigator.of(context).pop(place),
                shrinkWrap: true,
              ),
      );
    }
    if (origin == null && !searching) {
      return _LocationOffState(busy: _asking, onTurnOn: _turnOnLocation);
    }
    return _Results(
      searching: searching,
      results: results,
      rows: rows,
      showCurrent: !searching && ref.watch(hasDeviceFixProvider),
      onPick: (place) => Navigator.of(context).pop(place),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(placePinQueryProvider).trim();
    final searching = query.length >= minPlaceQueryLength;
    final results = searching
        ? ref.watch(placePinResultsProvider)
        : widget.suggestions?.source == PlaceSource.confirmedPlace
            ? const AsyncData<List<PostPlace>>([])
            : ref.watch(nearbyPlacePinsProvider);
    final rows = results.valueOrNull ?? const <PostPlace>[];
    final origin = ref.watch(placePinOriginProvider);
    final suggested = widget.suggestions?.options ?? const <SuggestedPlace>[];

    // A fixed tall sheet, as the design draws it in every state: hugging the
    // content would make it jump between the prompt, the spinner and a full
    // list. The keyboard takes its height off the top instead.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight =
        (screenHeight * 0.86 - keyboard).clamp(300.0, screenHeight * 0.86);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      // Material, not a decorated box: the rows are ListTiles, which paint
      // their ink on the nearest Material and assert when a coloured box sits
      // in between.
      child: Material(
        color: AppColors.screen,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              children: [
                _SheetHeader(onClose: () => Navigator.of(context).pop()),
                const SizedBox(height: 16),
                _SearchField(
                  controller: _controller,
                  loading: searching && results.isLoading,
                  onChanged: (value) =>
                      ref.read(placePinQueryProvider.notifier).state = value,
                  onMap: _openMap,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _body(
                    searching: searching,
                    suggested: suggested,
                    origin: origin,
                    results: results,
                    rows: rows,
                  ),
                ),
                if (widget.hasPlace)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(clearedPlacePin),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('ลบสถานที่ออกจากจุดนี้'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted),
                    ),
                  ),
                SizedBox(height: 12 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 34),
        const Expanded(
          child: Text(
            'Add Location',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Material(
          color: AppColors.postDraftBg,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onClose,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.close, size: 19, color: AppColors.foreground),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.loading,
    required this.onChanged,
    required this.onMap,
  });

  final TextEditingController controller;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 200,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, color: AppColors.foreground),
      decoration: InputDecoration(
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: AppColors.screen,
        hintText: 'ค้นหาสถานที่',
        hintStyle: const TextStyle(
          color: AppColors.postFieldHint,
          fontSize: 15,
        ),
        prefixIcon: const Icon(Icons.search, size: 21, color: AppColors.muted),
        suffixIcon: Padding(
          padding: const EdgeInsets.all(7),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(9),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _MapButton(onTap: onMap),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.chipBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.chipBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide:
              const BorderSide(color: AppColors.locationAction, width: 1.3),
        ),
      ),
    );
  }
}

/// Opens the map, for setting the point by hand.
class _MapButton extends StatelessWidget {
  const _MapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'เลือกจากแผนที่',
      child: Material(
        color: AppColors.locationLayerWell,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.map_outlined,
                size: 19, color: AppColors.locationPin),
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.searching,
    required this.results,
    required this.rows,
    required this.showCurrent,
    required this.onPick,
    this.shrinkWrap = false,
  });

  final bool searching;
  final AsyncValue<List<PostPlace>> results;
  final List<PostPlace> rows;

  /// The device knows where the traveller is, so the list can be led by it.
  final bool showCurrent;

  final ValueChanged<PostPlace> onPick;

  /// Nested under the suggestions, where the scroll belongs to the parent.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (results.hasError && rows.isEmpty) {
      return const _PickerNote('ค้นหาสถานที่ไม่สำเร็จ ลองอีกครั้ง');
    }
    if (rows.isEmpty && !showCurrent) {
      return _PickerNote(
        results.isLoading
            ? 'กำลังค้นหา…'
            : searching
                ? 'ไม่พบสถานที่ที่ตรงกับคำค้น'
                : 'ยังไม่พบสถานที่ใกล้เคียง ลองค้นหาด้วยชื่อ',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      itemCount: rows.length + (showCurrent ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 1,
        color: AppColors.line,
        indent: 58,
      ),
      itemBuilder: (context, index) {
        if (showCurrent && index == 0) {
          return _CurrentLocationRow(onTap: () => onPick(_here(rows)));
        }
        final place = rows[index - (showCurrent ? 1 : 0)];
        return _PlaceRow(place: place, onTap: () => onPick(place));
      },
    );
  }

  /// The traveller's own position as a pin. It borrows the nearest place's
  /// address because the API has no reverse geocode — and only when that place
  /// is close enough to describe where they are standing.
  PostPlace _here(List<PostPlace> nearby) {
    final closest = nearby.isEmpty ? null : nearby.first;
    final near = (closest?.distanceKm ?? 1) < 0.15;
    return PostPlace(
      id: '',
      name: 'ตำแหน่งปัจจุบัน',
      area: near ? closest!.area : null,
      address: near ? closest!.address : null,
      distanceKm: 0,
    );
  }
}

/// "Use Current location", on its own tinted card at the head of the list.
class _CurrentLocationRow extends StatelessWidget {
  const _CurrentLocationRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.postDraftBg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.screen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location,
                      size: 19, color: AppColors.locationPin),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Use Current location',
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place, required this.onTap});

  final PostPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = place.subtitle;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.paigunPinWell,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.location_on,
            size: 19, color: AppColors.locationPin),
      ),
      title: Text(
        place.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
    );
  }
}

/// The assistant's candidates for this spot, with whatever it is standing near
/// underneath. Nothing here is confirmed until one is tapped — the draft comes
/// back `suggested` on purpose, so a guessed place can never go public unseen.
class _SuggestedList extends StatelessWidget {
  const _SuggestedList({
    required this.options,
    required this.onPick,
    required this.nearby,
  });

  final SectionPlaceOptions options;
  final ValueChanged<SuggestedPlace> onPick;
  final Widget? nearby;

  /// Where these came from, in the traveller's words.
  ///
  /// Worth a line because the four sources are not equally trustworthy and
  /// look identical once they are rows in a list: a place under the camera is
  /// not the same claim as one the assistant read off a sign, and a place near
  /// where the traveller is standing says nothing about a photo taken
  /// somewhere else entirely.
  String? get _sourceNote => switch (options.source) {
        PlaceSource.photo => 'จากพิกัดที่ติดมากับรูป',
        PlaceSource.locationName => 'จากสถานที่ที่คุณระบุไว้เอง',
        PlaceSource.confirmedPlace => 'จากสถานที่ที่คุณเลือก',
        PlaceSource.currentLocation =>
          'รูปไม่มีพิกัด จึงหาจากตำแหน่งของคุณตอนนี้ ไม่ใช่ที่ที่ถ่ายรูป',
        PlaceSource.image =>
          'ผู้ช่วยเดาจากสิ่งที่เห็นในภาพ เช่น ป้ายหรือจุดสังเกต ควรตรวจก่อนยืนยัน',
        PlaceSource.none => null,
      };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Text(
                'สถานที่ที่ผู้ช่วยแนะนำ',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              if (options.confidence == PlaceConfidence.low)
                const Flexible(
                  child: Text(
                    'ยังไม่ค่อยมั่นใจ ลองตรวจดู',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        if (_sourceNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  options.source == PlaceSource.image
                      ? Icons.auto_awesome_outlined
                      : Icons.info_outline,
                  size: 14,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _sourceNote!,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        if (options.openingHours case final hours?)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule, color: AppColors.postPurple),
            title: const Text('เวลาเปิด–ปิดที่แนบมากับคำแนะนำ'),
            subtitle: Text(hours.closedToday
                ? 'วันนี้ปิด'
                : hours.openAllDay
                    ? 'เปิด 24 ชั่วโมง'
                    : [hours.opensAt, hours.closesAt]
                        .whereType<String>()
                        .join('–')),
            children: [
              for (final day in hours.weekdayDescriptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child:
                      Align(alignment: Alignment.centerLeft, child: Text(day)),
                ),
            ],
          ),
        for (final place in options.options)
          _SuggestedRow(place: place, onTap: () => onPick(place)),
        if (nearby != null) ...[
          const Divider(height: 26, thickness: 1, color: AppColors.line),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'ใกล้ตัวคุณ',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          nearby!,
        ],
      ],
    );
  }
}

class _SuggestedRow extends StatelessWidget {
  const _SuggestedRow({required this.place, required this.onTap});

  final SuggestedPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rating = place.rating;
    final subtitle = <String>[
      if (place.category != null && place.category!.isNotEmpty) place.category!,
      if (rating != null) '★ ${rating.toStringAsFixed(1)}',
    ].join(' • ');

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.postPurpleWell,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome,
            size: 18, color: AppColors.postPurple),
      ),
      title: Text(
        place.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
    );
  }
}

/// Nothing can be suggested until the app knows where the traveller is.
class _LocationOffState extends StatelessWidget {
  const _LocationOffState({required this.busy, required this.onTurnOn});

  final bool busy;
  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.postDraftBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_searching,
                  size: 32, color: Color(0xFF9A9A95)),
            ),
            const SizedBox(height: 18),
            const Text(
              'Find places nearby',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Turn on Location Services to see suggestions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: busy ? null : onTurnOn,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.locationAction,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                ),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Turn on Location Services',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerNote extends StatelessWidget {
  const _PickerNote(this.text);

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
