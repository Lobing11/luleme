/**
 * 鹿了么 - 日历网格计算（纯函数）
 *
 * 生成自然月的 7 列日历单元格序列，供首页热力图渲染。
 */
const WEEKDAYS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

/** 一周的列头 */
export function weekdayHeaders(): string[] {
  return WEEKDAYS;
}

/**
 * 生成某月的日历单元格。返回的数组中，
 * 元素为 null 表示占位（上/下月空位），数字 1-31 表示该月某日。
 * 结果总是 7 的整数倍，可直接按行渲染。
 */
export function buildMonthGrid(year: number, month: number): (number | null)[] {
  const first = new Date(year, month, 1);
  const startWeekday = first.getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const cells: (number | null)[] = [];
  for (let i = 0; i < startWeekday; i++) {
    cells.push(null);
  }
  for (let d = 1; d <= daysInMonth; d++) {
    cells.push(d);
  }
  while (cells.length % 7 !== 0) {
    cells.push(null);
  }
  return cells;
}

/** 年月组合 */
export interface YearMonth {
  year: number;
  month: number;
}

/** 由偏移量计算目标月份；delta 可为负数。返回 {year, month}，month 为 0-11 */
export function shiftMonth(year: number, month: number, delta: number): YearMonth {
  const total = month + delta;
  const y = year + Math.floor(total / 12);
  const m = ((total % 12) + 12) % 12;
  return { year: y, month: m };
}
