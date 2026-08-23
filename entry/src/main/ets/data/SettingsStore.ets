/**
 * 鹿了么 - 设置存储（Preferences）
 *
 * 存放应用锁、PIN、生物识别开关等轻量设置。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREF_NAME: string = 'luleme_settings';
const KEY_LOCK_ENABLED: string = 'lock_enabled';
const KEY_PIN_HASH: string = 'pin_hash';
const KEY_PIN_SALT: string = 'pin_salt';
const KEY_BIOMETRIC_ENABLED: string = 'biometric_enabled';

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

  /** 是否已配置 PIN（hash 与 salt 同时存在） */
  async hasPin(): Promise<boolean> {
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
