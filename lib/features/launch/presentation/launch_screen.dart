import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../location_access/presentation/providers/location_providers.dart';

/// The first route of every run: holds the logo up while the last session is
/// restored, then sends the traveller on through the launch sequence —
///
/// 1. Login, when nobody is signed in;
/// 2. Location Access, while the location question has never been answered;
/// 3. Home.
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

    final afterSignIn = ref.read(locationPermissionProvider) == null
        ? '/location?from=${Uri.encodeComponent('/')}'
        : '/';
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
