/**
 * 鹿了么 - 记录数据模型
 *
 * 一条记录 = 一次自慰记录。
 * 字段与数据库 records 表一一对应，全部为非空，简化序列化与 RDB 存取。
 */

export interface Record {
  /** 数据库自增主键 */
  id: number;
  /** 记录时间（epoch 毫秒） */
  timestamp: number;
  /** 心情档位 0-4，见 MOODS */
  mood: number;
  /** 备注，可为空字符串 */
  note: string;
}

/** 新增记录时 id 尚未分配 */
export interface NewRecord {
  timestamp: number;
  mood: number;
  note: string;
}

export interface MoodOption {
  value: number;
  emoji: string;
  label: string;
}

/** 心情选项：5 档 */
export const MOODS: MoodOption[] = [
  { value: 0, emoji: '🥰', label: '愉悦' },
  { value: 1, emoji: '😌', label: '放松' },
  { value: 2, emoji: '😄', label: '兴奋' },
  { value: 3, emoji: '😴', label: '疲惫' },
  { value: 4, emoji: '😕', label: '一般' }
];

export const DEFAULT_MOOD: number = 2;

export function moodEmoji(value: number): string {
  for (let i = 0; i < MOODS.length; i++) {
    if (MOODS[i].value === value) {
      return MOODS[i].emoji;
    }
  }
  return '😄';
}

export function moodLabel(value: number): string {
  for (let i = 0; i < MOODS.length; i++) {
    if (MOODS[i].value === value) {
      return MOODS[i].label;
    }
  }
  return '';
}

/** 校验 JSON.parse 得到的对象是否可安全转换为 Record（导入备份时使用） */
export function parseRecord(raw: object): Record | null {
  const obj = raw as Record;
  if (typeof obj.id !== 'number' || !Number.isFinite(obj.id)) {
    return null;
  }
  if (typeof obj.timestamp !== 'number' || !Number.isFinite(obj.timestamp)) {
    return null;
  }
  if (typeof obj.mood !== 'number' || obj.mood < 0 || obj.mood > 4) {
    return null;
  }
  if (typeof obj.note !== 'string') {
    return null;
  }
  return {
    id: obj.id,
    timestamp: obj.timestamp,
    mood: obj.mood,
    note: obj.note
  };
}

/** 时间显示格式化：MM-DD HH:mm */
export function formatDateTime(ts: number): string {
  const d = new Date(ts);
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const mi = String(d.getMinutes()).padStart(2, '0');
  return `${mm}-${dd} ${hh}:${mi}`;
}
