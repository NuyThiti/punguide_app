import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/location_access/presentation/providers/location_providers.dart';

class PlunoApp extends ConsumerStatefulWidget {
  const PlunoApp({super.key});

  @override
  ConsumerState<PlunoApp> createState() => _PlunoAppState();
}

class _PlunoAppState extends ConsumerState<PlunoApp> {
  /// Once per run. The account keeps a single fix and overwrites it, so a
  /// second sync in the same session would cost a request and teach it
  /// nothing.
  bool _syncedLocation = false;

  @override
  void initState() {
    super.initState();

    // Waits for the restored session rather than firing now: the session comes
    // back asynchronously, and `/users/me/location` is behind the auth guard,
    // so syncing on the first frame would simply be skipped as signed-out.
    ref.listenManual(
      isSignedInProvider,
      fireImmediately: true,
      (_, signedIn) {
        if (!signedIn || _syncedLocation) return;
        _syncedLocation = true;
        // Deliberately not awaited: nothing on screen is waiting for it, and
        // ensureFix swallows its own failures.
        ref.read(locationFixProvider.notifier).ensureFix();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
