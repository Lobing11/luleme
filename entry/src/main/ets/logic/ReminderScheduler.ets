/**
 * 鹿了么 - 提醒调度（系统级提醒代理 reminderAgentManager）
 *
 * 为什么不用后台常驻 / WorkScheduler：
 *   - continuousTask 常驻耗电，且上架审核对"性健康类应用后台保活"很敏感；
 *   - WorkScheduler 最小粒度 20 分钟且会被系统合并延迟，做不出"准点闹钟"。
 *   reminderAgentManager 是系统统一调度，**重启后提醒依然有效**，代价只有一条普通权限
 *   `ohos.permission.PUBLISH_AGENT_REMINDER`（见 module.json5）。
 *
 * 两类提醒：
 *   1) 每日定时提醒：ReminderRequestAlarm，daysOfWeek = 1..7，可自定义文案；
 *   2) 葛神模式：每次记录后 8 小时的**一次性**提醒（ReminderRequestCalendar）。
 *      每次记录都会先 cancel 旧的再重建，语义永远是"距上次已经 8 小时"，
 *      所以不会像固定周期那样把提醒越积越多；落点若在静默时段则顺延到早上。
 */
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SettingsStore } from '../data/SettingsStore';

/** 与 AppScope/app.json5 的 bundleName、EntryAbility 保持一致：点提醒直接拉起应用 */
const BUNDLE_NAME: string = 'com.luleme.app';
const ABILITY_NAME: string = 'EntryAbility';
/** 葛神模式延后小时数 */
const GESHEN_DELAY_HOURS: number = 8;
/** 静默时段 [23:00, 08:00)：落在这个区间的提醒顺延到 08:00，避免半夜吵人 */
const QUIET_END_HOUR: number = 8;
const QUIET_START_HOUR: number = 23;
/** 每日提醒默认时刻 */
export const DEFAULT_REMINDER_HOUR: number = 21;
export const DEFAULT_REMINDER_MINUTE: number = 0;
/** 默认文案：用户确认过「提醒文案允许出现在锁屏」 */
export const DEFAULT_REMINDER_TEXT: string = '是时候鹿了！';
export const GESHEN_TEXT: string = '想变得和葛神一样强大吗？快来鹿吧！';

/** 每日定时提醒的配置 */
export interface DailyReminderConfig {
  hour: number;
  minute: number;
  text: string;
}

export class ReminderScheduler {
  private static instance: ReminderScheduler | null = null;

  /**
   * 最近一次 publishReminder 的错误码。1700002 = 系统未开放提醒能力/超出配额，
   * 在部分机型（未通过 AGC 提醒能力校验的设备）上恒为失败，此时降级为应用内提醒。
   */
  lastErrorCode: number = 0;

  static getInstance(): ReminderScheduler {
    if (ReminderScheduler.instance === null) {
      ReminderScheduler.instance = new ReminderScheduler();
    }
    return ReminderScheduler.instance;
  }

