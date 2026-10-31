/**
 * 鹿了么 - 设置存储（Preferences）
 *
 * 存放应用锁、PIN、生物识别开关等轻量设置。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DEFAULT_MATERIAL_LEVEL, MATERIAL_LEVEL_KEY } from '../common/MaterialConfig';

const PREF_NAME: string = 'luleme_settings';
const KEY_LOCK_ENABLED: string = 'lock_enabled';
const KEY_PIN_HASH: string = 'pin_hash';
const KEY_PIN_SALT: string = 'pin_salt';
const KEY_BIOMETRIC_ENABLED: string = 'biometric_enabled';
const KEY_MATERIAL_LEVEL: string = MATERIAL_LEVEL_KEY;
/** 每日定时提醒 */
const KEY_REMINDER_ENABLED: string = 'reminder_enabled';
const KEY_REMINDER_HOUR: string = 'reminder_hour';
const KEY_REMINDER_MINUTE: string = 'reminder_minute';
const KEY_REMINDER_TEXT: string = 'reminder_text';
/** 已发布的每日提醒 id（逗号分隔），撤销时逐个 cancel */
const KEY_REMINDER_IDS: string = 'reminder_ids';
/** 葛神模式：记录后 8 小时提醒 */
const KEY_GESHEN_ENABLED: string = 'geshen_enabled';
const KEY_GESHEN_REMINDER_ID: string = 'geshen_reminder_id';
/** 防截屏 / 任务缩略图遮罩，默认开启 */
const KEY_PRIVACY_MODE: string = 'privacy_mode_enabled';

export class SettingsStore {
  private static instance: SettingsStore | null = null;
  private pref: preferences.Preferences | null = null;

  static getInstance(): SettingsStore {
    if (SettingsStore.instance === null) {
      SettingsStore.instance = new SettingsStore();
    }
    return SettingsStore.instance;
  }

  /** 初始化 Preferences（幂等） */
  async init(context: common.Context): Promise<void> {
    if (this.pref !== null) {
      return;
    }
    this.pref = await preferences.getPreferences(context, PREF_NAME);
  }

  private requirePref(): preferences.Preferences {
    if (this.pref === null) {
      throw new Error('SettingsStore not initialized');
    }
    return this.pref;
  }

  async isLockEnabled(): Promise<boolean> {
    return await this.requirePref().get(KEY_LOCK_ENABLED, false) as boolean;
  }

  async setLockEnabled(enabled: boolean): Promise<void> {
    await this.requirePref().put(KEY_LOCK_ENABLED, enabled);
    await this.requirePref().flush();
  }

  async getPinHash(): Promise<string> {
    return await this.requirePref().get(KEY_PIN_HASH, '') as string;
  }

  async setPinHash(hash: string): Promise<void> {
    await this.requirePref().put(KEY_PIN_HASH, hash);
    await this.requirePref().flush();
  }

  async getPinSalt(): Promise<string> {
    return await this.requirePref().get(KEY_PIN_SALT, '') as string;
  }

  async setPinSalt(salt: string): Promise<void> {
    await this.requirePref().put(KEY_PIN_SALT, salt);
    await this.requirePref().flush();
  }

  async isBiometricEnabled(): Promise<boolean> {
    return await this.requirePref().get(KEY_BIOMETRIC_ENABLED, false) as boolean;
  }

  async setBiometricEnabled(enabled: boolean): Promise<void> {
    await this.requirePref().put(KEY_BIOMETRIC_ENABLED, enabled);
    await this.requirePref().flush();
  }

  /** 沉浸光感材质档位（hdsMaterial.MaterialLevel 数值），默认自适应 */
  async getMaterialLevel(): Promise<number> {
    return await this.requirePref().get(KEY_MATERIAL_LEVEL, DEFAULT_MATERIAL_LEVEL) as number;
  }

  async setMaterialLevel(level: number): Promise<void> {
    await this.requirePref().put(KEY_MATERIAL_LEVEL, level);
    await this.requirePref().flush();
  }

