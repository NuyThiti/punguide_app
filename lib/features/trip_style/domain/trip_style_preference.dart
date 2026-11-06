import 'package:flutter/foundation.dart';

/// What the traveller answered on สไตล์เที่ยวของฉัน: the kinds of trip they
/// want offered, and the limits any trip has to respect.
///
/// Both lists hold Thai chip labels rather than wire enums — the same strings
/// [styleByLabel] and [constraintByLabel] are keyed by — because "+ เพิ่ม"
/// lets a traveller type something no enum covers. Turning a label into an
/// enum is [TripFilter.toFeedQuery]'s job, and it is the only place that
/// knows which labels have one.
@immutable
class TripStylePreference {
  const TripStylePreference({
    this.styles = const <String>[],
    this.constraints = const <String>[],
  });

  factory TripStylePreference.fromJson(Map<String, dynamic> json) =>
      TripStylePreference(
        styles: _labels(json['styles']),
        constraints: _labels(json['constraints']),
      );

  /// Answered, and nothing picked — what ข้ามไปก่อน leaves behind. Distinct
  /// from a null preference, which means the question has never been put.
  static const skipped = TripStylePreference();

  final List<String> styles;
  final List<String> constraints;

  /// What the foot of the page counts: "4 รายการ" across both sections.
  int get count => styles.length + constraints.length;

  bool get isEmpty => count == 0;

  TripStylePreference copyWith({
    List<String>? styles,
    List<String>? constraints,
  }) =>
      TripStylePreference(
        styles: styles ?? this.styles,
        constraints: constraints ?? this.constraints,
      );

  /// Adds [label] to a list, or takes it out when it is already there.
  TripStylePreference toggleStyle(String label) =>
      copyWith(styles: _toggled(styles, label));

  TripStylePreference toggleConstraint(String label) =>
      copyWith(constraints: _toggled(constraints, label));

  Map<String, dynamic> toJson() => <String, dynamic>{
        'styles': styles,
        'constraints': constraints,
      };

  static List<String> _toggled(List<String> list, String label) {
    final next = List<String>.of(list);
    if (!next.remove(label)) next.add(label);
    return List<String>.unmodifiable(next);
  }

  /// Anything that is not a list of strings reads as nothing chosen: a half
  /// understood answer would quietly narrow the board for good.
  static List<String> _labels(Object? value) {
    if (value is! List) return const <String>[];
    return List<String>.unmodifiable(value.whereType<String>());
  }
}
