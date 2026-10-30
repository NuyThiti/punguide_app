import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../location_access/data/location_sync.dart';
import '../../../location_access/domain/location_service.dart';
import '../../../location_access/presentation/providers/location_providers.dart';

/// What [showLocationPicker] returns for "ลบสถานที่ออกจากจุดนี้".
const clearedLocation = Place(id: '', name: '');

/// Asks where a stop happens. Returns the chosen place, [clearedLocation]
/// when the traveller took the place off, or null when dismissed.
///
/// Drawn like the post composer's Add Location sheet, but not that sheet: a
/// stop needs one of *our* place ids as `placeId`. That sheet's "Use Current
/// location" returns a pin with no id, and its map sets the account's own
/// location — neither can name a place for a stop. Here every row is a place
/// we hold. Search also resolves photos: a place cached without one shows no
/// image on every stop that links it afterwards.
Future<Place?> showLocationPicker(
  BuildContext context, {
  String? initial,
  bool hasPlace = false,
}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => LocationPickerSheet(initial: initial, hasPlace: hasPlace),
  );
}

class LocationPickerSheet extends ConsumerStatefulWidget {
  const LocationPickerSheet({super.key, this.initial, this.hasPlace = false});

  /// Seeds the search, e.g. with the activity name already typed.
  final String? initial;

  /// The stop already has a place, so the sheet offers to remove it.
  final bool hasPlace;

