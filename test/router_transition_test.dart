import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/home/presentation/home_screen.dart';
import 'package:pluno/features/profile/presentation/profile_screen.dart';

import 'support/home_feed_fixtures.dart';

void main() {
  testWidgets('navigation swaps pages on the first frame, with no transition',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: homeOverrides(const []),
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    appRouter.goNamed(AppRoute.profile.name);
    // A single frame: with a slide/fade both pages would still be on screen.
    await tester.pump();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    addTearDown(() => appRouter.goNamed(AppRoute.home.name));
  });
}