  /** 发布每日定时提醒（先撤旧的），返回是否成功 */
  async applyDaily(config: DailyReminderConfig): Promise<boolean> {
    await this.cancelDaily();
    try {
      const agent = this.buildWantAgent();
      const request: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: config.hour,
        minute: config.minute,
        // 1-7 对应周一到周日，全部选中即"每天"
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        title: '鹿了么',
        content: config.text,
        // 过期未点开时的兜底文案，同样走脱敏后的措辞
        expiredContent: config.text,
        tapDismissed: true,
        // 允许"稍后提醒"一次，间隔 5 分钟
        snoozeTimes: 1,
        timeInterval: 300,
        wantAgent: agent
      };
      const id = await reminderAgentManager.publishReminder(request);
      this.lastErrorCode = 0;
      await SettingsStore.getInstance().setReminderIds([id]);
      return true;
    } catch (err) {
      const e = err as BusinessError;
      this.lastErrorCode = e.code;
      hilog.error(0x0000, 'Reminder', 'publish failed: %{public}s %{public}s', `${e.code}`, e.message);
      return false;
    }
  }

  /** 撤销每日定时提醒（含历史遗留 id 的清理） */
  async cancelDaily(): Promise<void> {
    const store = SettingsStore.getInstance();
    const ids: number[] = await store.getReminderIds();
    for (let i = 0; i < ids.length; i++) {
      try {
        await reminderAgentManager.cancelReminder(ids[i]);
      } catch (err) {
        // 已被系统清理的 id 取消会抛错，忽略
      }
    }
    await store.setReminderIds([]);
  }

  /**
   * 记录新增后的钩子：葛神模式开启时，重建一条 8 小时后的一次性提醒。
   * 失败不影响记录本身，因此整体吞掉异常。
   */
  async onRecordCreated(recordTs: number): Promise<void> {
    const store = SettingsStore.getInstance();
    const enabled: boolean = await store.isGeshenEnabled();
    if (!enabled) {
      return;
    }
    await this.cancelGeshen();
    const fireAt: number = ReminderScheduler.geshenFireTime(recordTs);
    try {
      const agent = this.buildWantAgent();
      const request: reminderAgentManager.ReminderRequestCalendar = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
        dateTime: ReminderScheduler.toLocalDateTime(fireAt),
        title: '葛神模式',
        content: GESHEN_TEXT,
        expiredContent: GESHEN_TEXT,
        tapDismissed: true,
        wantAgent: agent
      };
      const id = await reminderAgentManager.publishReminder(request);
      await store.setGeshenReminderId(id);
    } catch (err) {
      // 提醒是增强功能，失败不阻塞记录
    }
  }

  /** 撤销葛神模式提醒（关闭开关、删除记录后调用） */
  async cancelGeshen(): Promise<void> {
    const store = SettingsStore.getInstance();
    const id: number = await store.getGeshenReminderId();
    if (id > 0) {
      try {
        await reminderAgentManager.cancelReminder(id);
      } catch (err) {
        // 已失效的 id 忽略
      }
      await store.setGeshenReminderId(0);
    }
  }

  /** 开关打开时补一次，避免"设置了但没生效" */
  async syncGeshenFromLastRecord(lastRecordTs: number): Promise<void> {
    const store = SettingsStore.getInstance();
    if (!(await store.isGeshenEnabled())) {
      await this.cancelGeshen();
      return;
    }
    if (lastRecordTs > 0) {
      await this.onRecordCreated(lastRecordTs);
    }
  }

  /**
   * 葛神模式的提醒时刻：记录时间 + 8 小时；若落在静默时段，顺延到当天/次日的 08:00。
   */
  static geshenFireTime(recordTs: number): number {
    const fire = new Date(recordTs + GESHEN_DELAY_HOURS * 3600 * 1000);
    const hour = fire.getHours();
    if (hour >= QUIET_START_HOUR || hour < QUIET_END_HOUR) {
      const next = new Date(fire.getTime());
      if (hour >= QUIET_START_HOUR) {
        next.setDate(next.getDate() + 1);
      }
      next.setHours(QUIET_END_HOUR, 0, 0, 0);
      return next.getTime();
    }
    return fire.getTime();
  }

  private static toLocalDateTime(ts: number): reminderAgentManager.LocalDateTime {
    const d = new Date(ts);
    const value: reminderAgentManager.LocalDateTime = {
      year: d.getFullYear(),
      // reminderAgentManager 的 month 取值范围是 1-12，与 Date 的 0-11 不同
      month: d.getMonth() + 1,
      day: d.getDate(),
      hour: d.getHours(),
      minute: d.getMinutes(),
      second: 0
    };
    return value;
  }

  /**
   * reminderAgentManager 的 WantAgent 是它自己的轻量结构（pkgName + abilityName），
   * 不是 @ohos.app.ability.wantAgent 的 WantAgent，直接给字面量即可。
   */
  private buildWantAgent(): reminderAgentManager.WantAgent {
    const agent: reminderAgentManager.WantAgent = {
      pkgName: BUNDLE_NAME,
      abilityName: ABILITY_NAME
    };
    return agent;
  }
}
