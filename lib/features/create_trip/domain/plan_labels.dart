import 'package:flutter/material.dart';
import '../../../core/api/pluno_api.dart';

/// Thai chip labels for the plan brief, shared by the create wizard (which
/// turns a tapped label back into an enum) and the plan editor (which turns a
/// stored enum back into a label).
///
/// One map per direction would drift, so the label maps below are the single
/// source of truth and the `*Label` helpers read them backwards.

/// Thai chip label to the wire enum `POST /trips` expects.
const styleByLabel = <String, TravelStyle>{
  'ทะเล': TravelStyle.beach,
  'ภูเขา': TravelStyle.mountain,
  'ธรรมชาติ': TravelStyle.nature,
  'คาเฟ่': TravelStyle.cafe,
  'เข้าถึงท้องถิ่น': TravelStyle.local,
  'วัฒนธรรม': TravelStyle.culture,
  'อาหาร': TravelStyle.food,
  'ไนท์ไลฟ์': TravelStyle.nightlife,
  'ช้อปปิ้ง': TravelStyle.shopping,
  'ผจญภัย': TravelStyle.adventure,
};

/// Only four of the six constraint chips have an enum. `อิสลาม` and
/// `มังสวิรัติ` are dietary, not accessibility, and the API would 400 on them
/// — they are carried in `specialNotes` instead of being thrown away.
const constraintByLabel = <String, TripConstraint>{
  'มีผู้สูงอายุ': TripConstraint.seniors,
  'ผู้ใช้รถเข็น': TripConstraint.wheelchair,
  'เดินเยอะไม่ได้': TripConstraint.limitedWalking,
  'มีเด็กเล็ก': TripConstraint.youngChildren,
};

const transportByLabel = <String, TransportMode>{
  'รถส่วนตัว': TransportMode.privateCar,
  'รถเช่า': TransportMode.rentalCar,
  'มอเตอร์ไซค์': TransportMode.motorbike,
  'รถสาธารณะ': TransportMode.publicTransit,
  'แนะนำให้หน่อย': TransportMode.recommend,
};

/// The pace chips keep their English names on the hero, matching the design.
const intensityLabels = <TripIntensity, String>{
  TripIntensity.slowLife: 'Slow Life',
  TripIntensity.chill: 'Chill',
  TripIntensity.balance: 'Balance',
  TripIntensity.active: 'Active',
  TripIntensity.hardcore: 'Hardcore',
};

String? styleLabel(TravelStyle style) => _reverse(styleByLabel, style);

String? constraintLabel(TripConstraint constraint) =>
    _reverse(constraintByLabel, constraint);

String? transportLabel(TransportMode mode) => _reverse(transportByLabel, mode);

String? _reverse<T>(Map<String, T> labels, T value) {
  for (final entry in labels.entries) {
    if (entry.value == value) return entry.key;
  }
  return null;
}

/// How a leg was travelled, as the plan editor labels it.
const travelTypeLabels = <TravelType, String>{
  TravelType.walk: 'เดิน',
  TravelType.bicycle: 'จักรยาน',
  TravelType.tukTuk: 'ตุ๊กตุ๊ก',
  TravelType.privateTransfer: 'รถรับส่งส่วนตัว',
  TravelType.rentalCar: 'รถเช่า',
  TravelType.boat: 'เรือ',
  TravelType.train: 'รถไฟ',
  TravelType.airplane: 'เครื่องบิน',
  TravelType.other: 'อื่น ๆ',
};

/// The routing mode the server measured, for a leg the traveller never
/// described themselves.
const travelModeLabels = <TravelMode, String>{
  TravelMode.drive: 'ขับรถ',
  TravelMode.walk: 'เดิน',
  TravelMode.bicycle: 'จักรยาน',
  TravelMode.transit: 'ขนส่งสาธารณะ',
};