  // ---- 每日定时提醒 ----

  async isReminderEnabled(): Promise<boolean> {
    return await this.requirePref().get(KEY_REMINDER_ENABLED, false) as boolean;
  }

  async setReminderEnabled(enabled: boolean): Promise<void> {
    await this.requirePref().put(KEY_REMINDER_ENABLED, enabled);
    await this.requirePref().flush();
  }

  async getReminderHour(): Promise<number> {
    return await this.requirePref().get(KEY_REMINDER_HOUR, 21) as number;
  }

  async setReminderHour(hour: number): Promise<void> {
    await this.requirePref().put(KEY_REMINDER_HOUR, hour);
    await this.requirePref().flush();
  }

  async getReminderMinute(): Promise<number> {
    return await this.requirePref().get(KEY_REMINDER_MINUTE, 0) as number;
  }

  async setReminderMinute(minute: number): Promise<void> {
    await this.requirePref().put(KEY_REMINDER_MINUTE, minute);
    await this.requirePref().flush();
  }

  async getReminderText(): Promise<string> {
    return await this.requirePref().get(KEY_REMINDER_TEXT, '是时候鹿了！') as string;
  }

  async setReminderText(text: string): Promise<void> {
    await this.requirePref().put(KEY_REMINDER_TEXT, text);
    await this.requirePref().flush();
  }

  /** 已发布的每日提醒 id 列表（存成逗号分隔字符串，Preferences 对数组支持不一致） */
  async getReminderIds(): Promise<number[]> {
    const raw = await this.requirePref().get(KEY_REMINDER_IDS, '') as string;
    if (raw.length === 0) {
      return [];
    }
    const ids: number[] = [];
    const parts: string[] = raw.split(',');
    for (let i = 0; i < parts.length; i++) {
      const value = Number.parseInt(parts[i], 10);
      if (!Number.isNaN(value) && value > 0) {
        ids.push(value);
      }
    }
    return ids;
  }

  async setReminderIds(ids: number[]): Promise<void> {
    await this.requirePref().put(KEY_REMINDER_IDS, ids.join(','));
    await this.requirePref().flush();
  }

  // ---- 葛神模式 ----

  async isGeshenEnabled(): Promise<boolean> {
    return await this.requirePref().get(KEY_GESHEN_ENABLED, false) as boolean;
  }

  async setGeshenEnabled(enabled: boolean): Promise<void> {
    await this.requirePref().put(KEY_GESHEN_ENABLED, enabled);
    await this.requirePref().flush();
  }

  async getGeshenReminderId(): Promise<number> {
    return await this.requirePref().get(KEY_GESHEN_REMINDER_ID, 0) as number;
  }

  async setGeshenReminderId(id: number): Promise<void> {
    await this.requirePref().put(KEY_GESHEN_REMINDER_ID, id);
    await this.requirePref().flush();
  }

  // ---- 隐私 ----

  /** 防截屏 / 任务切换缩略图遮罩（默认开启） */
  async isPrivacyModeEnabled(): Promise<boolean> {
    return await this.requirePref().get(KEY_PRIVACY_MODE, true) as boolean;
  }

  async setPrivacyModeEnabled(enabled: boolean): Promise<void> {
    await this.requirePref().put(KEY_PRIVACY_MODE, enabled);
    await this.requirePref().flush();
  }

  /** 是否已配置 PIN（hash 与 salt 同时存在） */  async hasPin(): Promise<boolean> {
    const hash = await this.getPinHash();
    const salt = await this.getPinSalt();
    return hash.length > 0 && salt.length > 0;
  }

  /** 关闭应用锁并清除所有锁相关设置 */
  async resetLock(): Promise<void> {
    const pref = this.requirePref();
    await pref.delete(KEY_PIN_HASH);
    await pref.delete(KEY_PIN_SALT);
    await pref.put(KEY_LOCK_ENABLED, false);
    await pref.put(KEY_BIOMETRIC_ENABLED, false);
    await pref.flush();
  }
}
