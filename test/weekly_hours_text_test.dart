import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/shared/formatting/spot_detail_text.dart';

List<String> _week(List<String> hours) => [
      for (var i = 0; i < 7; i++)
        '${['วันจันทร์', 'วันอังคาร', 'วันพุธ', 'วันพฤหัสบดี', 'วันศุกร์', 'วันเสาร์', 'วันอาทิตย์'][i]}: ${hours[i]}',
    ];

void main() {
  test('a whole week on the same hours is one run', () {
    expect(
      weeklyHoursText(_week(List.filled(7, '6:00–14:30'))),
      'จ - อา : 06.00 - 14.30 น.',
    );
  });

  test('weekdays and the weekend split into two runs', () {
    expect(
      weeklyHoursText(_week([
        ...List.filled(5, '09:00–18:00'),
        ...List.filled(2, '10:00–16:00'),
      ])),
      'จ - ศ : 09.00 - 18.00 น. · ส - อา : 10.00 - 16.00 น.',
    );
  });

  test('a closed day is left out, not guessed at', () {
    expect(
      weeklyHoursText(_week([
        ...List.filled(6, '09:00–18:00'),
        'ปิดทำการ',
      ])),
      'จ - ส : 09.00 - 18.00 น.',
    );
  });

  test('a lone day prints on its own', () {
    expect(
      weeklyHoursText(_week([
        'ปิดทำการ',
        ...List.filled(5, 'ปิดทำการ'),
        '08:00–12:00',
      ])),
      'อา : 08.00 - 12.00 น.',
    );
  });

  test("the writer's hours only borrow the days Google agrees on", () {
    final week = _week([
      ...List.filled(5, '06:00–14:30'),
      ...List.filled(2, '08:00–15:00'),
    ]);
    expect(
      weeklyHoursText(week, only: ('06:00', '14:30')),
      'จ - ศ : 06.00 - 14.30 น.',
    );
    // Hours Google never mentions earn no days at all.
    expect(weeklyHoursText(week, only: ('07:00', '20:00')), isNull);
  });

  test('anything but the standard seven lines is refused', () {
    expect(weeklyHoursText(const []), isNull);
    expect(weeklyHoursText(const ['วันจันทร์: 9:00–20:00']), isNull);
  });
}