/// The category chips on the แนะนำสถานที่ sheet. `null` is the "ทั้งหมด" chip,
/// which asks the server for every category at once.
const placeCategoryByLabel = <String, PlaceCategory?>{
  'ทั้งหมด': null,
  'แลนด์มาร์ค': PlaceCategory.attraction,
  'สถานที่เที่ยว': PlaceCategory.activity,
  'อาหาร': PlaceCategory.restaurant,
  'คาเฟ่': PlaceCategory.cafe,
  'ที่พัก': PlaceCategory.hotel,
  'ช้อปปิ้ง': PlaceCategory.shopping,
  'เดินทาง': PlaceCategory.transport,
};

/// The badge on a suggestion card. Falls back to the chip labels above.
String placeCategoryLabel(PlaceCategory? category) {
  if (category == null) return 'ทั่วไป';
  for (final entry in placeCategoryByLabel.entries) {
    if (entry.value == category) return entry.key;
  }
  return 'ทั่วไป';
}

/// The glyph each travel style wears, wherever it is offered — the plan
/// wizard's สไตล์การเที่ยว and the post composer's Trip Activity read the same
/// list, so they cannot drift apart.
IconData styleIcon(TravelStyle style) => switch (style) {
      TravelStyle.beach => Icons.beach_access_outlined,
      TravelStyle.mountain => Icons.terrain_outlined,
      TravelStyle.nature => Icons.eco_outlined,
      TravelStyle.cafe => Icons.coffee_outlined,
      TravelStyle.local => Icons.storefront_outlined,
      TravelStyle.culture => Icons.museum_outlined,
      TravelStyle.food => Icons.restaurant_outlined,
      TravelStyle.nightlife => Icons.local_bar_outlined,
      TravelStyle.shopping => Icons.shopping_bag_outlined,
      TravelStyle.adventure => Icons.hiking_outlined,
    };

/// What each spending category is called in the สรุปงบ tab, and the colour it
/// carries there — the proportion bar, its legend and the item rows all read
/// this, so a category cannot be one colour in one place and another below.
String expenseCategoryLabel(ExpenseCategory category) => switch (category) {
      ExpenseCategory.hotel => 'ค่าที่พัก',
      ExpenseCategory.activity => 'ค่ากิจกรรม',
      ExpenseCategory.food => 'ค่าอาหาร / ของกิน',
      ExpenseCategory.shopping => 'ช้อปปิ้ง',
      ExpenseCategory.transport => 'ค่าเดินทาง',
      ExpenseCategory.sightseeing => 'ค่าเข้าชมสถานที่',
      ExpenseCategory.fuel => 'ค่าน้ำมัน',
      ExpenseCategory.other => 'อื่นๆ',
    };

Color expenseCategoryColor(ExpenseCategory category) => switch (category) {
      ExpenseCategory.hotel => const Color(0xFF7C5CFC),
      ExpenseCategory.activity => const Color(0xFFF4553C),
      ExpenseCategory.food => const Color(0xFFF7B44C),
      ExpenseCategory.shopping => const Color(0xFF21A366),
      ExpenseCategory.transport => const Color(0xFF4A90E2),
      ExpenseCategory.sightseeing => const Color(0xFF12B5B0),
      ExpenseCategory.fuel => const Color(0xFF8D6E63),
      ExpenseCategory.other => const Color(0xFF9A9A95),
    };

IconData expenseCategoryIcon(ExpenseCategory category) => switch (category) {
      ExpenseCategory.hotel => Icons.bed_outlined,
      ExpenseCategory.activity => Icons.hiking_outlined,
      ExpenseCategory.food => Icons.restaurant_outlined,
      ExpenseCategory.shopping => Icons.shopping_bag_outlined,
      ExpenseCategory.transport => Icons.directions_car_outlined,
      ExpenseCategory.sightseeing => Icons.photo_camera_outlined,
      ExpenseCategory.fuel => Icons.local_gas_station_outlined,
      ExpenseCategory.other => Icons.more_horiz,
    };
