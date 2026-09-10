import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/shared/layout/screen_class.dart';

void main() {
  test('the breakpoints land on Material window size classes', () {
    expect(ScreenClass.fromWidth(360), ScreenClass.compact);
    expect(ScreenClass.fromWidth(393), ScreenClass.compact);
    expect(ScreenClass.fromWidth(599.9), ScreenClass.compact);
    expect(ScreenClass.fromWidth(600), ScreenClass.medium);
    expect(ScreenClass.fromWidth(834), ScreenClass.medium);
    expect(ScreenClass.fromWidth(839.9), ScreenClass.medium);
    expect(ScreenClass.fromWidth(840), ScreenClass.expanded);
    expect(ScreenClass.fromWidth(1194), ScreenClass.expanded);
  });

  test('pick falls back to the next class down', () {
    expect(ScreenClass.compact.pick(compact: 1, medium: 2, expanded: 3), 1);
    expect(ScreenClass.medium.pick(compact: 1, medium: 2, expanded: 3), 2);
    expect(ScreenClass.expanded.pick(compact: 1, medium: 2, expanded: 3), 3);

    // A layout that only widens once names one size.
    expect(ScreenClass.medium.pick(compact: 1, medium: 2), 2);
    expect(ScreenClass.expanded.pick(compact: 1, medium: 2), 2);
    expect(ScreenClass.expanded.pick(compact: 1), 1);
  });

  group('contentGutter', () {
    test('an uncapped column keeps the minimum padding', () {
      expect(
        contentGutter(393, maxWidth: double.infinity, minPadding: 16),
        16,
      );
    });

    test('a screen narrower than the cap keeps the minimum padding', () {
      expect(contentGutter(500, maxWidth: 620, minPadding: 24), 24);
    });

    test('a wide screen centres the column instead of stretching it', () {
      // 1194 - 720 = 474 of slack, half either side.
      expect(contentGutter(1194, maxWidth: 720, minPadding: 32), 237);
    });

    test('the cap only bites once it beats the minimum', () {
      // 700 wide, 620 cap: 40 of slack is less than the 32 minimum… just.
      expect(contentGutter(700, maxWidth: 620, minPadding: 32), 40);
      expect(contentGutter(660, maxWidth: 620, minPadding: 32), 32);
    });
  });
}
