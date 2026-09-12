import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/features/create_post/domain/services/trip_photo_grouper.dart';

void main() {
  TripPhoto photo(String id, int hour, {double lat = 13}) => TripPhoto(id,
      takenAt: DateTime(2026, 9, 12, hour), latitude: lat, longitude: 100);
  const grouper = TripPhotoGrouper();
  test('sorts metadata runs; splits time, day and distance', () {
    expect(
        grouper
            .group([
              photo('b', 10),
              photo('a', 9),
              photo('c', 15),
              photo('d', 16, lat: 14)
            ])
            .map((g) => g.map((p) => p.path).toList())
            .toList(),
        [
          ['a', 'b'],
          ['c'],
          ['d']
        ]);
    expect(
        grouper.group([
          photo('a', 23),
          TripPhoto('b',
              takenAt: DateTime(2026, 9, 13), latitude: 13, longitude: 100)
        ]),
        hasLength(2));
  });
  test('unknown metadata anchors selection order and duplicates survive', () {
    final input = [
      photo('b', 10),
      const TripPhoto('unknown'),
      photo('a', 9),
      photo('a', 9)
    ];
    expect(grouper.group(input).expand((g) => g).map((p) => p.path),
        ['b', 'unknown', 'a', 'a']);
    final noGps = [
      TripPhoto('b', takenAt: DateTime(2026, 9, 12, 10)),
      TripPhoto('a', takenAt: DateTime(2026, 9, 12, 9))
    ];
    expect(
        grouper.group(noGps).expand((g) => g).map((p) => p.path), ['b', 'a']);
  });
  test('splits at API capacity without losing photos', () {
    final result = grouper.group(List.generate(41, (i) => TripPhoto('$i')));
    expect(result.map((g) => g.length), [20, 20, 1]);
  });
  test(
      'reads capture time and signed GPS from EXIF, ignoring modification time',
      () async {
    final bytes = Uint8List(178);
    final data = ByteData.sublistView(bytes);
    void u16(int offset, int value) =>
        data.setUint16(offset, value, Endian.little);
    void u32(int offset, int value) =>
        data.setUint32(offset, value, Endian.little);
    void tag(int offset, int id, int type, int count, int value) {
      u16(offset, id);
      u16(offset + 2, type);
      u32(offset + 4, count);
      u32(offset + 8, value);
    }

    bytes[0] = bytes[1] = 73;
    u16(2, 42);
    u32(4, 8);
    u16(8, 2);
    tag(10, 0x8769, 4, 1, 38);
    tag(22, 0x8825, 4, 1, 56);
    u16(38, 1);
    tag(40, 0x9003, 2, 20, 110);
    u16(56, 4);
    tag(58, 1, 2, 2, 83); // South.
    tag(70, 2, 5, 3, 130);
    tag(82, 3, 2, 2, 69); // East.
    tag(94, 4, 5, 3, 154);
    bytes.setRange(110, 129, '2026:09:12 10:30:00'.codeUnits);
    for (final offset in [130, 138, 146, 154, 162, 170]) {
      u32(offset + 4, 1);
    }
    u32(130, 13);
    u32(138, 30);
    u32(154, 100);
    u32(162, 15);
    final photo = await readTripPhoto(bytes, 'capture.tiff');
    expect(photo.takenAt, DateTime(2026, 9, 12, 10, 30));
    expect(photo.latitude, -13.5);
    expect(photo.longitude, 100.25);
    // TIFF Image DateTime is modification time and must not be used.
    tag(40, 0x0132, 2, 20, 110);
    expect((await readTripPhoto(bytes, 'modified.tiff')).takenAt, isNull);
  });

  test('unreadable metadata retains the photo', () async {
    final result = await readTripPhoto(Uint8List.fromList([1, 2, 3]), 'broken');
    expect(result.path, 'broken');
    expect(result.takenAt, isNull);
    expect(result.hasLocation, isFalse);
  });
}
