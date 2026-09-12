import 'dart:math';
import 'dart:typed_data';
import 'package:exif/exif.dart';

class TripPhoto {
  const TripPhoto(this.path,
      {this.takenAt, this.captureTimestamp, this.latitude, this.longitude});
  final String path;
  final DateTime? takenAt;
  final String? captureTimestamp;
  final double? latitude, longitude;
  bool get hasLocation => latitude != null && longitude != null;
}

/// Only capture metadata is used. Filesystem modification times are not read.
Future<TripPhoto> readTripPhoto(Uint8List bytes, String path) async {
  try {
    final tags = await readExifFromBytes(bytes);
    final raw = tags['EXIF DateTimeOriginal']?.printable;
    DateTime? date;
    final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$')
        .firstMatch(raw ?? '');
    if (match != null) {
      final n = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
      final candidate = DateTime(n[0], n[1], n[2], n[3], n[4], n[5]);
      if (candidate.year == n[0] &&
          candidate.month == n[1] &&
          candidate.day == n[2] &&
          candidate.hour == n[3] &&
          candidate.minute == n[4] &&
          candidate.second == n[5]) date = candidate;
    }
    double? coordinate(String axis, double limit) {
      try {
        final value = tags['GPS GPS$axis']?.printable ?? '';
        final parts = value
            .replaceAll(RegExp(r'[\[\],]'), ' ')
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toList();
        if (parts.length != 3) return null;
        double number(String s) {
          final fraction = s.split('/');
          return double.parse(fraction[0]) /
              (fraction.length == 2 ? double.parse(fraction[1]) : 1);
        }

        final d = number(parts[0]), m = number(parts[1]), s = number(parts[2]);
        final ref = tags['GPS GPS${axis}Ref']?.printable;
        if (!(axis == 'Latitude' ? ['N', 'S'] : ['E', 'W']).contains(ref))
          return null;
        final result =
            (d + m / 60 + s / 3600) * (ref == 'S' || ref == 'W' ? -1 : 1);
        return result.isFinite &&
                result.abs() <= limit &&
                d >= 0 &&
                m >= 0 &&
                m < 60 &&
                s >= 0 &&
                s < 60
            ? result
            : null;
      } catch (_) {
        return null;
      }
    }

    final offset = tags['EXIF OffsetTimeOriginal']?.printable;
    final timestamp = date != null &&
            offset != null &&
            RegExp(r'^[+-](0\d|1[0-4]):[0-5]\d$').hasMatch(offset)
        ? '${date.toIso8601String()}$offset'
        : null;
    return TripPhoto(path,
        captureTimestamp: timestamp,
        takenAt: date,
        latitude: coordinate('Latitude', 90),
        longitude: coordinate('Longitude', 180));
  } catch (_) {
    return TripPhoto(path);
  }
}

class TripPhotoGrouper {
  const TripPhotoGrouper(
      {this.gap = const Duration(hours: 3),
      this.distanceKm = 2,
      this.maxPhotos = 20});
  final Duration gap;
  final double distanceKm;
  final int maxPhotos;

  List<List<TripPhoto>> group(List<TripPhoto> selected) {
    // Unknown metadata is an anchor: retain selection order and sort only
    // contiguous runs with both capture time and coordinates.
    final ordered = <TripPhoto>[];
    final run = <TripPhoto>[];
    void flush() {
      final indexed = run.asMap().entries.toList()
        ..sort((a, b) {
          final comparison = a.value.takenAt!.compareTo(b.value.takenAt!);
          return comparison == 0 ? a.key.compareTo(b.key) : comparison;
        });
      ordered.addAll(indexed.map((e) => e.value));
      run.clear();
    }

    for (final photo in selected) {
      if (photo.takenAt == null || !photo.hasLocation) {
        flush();
        ordered.add(photo);
      } else {
        run.add(photo);
      }
    }
    flush();
    final groups = <List<TripPhoto>>[];
    for (final photo in ordered) {
      var split = groups.isEmpty || groups.last.length >= maxPhotos;
      if (!split) {
        final previous = groups.last.last;
        final a = previous.takenAt, b = photo.takenAt;
        if (a != null && b != null) {
          split = a.year != b.year ||
              a.month != b.month ||
              a.day != b.day ||
              b.difference(a).abs() > gap;
        }
        if (previous.hasLocation && photo.hasLocation)
          split |= _distance(previous, photo) > distanceKm;
      }
      if (split) groups.add([]);
      groups.last.add(photo);
    }
    return groups;
  }

  double _distance(TripPhoto a, TripPhoto b) {
    double radians(double n) => n * pi / 180;
    final lat = radians(b.latitude! - a.latitude!);
    final lon = radians(b.longitude! - a.longitude!);
    final h = pow(sin(lat / 2), 2) +
        cos(radians(a.latitude!)) *
            cos(radians(b.latitude!)) *
            pow(sin(lon / 2), 2);
    return 6371 * 2 * asin(sqrt(h.clamp(0, 1)));
  }
}
