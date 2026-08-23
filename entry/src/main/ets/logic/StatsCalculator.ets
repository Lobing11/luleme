/**
 * 鹿了么 - 统计计算（纯函数，无 IO，可单元测试）
 *
 * 所有函数都不依赖 UI / 数据库 / 系统时间以外的状态，
 * 「现在」一律由调用方传入，保证可测性与结果一致性。
 */
import { Record } from '../model/RecordModel';

const DAY_MS: number = 24 * 60 * 60 * 1000;

/** 某毫秒时间戳所在日的零点（本地时区） */
export function startOfDay(ms: number): number {
  const d = new Date(ms);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

/** 某月的第一天零点；month 为 0-11 */
export function monthStart(year: number, month: number): number {
  const d = new Date(year, month, 1);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

/** 某月最后一天 24:00（即下月第一天零点）；month 为 0-11 */
export function monthEndExclusive(year: number, month: number): number {
  const d = new Date(year, month + 1, 1);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

/** 按日去重后的记录日列表（升序，值为当日零点毫秒） */
export function recordDays(records: Record[]): number[] {
  const set = new Set<number>();
  for (let i = 0; i < records.length; i++) {
    set.add(startOfDay(records[i].timestamp));
  }
  const days: number[] = [];
  set.forEach((v) => {
    days.push(v);
  });
  days.sort((a, b) => a - b);
  return days;
}

/**
 * 当前连续天数：从今天（若今天无记录则从昨天）向前数，连续有记录的天数。
 * 例如：今天有记录、昨天有、前天无 → 2；今天无、昨天有、前天有 → 2。
 */
export function currentStreak(records: Record[], now: number): number {
  const days = new Set<number>(recordDays(records));
  let cursor = startOfDay(now);
  if (!days.has(cursor)) {
    cursor -= DAY_MS;
  }
  let streak = 0;
  while (days.has(cursor)) {
    streak++;
    cursor -= DAY_MS;
  }
  return streak;
}

/** 距离最近一次记录的天数；无记录返回 null */
export function daysSinceLast(records: Record[], now: number): number | null {
  const days = recordDays(records);
  if (days.length === 0) {
    return null;
  }
  const last = days[days.length - 1];
  return Math.round((startOfDay(now) - last) / DAY_MS);
}

export interface IntervalStats {
  /** 最大间隔天数（相邻两个有记录日之间） */
  max: number;
  /** 平均间隔天数（保留 1 位小数） */
  avg: number;
  /** 间隔数量（记录日数 - 1） */
  count: number;
}

/** 记录日之间的间隔统计；不足 2 个记录日时返回全 0 */
export function intervalStats(records: Record[], now: number): IntervalStats {
  const days = recordDays(records);
  if (days.length < 2) {
    return { max: 0, avg: 0, count: 0 };
  }
  const gaps: number[] = [];
  for (let i = 1; i < days.length; i++) {
    gaps.push(Math.round((days[i] - days[i - 1]) / DAY_MS));
  }
  let max = 0;
  let sum = 0;
  for (let i = 0; i < gaps.length; i++) {
    sum += gaps[i];
    if (gaps[i] > max) {
      max = gaps[i];
    }
  }
  const avg = Math.round((sum / gaps.length) * 10) / 10;
  return { max: max, avg: avg, count: gaps.length };
}

export interface MonthCount {
  year: number;
  /** 0-11 */
  month: number;
  count: number;
}

/** 最近 N 个月（含当月）每月次数，用于趋势图；月份按自然月升序 */
export function monthCounts(records: Record[], now: number, months: number): MonthCount[] {
  const result: MonthCount[] = [];
  const cur = new Date(now);
  const curYear = cur.getFullYear();
  const curMonth = cur.getMonth();
  for (let i = months - 1; i >= 0; i--) {
    const total = curMonth - i;
    const year = curYear + Math.floor(total / 12);
    const month = ((total % 12) + 12) % 12;
    const start = monthStart(year, month);
    const end = monthEndExclusive(year, month);
    let count = 0;
    for (let j = 0; j < records.length; j++) {
      const ts = records[j].timestamp;
      if (ts >= start && ts < end) {
        count++;
      }
    }
    result.push({ year: year, month: month, count: count });
  }
  return result;
}

/** 指定自然月内的次数 */
export function countInMonth(records: Record[], year: number, month: number): number {
  const start = monthStart(year, month);
  const end = monthEndExclusive(year, month);
  let count = 0;
  for (let i = 0; i < records.length; i++) {
    const ts = records[i].timestamp;
    if (ts >= start && ts < end) {
      count++;
    }
  }
  return count;
}

/** 今天的次数 */
export function countToday(records: Record[], now: number): number {
  const start = startOfDay(now);
  const end = start + DAY_MS;
  let count = 0;
  for (let i = 0; i < records.length; i++) {
    const ts = records[i].timestamp;
    if (ts >= start && ts < end) {
      count++;
    }
  }
  return count;
}

/** 总次数 */
export function totalCount(records: Record[]): number {
  return records.length;
}

/** 某自然月内，按「日」统计次数，key 为日号 1-31 */
export function countByDayOfMonth(records: Record[], year: number, month: number): Map<number, number> {
  const map = new Map<number, number>();
  const start = monthStart(year, month);
  const end = monthEndExclusive(year, month);
  for (let i = 0; i < records.length; i++) {
    const ts = records[i].timestamp;
    if (ts >= start && ts < end) {
      const day = new Date(ts).getDate();
      const prev = map.get(day);
      map.set(day, prev === undefined ? 1 : prev + 1);
    }
  }
  return map;
}

/** 某自然月内的全部记录（升序） */
export function recordsInMonth(records: Record[], year: number, month: number): Record[] {
  const start = monthStart(year, month);
  const end = monthEndExclusive(year, month);
  const list: Record[] = [];
  for (let i = 0; i < records.length; i++) {
    const ts = records[i].timestamp;
    if (ts >= start && ts < end) {
      list.push(records[i]);
    }
  }
  list.sort((a, b) => a.timestamp - b.timestamp);
  return list;
}

/** 指定日（当日零点）的全部记录（升序） */
export function recordsOnDay(records: Record[], dayStartMs: number): Record[] {
  const start = dayStartMs;
  const end = start + DAY_MS;
  const list: Record[] = [];
  for (let i = 0; i < records.length; i++) {
    const ts = records[i].timestamp;
    if (ts >= start && ts < end) {
      list.push(records[i]);
    }
  }
  list.sort((a, b) => a.timestamp - b.timestamp);
  return list;
}
