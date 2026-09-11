import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/config/maps_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/picked_location.dart';

/// The map the pin sits on.
///
/// Falls back to a labelled plate when the build has no Maps key (see
/// [MapsConfig]) — the iOS SDK throws rather than degrading when
/// `GMSServices.provideAPIKey` was never called, so `GoogleMap` must not be
/// built in that case. The fallback still draws the pin, so the picker reads
/// the same and the sheet below it stays usable.
class LocationMapSurface extends StatefulWidget {
  const LocationMapSurface({
    super.key,
    required this.target,
    required this.satellite,
    required this.onTapPoint,
  });

  /// Where the pin is. Null before anything has been chosen.
  final PickedLocation? target;

  final bool satellite;

  /// Dropping the pin somewhere the search did not offer.
  final void Function(double latitude, double longitude) onTapPoint;

  @override
  State<LocationMapSurface> createState() => _LocationMapSurfaceState();
}

class _LocationMapSurfaceState extends State<LocationMapSurface> {
  GoogleMapController? _controller;

  /// Where the camera opens: เขตพระนคร, the district the design is drawn on.
  static const _fallbackCamera = LatLng(13.7563, 100.4930);

  @override
  void didUpdateWidget(LocationMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.target;
    final was = oldWidget.target;
    if (target == null ||
        (was != null &&
            was.latitude == target.latitude &&
            was.longitude == target.longitude)) {
      return;
    }
    _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(target.latitude, target.longitude), 15),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MapsConfig.isConfigured) return _Placeholder(target: widget.target);

    final target = widget.target;
    final position = target == null
        ? _fallbackCamera
        : LatLng(target.latitude, target.longitude);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: position, zoom: 15),
      mapType: widget.satellite ? MapType.hybrid : MapType.normal,
      markers: target == null
          ? const <Marker>{}
          : {
              Marker(
                markerId: const MarkerId('picked'),
                position: position,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
              ),
            },
      onTap: (point) => widget.onTapPoint(point.latitude, point.longitude),
      onMapCreated: (controller) => _controller = controller,
      // The picker's own chrome floats over all four corners.
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.target});

  final PickedLocation? target;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.locationMapFallback,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              target == null ? Icons.map_outlined : Icons.location_on,
              size: target == null ? 40 : 64,
              color: target == null ? AppColors.muted : AppColors.locationPin,
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'แผนที่ยังไม่ได้ตั้งค่า\nค้นหาชื่อสถานที่เพื่อเลือกตำแหน่งได้',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
