import 'dart:math';

const int noShowPenaltyThreshold = 3;

class NoShowPenaltyState {
  final int noShowCount;
  final DateTime? penaltyUntil;

  const NoShowPenaltyState({
    required this.noShowCount,
    required this.penaltyUntil,
  });

  bool isBlocked({DateTime? now}) {
    return isNoShowPenaltyActive(penaltyUntil, now: now);
  }
}

NoShowPenaltyState resolveNoShowPenaltyState({
  required int currentNoShowCount,
  required DateTime? currentPenaltyUntil,
  required Iterable<DateTime> newlyRecordedNoShowTimes,
  DateTime? now,
}) {
  final referenceNow = now ?? DateTime.now();
  final normalizedCount = max(0, currentNoShowCount);
  var normalizedPenaltyUntil = currentPenaltyUntil;
  if (!isNoShowPenaltyActive(normalizedPenaltyUntil, now: referenceNow)) {
    normalizedPenaltyUntil = null;
  }

  if (normalizedPenaltyUntil != null) {
    return NoShowPenaltyState(
      noShowCount: normalizedCount,
      penaltyUntil: normalizedPenaltyUntil,
    );
  }

  var nextCount = normalizedCount;
  DateTime? nextPenaltyUntil;
  var thresholdTriggered = false;
  final sortedNoShowTimes = newlyRecordedNoShowTimes.toList()
    ..sort((left, right) => left.compareTo(right));

  for (final noShowTime in sortedNoShowTimes) {
    if (thresholdTriggered) {
      break;
    }

    nextCount += 1;
    if (nextCount >= noShowPenaltyThreshold) {
      final candidatePenaltyUntil = addOneCalendarMonth(noShowTime);
      nextPenaltyUntil = candidatePenaltyUntil.isAfter(referenceNow)
          ? candidatePenaltyUntil
          : null;
      nextCount = 0;
      thresholdTriggered = true;
    }
  }

  return NoShowPenaltyState(
    noShowCount: nextCount,
    penaltyUntil: nextPenaltyUntil,
  );
}

bool isNoShowPenaltyActive(DateTime? penaltyUntil, {DateTime? now}) {
  final referenceNow = now ?? DateTime.now();
  return penaltyUntil != null && penaltyUntil.isAfter(referenceNow);
}

DateTime addOneCalendarMonth(DateTime value) {
  final nextMonth = value.month == 12 ? 1 : value.month + 1;
  final nextYear = value.month == 12 ? value.year + 1 : value.year;
  final nextDay = min(value.day, _daysInMonth(nextYear, nextMonth));

  if (value.isUtc) {
    return DateTime.utc(
      nextYear,
      nextMonth,
      nextDay,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  return DateTime(
    nextYear,
    nextMonth,
    nextDay,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

int _daysInMonth(int year, int month) {
  final startOfNextMonth = month == 12
      ? DateTime(year + 1, 1, 1)
      : DateTime(year, month + 1, 1);
  return startOfNextMonth.subtract(const Duration(days: 1)).day;
}
