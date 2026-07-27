import '../../../services/cow_limit_order_signing.dart';

enum LimitExpiryOption {
  minutes15,
  hour1,
  hours4,
  hours24,
  days7,
  never,
  custom,
}

int resolveLimitExpirySeconds({
  required LimitExpiryOption option,
  DateTime? customDate,
  DateTime? now,
}) {
  final resolvedNow = now ?? DateTime.now();
  final target = switch (option) {
    LimitExpiryOption.minutes15 => resolvedNow.add(const Duration(minutes: 15)),
    LimitExpiryOption.hour1 => resolvedNow.add(const Duration(hours: 1)),
    LimitExpiryOption.hours4 => resolvedNow.add(const Duration(hours: 4)),
    LimitExpiryOption.hours24 => resolvedNow.add(const Duration(hours: 24)),
    LimitExpiryOption.days7 => resolvedNow.add(const Duration(days: 7)),
    LimitExpiryOption.never => null,
    LimitExpiryOption.custom => _endOfDay(
      customDate ?? resolvedNow.add(const Duration(days: 1)),
    ),
  };
  return target == null
      ? resolveCowNeverValidTo(now: resolvedNow)
      : target.millisecondsSinceEpoch ~/ 1000;
}

int resolveOpenOceanLimitExpiryMs({
  required LimitExpiryOption option,
  DateTime? customDate,
  DateTime? now,
}) {
  final resolvedNow = now ?? DateTime.now();
  final targetSeconds = resolveLimitExpirySeconds(
    option: option,
    customDate: customDate,
    now: resolvedNow,
  );
  final nowSeconds = resolvedNow.millisecondsSinceEpoch ~/ 1000;
  final durationSeconds = (targetSeconds - nowSeconds)
      .clamp(10 * 60, 365 * 24 * 60 * 60)
      .toInt();
  return durationSeconds * 1000;
}

String limitExpiryLabel(LimitExpiryOption option, {DateTime? customDate}) =>
    switch (option) {
      LimitExpiryOption.minutes15 => '15M',
      LimitExpiryOption.hour1 => '1H',
      LimitExpiryOption.hours4 => '4H',
      LimitExpiryOption.hours24 => '24H',
      LimitExpiryOption.days7 => '7D',
      LimitExpiryOption.never => 'Never',
      LimitExpiryOption.custom =>
        customDate == null
            ? 'Custom'
            : '${customDate.day}/${customDate.month}/${customDate.year}',
    };

DateTime _endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59);
