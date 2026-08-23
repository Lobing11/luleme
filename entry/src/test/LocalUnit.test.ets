/**
 * 鹿了么 - 统计逻辑单元测试（hypium）
 *
 * 覆盖 StatsCalculator 与 CalendarUtil 的纯函数。
 */
import { describe, it, expect } from '@ohos/hypium';
import { Record } from '../main/ets/model/RecordModel';
import {
  currentStreak,
  daysSinceLast,
  intervalStats,
  monthCounts,
  countInMonth,
  countToday,
  recordsOnDay,
  countByDayOfMonth,
  recordDays,
  startOfDay
} from '../main/ets/logic/StatsCalculator';
import { buildMonthGrid, shiftMonth, weekdayHeaders } from '../main/ets/logic/CalendarUtil';

function rec(ts: number): Record {
  return { id: 0, timestamp: ts, mood: 2, note: '' };
}

function at(y: number, m: number, d: number, h: number = 10): number {
  return new Date(y, m, d, h, 0, 0, 0).getTime();
}

export default function lulemeUnitTest() {
  describe('currentStreak', () => {
    it('today_and_yesterday_recorded', 0, () => {
      const now = at(2025, 5, 15);
      const records = [rec(at(2025, 5, 15, 9)), rec(at(2025, 5, 14, 22)), rec(at(2025, 5, 12, 8))];
      expect(currentStreak(records, now)).assertEqual(2);
    });
    it('today_missing_but_yesterday_and_before', 0, () => {
      const now = at(2025, 5, 15);
      const records = [rec(at(2025, 5, 14, 20)), rec(at(2025, 5, 13, 8))];
      expect(currentStreak(records, now)).assertEqual(2);
    });
    it('no_recent_records', 0, () => {
      const now = at(2025, 5, 15);
      const records = [rec(at(2025, 5, 10))];
      expect(currentStreak(records, now)).assertEqual(0);
    });
    it('empty_records', 0, () => {
      expect(currentStreak([], at(2025, 5, 15))).assertEqual(0);
    });
  });

  describe('daysSinceLast', () => {
    it('gap_two_days', 0, () => {
      const now = at(2025, 5, 15);
      const records = [rec(at(2025, 5, 13))];
      expect(daysSinceLast(records, now)).assertEqual(2);
    });
    it('recorded_today', 0, () => {
      const now = at(2025, 5, 15);
      const records = [rec(at(2025, 5, 15, 8))];
      expect(daysSinceLast(records, now)).assertEqual(0);
    });
    it('empty_records_returns_null', 0, () => {
      expect(daysSinceLast([], at(2025, 5, 15))).assertNull();
    });
  });

  describe('intervalStats', () => {
    it('gaps_of_4_and_5', 0, () => {
      const now = at(2025, 6, 15);
      const records = [rec(at(2025, 6, 1)), rec(at(2025, 6, 5)), rec(at(2025, 6, 10))];
      const s = intervalStats(records, now);
      expect(s.max).assertEqual(5);
      expect(s.avg).assertEqual(4.5);
      expect(s.count).assertEqual(2);
    });
    it('single_record_zero_gaps', 0, () => {
      const records = [rec(at(2025, 6, 1))];
      const s = intervalStats(records, at(2025, 6, 15));
      expect(s.max).assertEqual(0);
      expect(s.count).assertEqual(0);
    });
  });

  describe('monthCounts', () => {
    it('six_month_window', 0, () => {
      const now = at(2025, 5, 15); // 2025年6月
      const records = [
        rec(at(2025, 6, 2)),
        rec(at(2025, 6, 10)),
        rec(at(2025, 5, 1)),
        rec(at(2025, 1, 20)),
        rec(at(2025, 2, 3))
      ];
      const counts = monthCounts(records, now, 6);
      expect(counts.length).assertEqual(6);
      // 第一个月是 2025年1月，第二个月 2025年2月，最后一个月 2025年6月
      expect(counts[0].month).assertEqual(0);
      expect(counts[0].year).assertEqual(2025);
      expect(counts[1].count).assertEqual(1);
      expect(counts[5].year).assertEqual(2025);
      expect(counts[5].month).assertEqual(5);
      expect(counts[5].count).assertEqual(2);
      expect(counts[4].count).assertEqual(1);
    });
    it('cross_year_boundary', 0, () => {
      const now = at(2025, 0, 15); // 2025年1月
      const records = [rec(at(2024, 11, 5))];
      const counts = monthCounts(records, now, 3);
      expect(counts[0].year).assertEqual(2024);
      expect(counts[0].month).assertEqual(10);
      expect(counts[0].count).assertEqual(0);
      expect(counts[1].month).assertEqual(11);
      expect(counts[1].count).assertEqual(1);
    });
  });

  describe('countInMonth', () => {
    it('counts_only_within_month', 0, () => {
      const records = [rec(at(2025, 5, 30)), rec(at(2025, 6, 1)), rec(at(2025, 6, 30, 23)), rec(at(2025, 7, 1))];
      expect(countInMonth(records, 2025, 5)).assertEqual(2);
      expect(countInMonth(records, 2025, 4)).assertEqual(0);
    });
  });

  describe('countToday', () => {
    it('counts_only_today', 0, () => {
      const now = at(2025, 6, 15, 18);
      const records = [rec(at(2025, 6, 15, 8)), rec(at(2025, 6, 15, 23)), rec(at(2025, 6, 14, 23))];
      expect(countToday(records, now)).assertEqual(2);
    });
  });

  describe('recordsOnDay', () => {
    it('filters_by_day', 0, () => {
      const records = [rec(at(2025, 6, 15, 8)), rec(at(2025, 6, 15, 20)), rec(at(2025, 6, 16, 1))];
      const day = startOfDay(at(2025, 6, 15));
      const list = recordsOnDay(records, day);
      expect(list.length).assertEqual(2);
      expect(list[0].timestamp).assertLessThan(list[1].timestamp);
    });
  });

  describe('countByDayOfMonth', () => {
    it('maps_day_to_count', 0, () => {
      const records = [rec(at(2025, 6, 3, 9)), rec(at(2025, 6, 3, 21)), rec(at(2025, 6, 15))];
      const map = countByDayOfMonth(records, 2025, 5);
      expect(map.get(3)).assertEqual(2);
      expect(map.get(15)).assertEqual(1);
      expect(map.get(10)).assertUndefined();
    });
  });

  describe('recordDays', () => {
    it('dedupes_and_sorts', 0, () => {
      const records = [rec(at(2025, 6, 15, 8)), rec(at(2025, 6, 14, 9)), rec(at(2025, 6, 15, 22))];
      const days = recordDays(records);
      expect(days.length).assertEqual(2);
      expect(days[0]).assertLessThan(days[1]);
    });
  });

  describe('buildMonthGrid', () => {
    it('june_2025_starts_on_sunday', 0, () => {
      // 2025-06-01 是星期日，getDay() = 0
      const grid = buildMonthGrid(2025, 5);
      expect(grid.length % 7).assertEqual(0);
      expect(grid[0]).assertEqual(1);
      expect(grid.length).assertEqual(35); // 30 天 + 0 前导 + 5 补齐
    });
    it('february_2024_leap_year', 0, () => {
      const grid = buildMonthGrid(2024, 1);
      let days = 0;
      for (let i = 0; i < grid.length; i++) {
        if (grid[i] !== null) {
          days++;
        }
      }
      expect(days).assertEqual(29);
      expect(grid.length % 7).assertEqual(0);
    });
    it('weekday_headers', 0, () => {
      const headers = weekdayHeaders();
      expect(headers.length).assertEqual(7);
      expect(headers[0]).assertEqual('日');
      expect(headers[6]).assertEqual('六');
    });
  });

  describe('shiftMonth', () => {
    it('backward_cross_year', 0, () => {
      const m = shiftMonth(2025, 0, -1);
      expect(m.year).assertEqual(2024);
      expect(m.month).assertEqual(11);
    });
    it('forward_cross_year', 0, () => {
      const m = shiftMonth(2025, 11, 1);
      expect(m.year).assertEqual(2026);
      expect(m.month).assertEqual(0);
    });
  });
}
