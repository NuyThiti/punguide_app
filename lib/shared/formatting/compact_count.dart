/// "1,111" as the design's "1.1K".
///
/// Counts on a post run into the thousands and the chips they sit in are
/// narrow, so anything past a thousand is abbreviated rather than grouped.
/// A round figure drops its decimal: 1000 reads "1K", not "1.0K".
String compactCount(int value) {
  final sign = value < 0 ? '-' : '';
  final n = value.abs();

  if (n < 1000) return '$sign$n';
  if (n < 1000000) return '$sign${_trim(n / 1000)}K';
  return '$sign${_trim(n / 1000000)}M';
}

/// One decimal, and none at all when it would be a zero.
String _trim(double value) {
  final one = (value * 10).floor() / 10;
  return one == one.roundToDouble()
      ? one.round().toString()
      : one.toStringAsFixed(1);
}
