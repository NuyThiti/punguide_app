import 'package:flutter/widgets.dart';

/// The window size classes the layouts distinguish, at Material's own
/// breakpoints: a phone, a large phone or small tablet, a tablet.
///
/// Most of the app's screens do not adapt at all — they letterbox the phone
/// layout into a 430px column via `AppFrame`. This is for the ones that do.
enum ScreenClass {
  /// A phone in portrait.
  compact,

  /// A large phone in landscape, or a small tablet.
  medium,

  /// A tablet.
  expanded;

  static const mediumMinWidth = 600.0;
  static const expandedMinWidth = 840.0;

  static ScreenClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static ScreenClass fromWidth(double width) => width >= expandedMinWidth
      ? ScreenClass.expanded
      : width >= mediumMinWidth
          ? ScreenClass.medium
          : ScreenClass.compact;

  bool get isCompact => this == ScreenClass.compact;

  /// The value for this class, falling back to the next class down when one is
  /// left out — so a layout names only the sizes it actually changes.
  T pick<T>({required T compact, T? medium, T? expanded}) => switch (this) {
        ScreenClass.compact => compact,
        ScreenClass.medium => medium ?? compact,
        ScreenClass.expanded => expanded ?? medium ?? compact,
      };
}

/// Side padding that holds a column of content to [maxWidth] and centres it,
/// never tightening past [minPadding].
///
/// Padding rather than a `Center` + `ConstrainedBox` so a sliver list can use
/// it without wrapping every child.
double contentGutter(
  double screenWidth, {
  required double maxWidth,
  required double minPadding,
}) {
  final slack = (screenWidth - maxWidth) / 2;
  return slack > minPadding ? slack : minPadding;
}
