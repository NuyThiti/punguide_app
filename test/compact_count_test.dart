import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/shared/formatting/compact_count.dart';

void main() {
  test('counts abbreviate past a thousand', () {
    expect(compactCount(0), '0');
    expect(compactCount(999), '999');
    expect(compactCount(1000), '1K');
    expect(compactCount(1111), '1.1K');
    expect(compactCount(1721), '1.7K');
    // Floors rather than rounds: 1999 is not yet 2K.
    expect(compactCount(1999), '1.9K');
    expect(compactCount(12345), '12.3K');
    expect(compactCount(999999), '999.9K');
    expect(compactCount(1000000), '1M');
    expect(compactCount(2500000), '2.5M');
  });
}
