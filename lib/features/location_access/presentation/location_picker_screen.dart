import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../paigun/presentation/providers/paigun_providers.dart';
import '../data/location_sync.dart';
import '../domain/picked_location.dart';
import 'providers/location_providers.dart';
import 'widgets/location_map_surface.dart';
import 'widgets/location_search_bar.dart';
import 'widgets/picked_location_sheet.dart';

/// The map half of Location Access: search a place, see where it lands, and
/// confirm it as the point ไปกัน measures "near me" from.
///
/// Reached from [LocationAccessScreen] whichever way the permission went — a
/// traveller who refused the OS dialog still needs a way to say where they
/// are, and this is it.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _searchController = TextEditingController();

  /// Held in the screen rather than a provider: it is scratch state for one
  /// visit, and the confirmed answer goes to [paigunOriginProvider] instead.
  /// Null until the account's stored fix comes back, a search is picked, or
  /// the map itself is tapped — never a guess.
  PickedLocation? _picked;

  bool _satellite = false;

  @override
  void initState() {
    super.initState();
    _loadInitialPin();
    _loadFix();
  }

  /// Opens on whatever the account already has stored — the same fix
  /// `/location`'s permission flow keeps in step with the device — rather
  /// than a hardcoded district. Nothing stored means nothing pinned: the
  /// picker opens blank and the sheet says so, instead of presenting a place
  /// nobody actually confirmed.
  ///
  /// `_picked` may already have something in it by the time this resolves —
  /// a tap or a search does not wait — so this never overwrites a choice the
  /// traveller has since made.
  Future<void> _loadInitialPin() async {
    final stored = await ref.read(locationSyncProvider).pull();
    if (!mounted || stored == null || _picked != null) return;
    setState(
      () => _picked = PickedLocation(
        name: 'ตำแหน่งล่าสุดที่บันทึกไว้',
        address: '${stored.latitude.toStringAsFixed(4)}, '
            '${stored.longitude.toStringAsFixed(4)}',
        latitude: stored.latitude,
        longitude: stored.longitude,
      ).measuredFrom(ref.read(locationFixProvider)),
    );
  }

  /// Finds a position to measure distances from.
  ///
  /// The permission is remembered between launches and the fix is not, so
  /// without this the distances below would quietly stop showing on the second
  /// run. [LocationFixController.ensureFix] takes the account's stored fix
  /// first — no GPS, no wait — then refreshes it from the device.
  Future<void> _loadFix() async {
    await ref.read(locationFixProvider.notifier).ensureFix();
    if (!mounted) return;

    final point = ref.read(locationFixProvider);
    if (point == null) return;
    setState(() => _picked = _picked?.measuredFrom(point));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final query = ref.watch(locationQueryProvider);
    final searching = query.trim().length >= minLocationQueryLength;

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          Positioned.fill(
            child: LocationMapSurface(
              target: _picked,
              satellite: _satellite,
              onTapPoint: _pinPoint,
            ),
          ),
          Positioned(
            top: topInset + 10,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LocationSearchBar(
                  controller: _searchController,
                  onBack: _close,
                  onChanged: (text) =>
                      ref.read(locationQueryProvider.notifier).state = text,
                  onToggleLayer: () => setState(() => _satellite = !_satellite),
                ),
                // Only while there is a query — the results cover the map, so
                // they must not linger once a place has been chosen.
                if (searching) _ResultsPanel(onSelect: _select),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: PickedLocationSheet(
              location: _picked,
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }

  /// A tap on bare map. There is no reverse-geocode endpoint, so the pin keeps
  /// the coordinates and says as much rather than inventing a name for them.
  void _pinPoint(double latitude, double longitude) {
    _select(
      PickedLocation(
        name: 'ตำแหน่งที่ปักไว้',
        address:
            '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  void _select(PickedLocation place) {
    setState(
      () => _picked = place.measuredFrom(ref.read(locationFixProvider)),
    );
    // Choosing closes the list: the traveller is looking at the map now.
    _searchController.clear();
    ref.read(locationQueryProvider.notifier).state = '';
    FocusScope.of(context).unfocus();
  }

  void _confirm() {
    final place = _picked;
    if (place == null) return;

    ref.read(paigunOriginProvider.notifier).state = place.toOrigin();
    context.goNamed(AppRoute.paigun.name);
  }

  /// Entered from the permission page as well as from the ไปกัน header, so
  /// there is not always something to pop back to.
  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.paigun.name);
    }
  }
}

/// The search results, floating under the field over the map.
class _ResultsPanel extends ConsumerWidget {
  const _ResultsPanel({required this.onSelect});

  final ValueChanged<PickedLocation> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(locationResultsProvider);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: results.when(
        data: (places) => places.isEmpty
            ? const _PanelMessage('ไม่พบสถานที่ที่ค้นหา')
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: places.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 56,
                  color: AppColors.line,
                ),
                itemBuilder: (context, index) => _ResultRow(
                  place: places[index],
                  onTap: () => onSelect(places[index]),
                ),
              ),
        // Riverpod carries the previous results into the new loading state, so
        // the panel only shows a spinner on the very first search.
        loading: () => const _PanelMessage('กำลังค้นหา…'),
        error: (error, _) => _PanelMessage(_messageFor(error)),
      ),
    );
  }

  static String _messageFor(Object error) {
    if (error is! ApiException) return 'ค้นหาสถานที่ไม่สำเร็จ';
    return error.isNetworkFailure
        ? 'เชื่อมต่อไม่ได้ ลองใหม่อีกครั้ง'
        : 'ค้นหาสถานที่ไม่สำเร็จ (${error.statusCode})';
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.place, required this.onTap});

  final PickedLocation place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = place.subtitle;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.postIconWell,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.locationPin,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    );
  }
}
