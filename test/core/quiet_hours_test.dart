import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/features/privacy_settings/domain/quiet_hours.dart';

void main() {
  DateTime at(int h, [int m = 0]) => DateTime(2026, 1, 15, h, m);
  const night = QuietHours(enabled: true);

  test('disabled or empty windows are never quiet', () {
    expect(const QuietHours().contains(at(23)), isFalse);
    expect(
      const QuietHours(
        enabled: true,
        startMin: 600,
        endMin: 600,
      ).contains(at(10)),
      isFalse,
    );
  });

  test('default 22:00-07:00 crosses midnight', () {
    expect(night.contains(at(22)), isTrue);
    expect(night.contains(at(23, 59)), isTrue);
    expect(night.contains(at(0)), isTrue);
    expect(night.contains(at(6, 59)), isTrue);
    expect(night.contains(at(7)), isFalse);
    expect(night.contains(at(12)), isFalse);
    expect(night.contains(at(21, 59)), isFalse);
  });

  test('same-day window is end-exclusive', () {
    const lunch = QuietHours(enabled: true, startMin: 780, endMin: 840);
    expect(lunch.contains(at(13)), isTrue);
    expect(lunch.contains(at(13, 59)), isTrue);
    expect(lunch.contains(at(14)), isFalse);
    expect(lunch.contains(at(12, 59)), isFalse);
  });

  test('validMinute', () {
    expect(QuietHours.validMinute(0), isTrue);
    expect(QuietHours.validMinute(1439), isTrue);
    expect(QuietHours.validMinute(1440), isFalse);
    expect(QuietHours.validMinute(-1), isFalse);
    expect(QuietHours.validMinute('9'), isFalse);
  });
}