  @override
  ConsumerState<LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet> {
  late final TextEditingController _query;
  Timer? _debounce;

  List<Place> _results = const <Place>[];
  bool _searching = false;
  String? _searchError;

  /// Places around the traveller, once "Use Current location" has a fix.
  List<_Nearby>? _nearby;
  bool _locating = false;
  String? _locateNote;

  /// Answers can arrive out of order; only the latest search may land.
  int _generation = 0;

  bool get _hasQuery => _query.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initial ?? '');
    if (_hasQuery) _search(_query.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String raw) async {
    final query = raw.trim();
    final generation = ++_generation;
    if (query.isEmpty) {
      setState(() {
        _results = const <Place>[];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final api = await ref.read(plunoApiProvider.future);
      final found =
          await api.places.search(query, limit: 20, resolvePhotos: true);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    } on ApiException catch (failure) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        _searchError = failure.message;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        _searchError = '$error';
      });
    }
  }

  /// "Use Current location": the places around the device, nearest first,
  /// for the traveller to choose from. Not the nearest one picked for them —
  /// `/places/suggest` returns popular places, not every building, so the
  /// closest result is not necessarily where they are standing.
  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locateNote = null;
    });
    try {
      // Where "current" comes from, in order: a reading this run already
      // took; the device; then the account's stored position — the point
      // every other screen calls "where I am". That last one matters today:
      // the app ships no location plugin, so the device answers
      // `unavailable` on every phone.
      final known = ref.read(locationFixProvider);
      double? lat = known?.latitude, lng = known?.longitude;
      LocationPermissionStatus? status;
      if (lat == null || lng == null) {
        final service = ref.read(locationServiceProvider);
        status = await service.requestPermission();
        await ref.read(locationPermissionProvider.notifier).record(status);
        if (status == LocationPermissionStatus.granted) {
          final fix = await service.currentFix();
          if (fix != null) {
            // observe, not capture: finding a stop is not the traveller
            // reporting where they are, so nothing goes onto the account.
            ref.read(locationFixProvider.notifier).observe(fix);
            lat = fix.latitude;
            lng = fix.longitude;
          }
        }
      }
      if (lat == null || lng == null) {
        final stored = await ref.read(locationSyncProvider).pull();
        lat = stored?.latitude;
        lng = stored?.longitude;
      }
      if (lat == null || lng == null) {
        _finishLocating(
          note: status == LocationPermissionStatus.denied
              ? 'ไม่ได้รับอนุญาตให้ใช้ตำแหน่ง ลองค้นหาด้วยชื่อแทน'
              : 'ยังไม่มีตำแหน่งปัจจุบัน ลองค้นหาด้วยชื่อแทน',
        );
        return;
      }

      final api = await ref.read(plunoApiProvider.future);
      final places = await api.places.suggest(
        latitude: lat,
        longitude: lng,
        radiusMeters: 800,
        limit: 20,
      );
      final rows = [
        for (final place in places)
          _Nearby(place, _distanceKm(lat, lng, place)),
      ]..sort((a, b) =>
          (a.km ?? double.infinity).compareTo(b.km ?? double.infinity));
      _finishLocating(
        nearby: rows,
        note: rows.isEmpty ? 'ไม่พบสถานที่ใกล้ตำแหน่งของคุณ' : null,
      );
    } on ApiException catch (failure) {
      _finishLocating(note: 'หาสถานที่ใกล้ไม่สำเร็จ: ${failure.message}');
    } catch (error) {
      _finishLocating(note: 'หาสถานที่ใกล้ไม่สำเร็จ: $error');
    }
  }

  void _finishLocating({List<_Nearby>? nearby, String? note}) {
    if (!mounted) return;
    setState(() {
      _locating = false;
      _nearby = nearby ?? _nearby;
      _locateNote = note;
    });
  }

  static double? _distanceKm(double lat, double lng, Place place) {
    final plat = place.latitude, plng = place.longitude;
    if (plat == null || plng == null) return null;
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(plat - lat), dLng = rad(plng - lng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) *
            math.cos(rad(plat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  void _pick(Place place) => Navigator.of(context).pop(place);

  @override
  Widget build(BuildContext context) {
    // A fixed tall sheet, as the reference draws it in every state, so it
    // does not jump between empty, loading and a full list. The keyboard
    // takes its height off the top instead.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight =
        (screenHeight * 0.86 - keyboard).clamp(300.0, screenHeight * 0.86);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      // Material, not a decorated box: the rows are ListTiles, which paint
      // their ink on the nearest Material.
      child: Material(
        color: AppColors.screen,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              children: [
                _Header(onClose: () => Navigator.of(context).pop()),
                const SizedBox(height: 16),
                _SearchField(
                  controller: _query,
                  loading: _searching,
                  onChanged: _onChanged,
                  onSubmitted: _search,
                ),
                const SizedBox(height: 14),
                Expanded(child: _body()),
                if (widget.hasPlace)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(clearedLocation),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('ลบสถานที่ออกจากจุดนี้'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                      ),
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

  Widget _body() {
    if (_hasQuery) {
      if (_searchError != null) return _Note('ค้นหาไม่สำเร็จ: $_searchError');
      if (_searching && _results.isEmpty) return const SizedBox.shrink();
      if (_results.isEmpty) return const _Note('ไม่พบสถานที่ ลองคำค้นอื่น');
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          for (final place in _results)
            _PlaceRow(
              name: place.name,
              subtitle: place.address ?? '',
              onTap: () => _pick(place),
            ),
        ],
      );
    }

    final nearby = _nearby;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _CurrentLocationRow(
          busy: _locating,
          onTap: _locating ? null : _useCurrentLocation,
        ),
        if (_locateNote != null) _Note(_locateNote!),
        if (nearby != null && nearby.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 2),
            child: Text(
              'ใกล้ตำแหน่งของคุณ',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final row in nearby)
            _PlaceRow(
              name: row.place.name,
              subtitle: [
                if (row.km != null) _distanceLabel(row.km!),
                if ((row.place.address ?? '').isNotEmpty) row.place.address!,
              ].join(' · '),
              onTap: () => _pick(row.place),
            ),
        ],
      ],
    );
  }

  static String _distanceLabel(double km) => km < 1
      ? '${(km * 1000).round()} ม.'
      : '${km.toStringAsFixed(km < 10 ? 1 : 0)} กม.';
}

class _Nearby {
  const _Nearby(this.place, this.km);

  final Place place;
  final double? km;
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

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
        Tooltip(
          message: 'ปิด',
          child: Material(
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
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool loading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      maxLength: 200,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15, color: AppColors.foreground),
      decoration: InputDecoration(
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: AppColors.screen,
        hintText: 'ค้นหาสถานที่',
        hintStyle:
            const TextStyle(color: AppColors.postFieldHint, fontSize: 15),
        prefixIcon: const Icon(Icons.search, size: 21, color: AppColors.muted),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: border(AppColors.chipBorder),
        enabledBorder: border(AppColors.chipBorder),
        focusedBorder: border(AppColors.locationAction, 1.3),
      ),
    );
  }
}

class _CurrentLocationRow extends StatelessWidget {
  const _CurrentLocationRow({required this.onTap, this.busy = false});

  final VoidCallback? onTap;
  final bool busy;

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
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(9),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location,
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
  const _PlaceRow({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
        name,
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

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 18),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
