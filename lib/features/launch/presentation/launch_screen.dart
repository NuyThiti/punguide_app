import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../location_access/presentation/providers/location_providers.dart';
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
/// The answers are read **from the device only**. They are still mirrored onto
/// the account — see [OnboardingSync] — but the account is deliberately not
/// consulted here: clearing the app's data has to give the full sequence back,
/// which is what makes the flow testable and what a traveller who wipes the
/// app expects.
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
