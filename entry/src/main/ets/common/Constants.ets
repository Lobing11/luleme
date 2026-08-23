/**
 * 鹿了么 - 全局常量
 */

/** 热力图 5 档颜色（浅 → 深） */
export const HEAT_COLORS: Resource[] = [
  $r('app.color.heat_0'),
  $r('app.color.heat_1'),
  $r('app.color.heat_2'),
  $r('app.color.heat_3'),
  $r('app.color.heat_4')
];

/** 根据次数映射热力档位 0-4 */
export function heatLevel(count: number): number {
  if (count <= 0) {
    return 0;
  }
  if (count === 1) {
    return 1;
  }
  if (count === 2) {
    return 2;
  }
  if (count === 3) {
    return 3;
  }
  return 4;
}

/** Navigation 路由名 */
export const ROUTE_RECORD_EDIT: string = 'RecordEdit';
export const ROUTE_STATS: string = 'Stats';
export const ROUTE_SETTINGS: string = 'Settings';
export const ROUTE_LOCK: string = 'Lock';

/** 记录编辑页参数 */
export interface RecordEditParam {
  /** 编辑已有记录时传入其 id；新增时为 undefined */
  id?: number;
  /** 新增时预设的日期（当日零点毫秒）；默认今天 */
  date?: number;
}

/** 锁屏状态：解锁成功后置 true，退到后台由 EntryAbility 置 false */
export const LOCK_UNLOCKED_KEY: string = 'appUnlocked';
