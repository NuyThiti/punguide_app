import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../location_access/domain/location_service.dart';
import '../../location_access/presentation/providers/location_providers.dart';
import '../../onboarding/data/onboarding_sync.dart';
import '../../trip_style/presentation/providers/trip_style_providers.dart';

/// The first route of every run: holds the logo up while the last session is
/// restored, then sends the traveller on through the launch sequence —
///
/// 1. Login, when nobody is signed in;
/// 2. Location Access, while the location question has never been answered;
/// 3. สไตล์เที่ยวของฉัน, while that one has not been answered either;
/// 4. Home.
///
/// Each step carries the rest of the sequence with it as `then` / `from`, so
/// a traveller who has already answered one of them is never shown it twice
/// and never lands short of Home.
///
/// Answers are kept on the device, which is what the steps above read. When
/// one is missing and there is a session, the account is asked first — that
/// is the whole point of storing them there: a traveller who answered on
/// their last phone should not be asked again on this one.
///
/// It waits rather than guessing because the session comes back
/// asynchronously: routing on the first frame would show a returning
/// traveller the login screen they do not need.
class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await ref.read(sessionRestoredProvider.future);
    // Somebody — a deep link, a test — has already moved on.
    if (!mounted) return;

    if (ref.read(isSignedInProvider)) {
      await _adoptAccountAnswers();
      if (!mounted) return;
    }

    // Built back to front: Home, then whichever questions are still owed in
    // front of it.
    var next = '/';
    if (ref.read(needsTripStyleProvider)) {
      next = '/trip-style?then=${Uri.encodeComponent(next)}';
    }
    final afterSignIn = ref.read(locationPermissionProvider) == null
        ? '/location?from=${Uri.encodeComponent(next)}'
        : next;
    if (ref.read(isSignedInProvider)) {
      context.go(afterSignIn);
    } else {
      context.go('/login?then=${Uri.encodeComponent(afterSignIn)}');
    }
  }

  /// Takes whatever the account has already answered, for the questions this
  /// device has not.
  ///
  /// Only ever fills gaps: a local answer is the newer one by definition —
  /// it was given on this device — so it is never overwritten from the
  /// server. A failed or signed-out read leaves everything as it was and the
  /// sequence simply asks.
  Future<void> _adoptAccountAnswers() async {
    final needsLocation = ref.read(locationPermissionProvider) == null;
    final needsStyle = ref.read(needsTripStyleProvider);
    if (!needsLocation && !needsStyle) return;

    final preferences = await ref.read(onboardingSyncProvider).pull();
    if (preferences == null || !mounted) return;

    final locationAccess = preferences.locationAccess;
    if (needsLocation && locationAccess != null) {
      await ref.read(locationPermissionProvider.notifier).adopt(
            switch (locationAccess.status) {
              LocationAccessAnswer.granted => LocationPermissionStatus.granted,
              LocationAccessAnswer.denied => LocationPermissionStatus.denied,
              LocationAccessAnswer.later => LocationPermissionStatus.later,
            },
          );
      if (!mounted) return;
    }

    final travelStyle = preferences.travelStyle;
    if (needsStyle && travelStyle != null) {
      await ref
          .read(tripStyleProvider.notifier)
          .adopt(tripStyleFrom(travelStyle));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screen,
      body: Center(
        child: Image.asset(
          'assets/images/app_logo.png',
          width: 120,
          height: 120,
        ),
      ),
    );
  }
}
