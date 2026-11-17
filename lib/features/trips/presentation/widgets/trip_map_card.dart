import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/config/maps_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../itinerary_display.dart';

/// The day's stops on a Google map, with the design's own chrome over it.
///
/// Falls back to a labelled placeholder when the build has no Maps key (see
/// [MapsConfig]) or when nothing on the day has coordinates yet — the SDK
/// throws rather than degrading, so the map must not be built in either case.
class TripMapCard extends StatefulWidget {
  const TripMapCard({
    super.key,
    required this.stops,
    required this.onMenu,
  });

  final List<Activity> stops;
  final VoidCallback onMenu;

  @override
  State<TripMapCard> createState() => _TripMapCardState();
}

class _TripMapCardState extends State<TripMapCard> {
  GoogleMapController? _controller;

  List<Activity> get _plottable => widget.stops
      .where((stop) => stop.location?.hasCoordinates ?? false)
      .toList(growable: false);

  @override
  void didUpdateWidget(TripMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching day keeps the same map, so move the camera to the new stops.
    if (!identical(oldWidget.stops, widget.stops)) _frameStops();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 250,
        child: Stack(
          children: [
            Positioned.fill(child: _surface()),
            Positioned(
              top: 12,
              left: 12,
              child: _MapControl(
                icon: Icons.more_vert,
                tooltip: 'ตัวเลือกแผนที่',
                onTap: widget.onMenu,
                circular: true,
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _MapControl(
                    icon: Icons.add,
                    tooltip: 'ขยาย',
                    onTap: () => _zoom(1),
                  ),
                  const SizedBox(height: 8),
                  _MapControl(
                    icon: Icons.remove,
                    tooltip: 'ย่อ',
                    onTap: () => _zoom(-1),
                  ),
                  const SizedBox(height: 8),
                  _MapControl(
                    icon: Icons.near_me_outlined,
                    tooltip: 'จัดกรอบให้พอดี',
                    onTap: _frameStops,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _surface() {
    final stops = _plottable;
    if (!MapsConfig.isConfigured || stops.isEmpty) {
      return _MapPlaceholder(
        message: !MapsConfig.isConfigured
            ? 'แผนที่ยังไม่ได้ตั้งค่า'
            : 'สถานที่ในวันนี้ยังไม่มีพิกัด',
      );
    }
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _positionOf(stops.first),
        zoom: 12,
      ),
      markers: _markers(stops),
      polylines: _route(stops),
      onMapCreated: (controller) {
        _controller = controller;
        _frameStops();
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      // The card's own buttons sit over these corners.
      compassEnabled: false,
    );
  }

  Set<Marker> _markers(List<Activity> stops) => {
        for (var i = 0; i < stops.length; i++)
          Marker(
            markerId: MarkerId(stops[i].id),
            position: _positionOf(stops[i]),
            infoWindow: InfoWindow(
              title: '${i + 1}. ${stops[i].title}',
              snippet:
                  stops[i].time == null ? null : clockLabel(stops[i].time!),
            ),
          ),
      };

  /// The day's order, drawn as one line so the shape of the day reads at a
  /// glance. Only meaningful with two stops or more.
  Set<Polyline> _route(List<Activity> stops) {
    if (stops.length < 2) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('day-route'),
        points: stops.map(_positionOf).toList(growable: false),
        color: AppColors.brandPurple,
        width: 3,
      ),
    };
  }

  LatLng _positionOf(Activity stop) => LatLng(
        stop.location!.latitude!,
        stop.location!.longitude!,
      );

  Future<void> _zoom(double by) async {
    await _controller?.animateCamera(CameraUpdate.zoomBy(by));
  }

  /// Fits every plottable stop in view. This is what the locate button does:
  /// nothing here asks for the device's location, because reframing the day is
  /// what a traveller reading a plan actually wants.
  /// A single stop has no bounds to fit, so
  /// it is centred instead.
  Future<void> _frameStops() async {
    final controller = _controller;
    final stops = _plottable;
    if (controller == null || stops.isEmpty) return;

    if (stops.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_positionOf(stops.first), 14),
      );
      return;
    }

    final positions = stops.map(_positionOf);
    final lats = positions.map((p) => p.latitude);
    final lngs = positions.map((p) => p.longitude);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
          northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
        ),
        48,
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE9EFE8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 30, color: AppColors.muted),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.circular = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circular ? null : BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 19, color: AppColors.foreground),
        ),
      ),
    );
  }
}
