import 'package:flutter/material.dart';

import '../../../core/api/pluno_api.dart';
import '../../../shared/extensions/currency_extensions.dart';
import '../../create_trip/domain/plan_labels.dart';

/// How an itinerary reads on screen: icons for a stop's category, labels for
/// the leg into it, and the clock and date formats the designs use.
///
/// Shared by the plan editor (`/trips/:id/edit`) and the view plan page
/// (`/trips/:id`), which render the same days in different shapes. One copy,
/// because a leg described two ways would drift.

IconData categoryIcon(ActivityCategory category) => switch (category) {
      ActivityCategory.food => Icons.restaurant,
      ActivityCategory.hotel => Icons.hotel_outlined,
      ActivityCategory.transport => Icons.directions_bus_filled_outlined,
      ActivityCategory.sightseeing => Icons.photo_camera_outlined,
      ActivityCategory.activity => Icons.hiking,
      ActivityCategory.other => Icons.place_outlined,
    };

/// What a stop is, for a card that has no leg to describe instead — the first
/// stop of a day has nothing to travel from.
const categoryLabels = <ActivityCategory, String>{
  ActivityCategory.food: 'ร้านอาหาร',
  ActivityCategory.hotel: 'ที่พัก',
  ActivityCategory.transport: 'การเดินทาง',
  ActivityCategory.sightseeing: 'เที่ยวชม',
  ActivityCategory.activity: 'กิจกรรม',
  ActivityCategory.other: 'อื่น ๆ',
};

String categoryLabel(ActivityCategory category) => categoryLabels[category]!;

IconData travelTypeIcon(TravelType type) => switch (type) {
      TravelType.walk => Icons.directions_walk,
      TravelType.bicycle => Icons.directions_bike,
      TravelType.tukTuk => Icons.electric_rickshaw,
      TravelType.privateTransfer => Icons.local_taxi,
      TravelType.rentalCar => Icons.directions_car,
      TravelType.boat => Icons.directions_boat,
      TravelType.train => Icons.train,
      TravelType.airplane => Icons.flight,
      TravelType.other => Icons.more_horiz,
    };

IconData travelModeIcon(TravelMode mode) => switch (mode) {
      TravelMode.drive => Icons.directions_car,
      TravelMode.walk => Icons.directions_walk,
      TravelMode.bicycle => Icons.directions_bike,
      TravelMode.transit => Icons.directions_bus_filled_outlined,
    };

/// The traveller's own description of the leg wins over the server's measured
/// mode, the same order [legParts] reads them in.
IconData legIcon(Activity stop, TravelSegment? segment) {
  final planned = stop.travelFromPrevious?.type;
  if (planned != null) return travelTypeIcon(planned);
  if (segment != null) return travelModeIcon(segment.travelMode);
  return Icons.trending_flat;
}

/// The pieces of a leg description, most specific source first: what the
/// traveller wrote, then what the server measured.
List<String> legParts(
  Activity stop,
  TravelSegment? segment, {
  required bool withDistance,
  required bool withCost,
}) {
  final leg = stop.travelFromPrevious;
  return <String>[
    if (leg?.customType != null && leg!.customType!.isNotEmpty)
      leg.customType!
    else if (leg?.type != null)
      travelTypeLabels[leg!.type!]!
    else if (segment != null)
      travelModeLabels[segment.travelMode]!,
    if (leg?.durationMin != null)
      '${leg!.durationMin} นาที'
    else if (segment?.durationMinutes != null)
      '${segment!.durationMinutes} นาที',
    if (withDistance)
      if (leg?.distanceKm != null)
        '${trimZero(leg!.distanceKm!)} กม.'
      else if (segment?.distanceKilometers != null)
        '${trimZero(segment!.distanceKilometers!)} กม.',
    if (withCost && leg?.costAmount != null && leg!.costAmount! > 0)
      leg.costAmount!.asBaht,
  ];
}

/// "รถเช่า • 15 นาที • ฿3,500", for the rail on จัดแผน.
String legLabel(Activity stop, TravelSegment? segment) {
  final parts = legParts(stop, segment, withDistance: true, withCost: true);
  if (parts.isNotEmpty) return parts.join(' • ');
  // [Activity.travelNote] is the legacy pre-composed string; it is the last
  // thing to fall back on, not the first.
  return stop.travelNote ?? 'ยังไม่ได้ระบุการเดินทาง';
}

/// "รถเช่า • 15 นาที", for the chip on ทริปของฉัน, where cost has its own chip.
String legShortLabel(Activity stop, TravelSegment? segment) {
  final parts = legParts(stop, segment, withDistance: false, withCost: false);
  return parts.isEmpty ? 'ยังไม่ระบุ' : parts.join(' • ');
}

String trimZero(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

/// "08:30" as the design's "08:30 AM". The API sends 24-hour `HH:mm`.
String clockLabel(String time) {
  final parts = time.split(':');
  final hour = int.tryParse(parts.first);
  if (hour == null || parts.length < 2) return time;
  final suffix = hour < 12 ? 'AM' : 'PM';
  final display = hour % 12 == 0 ? 12 : hour % 12;
  return '${_two(display)}:${parts[1]} $suffix';
}

const _weekdayNames = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String slashDate(DateTime date) =>
    '${_two(date.day)}/${_two(date.month)}/${date.year}';

/// "Sat, 20 Aug". Empty when the trip has no dates to hang the day off.
String weekdayDate(DateTime? date) {
  if (date == null) return '';
  return '${_weekdayNames[date.weekday - 1]}, '
      '${date.day} ${_monthNames[date.month - 1]}';
}

String _two(int value) => value.toString().padLeft(2, '0');
