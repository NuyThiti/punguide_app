import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/cover_image.dart';
import '../domain/location_service.dart';
import '../domain/picked_location.dart';
import 'providers/location_providers.dart';
import 'widgets/location_permission_sheet.dart';

/// Location Access — the page that asks before anything on the device is read.
///
/// The illustration behind it is Home's own photo, so the ask arrives inside
/// the app's world rather than as a system-looking interstitial.
///
/// Whatever the OS answers, the traveller leaves here for the map picker: a
/// refusal — or a build with no location plugin at all (see [LocationService])
/// — means the origin is chosen by hand, not that ไปกัน stops working.
class LocationAccessScreen extends ConsumerStatefulWidget {
  const LocationAccessScreen({super.key, this.from});

  /// Where the traveller was heading when the gate caught them. Null when they
  /// came here directly, in which case ไว้ทีหลังนะ falls back to the board.

  final String? from;

  /// The same photo Home and the ไปกัน header put behind their heroes.
  static const String coverAsset = 'assets/images/home_hero.jpg';

  @override
  ConsumerState<LocationAccessScreen> createState() =>
      _LocationAccessScreenState();
}

class _LocationAccessScreenState extends ConsumerState<LocationAccessScreen> {
  bool _asking = false;

  @override
  Widget build(BuildContext context) {
    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Held to the top seven tenths rather than run full bleed. The
          // illustration is a 3:4 portrait and a phone frame is nearer 1:2, so
          // covering the whole screen would scale it until the suitcase fell
          // off the sides. This region is close to the artwork's own ratio, and
          // the sheet — a little over a third of the height — still laps over
          // its bottom edge on every phone size.
          const Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: 0.7,
              alignment: Alignment.topCenter,
              child: CoverImage(
                source: LocationAccessScreen.coverAsset,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: LocationPermissionSheet(
              busy: _asking,
              onAllow: _allow,
              onLater: _later,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _allow() async {
    setState(() => _asking = true);

    // The OS dialog the design shows over this sheet is raised inside
    // requestPermission — iOS draws it, not us.
    final status = await ref.read(locationServiceProvider).requestPermission();
    if (!mounted) return;

    await ref.read(locationPermissionProvider.notifier).record(status);
    if (!mounted) return;

    if (status == LocationPermissionStatus.granted) {
      final fix = await ref.read(locationServiceProvider).currentFix();
      if (!mounted) return;
      if (fix != null) {
        ref.read(locationFixProvider.notifier).state = LocationFixPoint(
          latitude: fix.latitude,
          longitude: fix.longitude,
        );
      }
    }

    setState(() => _asking = false);
    // Straight to the map, as the design has it: having just granted the
    // permission, the next thing to settle is which place the board measures
    // from.
    context.goNamed(AppRoute.locationPicker.name);
  }

  /// "ไว้ทีหลังนะ" — remembered as a refusal so the app does not ask twice in
  /// one run, then on to wherever they were going. Saying "later" to the OS
  /// does not mean giving up on the board: the origin can still be set by hand
  /// in the picker.
  Future<void> _later() async {
    await ref
        .read(locationPermissionProvider.notifier)
        .record(LocationPermissionStatus.denied);
    if (!mounted) return;
    context.go(widget.from ?? '/paigun');
  }
}
