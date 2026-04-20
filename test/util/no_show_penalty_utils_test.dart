import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/util/date_time/util_no_show_penalty.dart';

void main() {
  group('addOneCalendarMonth', () {
    test('clamps to the last day of shorter months', () {
      expect(
        addOneCalendarMonth(DateTime(2026, 1, 31, 9, 15)),
        DateTime(2026, 2, 28, 9, 15),
      );
    });
  });

  group('resolveNoShowPenaltyState', () {
    test('applies a one month block after the third no-show', () {
      final state = resolveNoShowPenaltyState(
        currentNoShowCount: 2,
        currentPenaltyUntil: null,
        newlyRecordedNoShowTimes: [DateTime(2026, 4, 18, 11)],
        now: DateTime(2026, 4, 19, 9),
      );

      expect(state.noShowCount, 0);
      expect(state.penaltyUntil, DateTime(2026, 5, 18, 11));
      expect(state.isBlocked(now: DateTime(2026, 4, 19, 9)), isTrue);
    });

    test('preserves an active block without stacking another one', () {
      final state = resolveNoShowPenaltyState(
        currentNoShowCount: 0,
        currentPenaltyUntil: DateTime(2026, 5, 20),
        newlyRecordedNoShowTimes: [
          DateTime(2026, 4, 21, 10),
          DateTime(2026, 4, 22, 10),
        ],
        now: DateTime(2026, 4, 25),
      );

      expect(state.noShowCount, 0);
      expect(state.penaltyUntil, DateTime(2026, 5, 20));
    });

    test('clears expired blocks and keeps counting fresh strikes', () {
      final state = resolveNoShowPenaltyState(
        currentNoShowCount: 1,
        currentPenaltyUntil: DateTime(2026, 3, 1),
        newlyRecordedNoShowTimes: [DateTime(2026, 4, 18, 11)],
        now: DateTime(2026, 4, 19, 9),
      );

      expect(state.noShowCount, 2);
      expect(state.penaltyUntil, isNull);
      expect(state.isBlocked(now: DateTime(2026, 4, 19, 9)), isFalse);
    });
  });
}
