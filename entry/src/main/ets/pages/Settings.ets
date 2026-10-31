import { picker, fileIo } from '@kit.CoreFileKit';
import { common, bundleManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { window } from '@kit.ArkUI';
import { hdsMaterial } from '@kit.UIDesignKit';
import { notificationManager } from '@kit.NotificationKit';
import { SettingsStore } from '../data/SettingsStore';
import { RecordRepository } from '../data/RecordRepository';
import { Record, parseRecord } from '../model/RecordModel';
import { hashPin, verifyPin, randomSalt, getBiometricStatus } from '../logic/SecurityUtil';
import {
  ReminderScheduler,
  DailyReminderConfig,
  DEFAULT_REMINDER_HOUR,
  DEFAULT_REMINDER_MINUTE,
  DEFAULT_REMINDER_TEXT
} from '../logic/ReminderScheduler';
import {
  MaterialLevelOption,
  MATERIAL_LEVEL_OPTIONS,
  sanitizeMaterialLevel,
  supportsImmersiveMaterial
} from '../common/MaterialConfig';
import { CARD_PADDING, CARD_RADIUS, DIVIDER_INSET, PAGE_BOTTOM_PADDING, PAGE_PADDING, ROW_HEIGHT } from '../common/DesignTokens';

interface BackupPayload {
  app: string;
  version: number;
  exportedAt: number;
  records: Record[];
}

/** 读取应用自身 versionName，失败时返回空串（界面不显示版本号而不是显示错的） */
function readVersionLabel(): string {
  try {
    const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    return info.versionName.length > 0 ? `v${info.versionName}` : '';
  } catch (err) {
    return '';
  }
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/**
 * 导出文件名：luleme_backup_20261030-2312.json
 *
 * 三条约束：
 *   1) 纯英文前缀 —— 备份会落到公共目录 / 网盘，中文名等于自曝内容性质；
 *   2) 时间戳用 YYYYMMDD-HHmm，不含冒号（跨文件系统最安全），且可按名排序；
 *   3) 后缀只写在这里一次 —— 曾经同时传 fileSuffixChoices，导致出现 .json.json 或后缀被吃掉。
 */
function backupFileName(ts: number): string {
  const d = new Date(ts);
  const date = `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}`;
  const time = `${pad2(d.getHours())}${pad2(d.getMinutes())}`;
  return `luleme_backup_${date}-${time}.json`;
}

@Component
export struct SettingsPage {
  @State materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;
  @State lockEnabled: boolean = false;
  @State hasPin: boolean = false;
  @State bioEnabled: boolean = false;
  @State bioAvailable: boolean = false;
  @State bioEnrolled: boolean = false;
  @State showPinSetup: boolean = false;
  @State pinInput1: string = '';
  @State pinInput2: string = '';
  @State showPinDisable: boolean = false;
  @State disablePinInput: string = '';
  @State busy: boolean = false;
  /** 从 bundle 读取的真实版本号（避免界面里再手写一份 versionName） */
  @State appVersion: string = '';

  // ---- 每日定时提醒 ----
  @State reminderEnabled: boolean = false;
  @State reminderHour: number = DEFAULT_REMINDER_HOUR;
  @State reminderMinute: number = DEFAULT_REMINDER_MINUTE;
  @State reminderText: string = DEFAULT_REMINDER_TEXT;
  /** 文案输入的防抖计时器：连续输入时只在停手后写一次库 + 重发一次提醒 */
  private reminderTextTimer: number = -1;

  // ---- 葛神模式：记录后 8 小时提醒 ----
  @State geshenEnabled: boolean = false;

  // ---- 防截屏 ----
  @State privacyMode: boolean = true;

  aboutToAppear(): void {
    this.appVersion = readVersionLabel();
    this.load();
  }

  private async load(): Promise<void> {
    const store = SettingsStore.getInstance();
    this.materialLevel = sanitizeMaterialLevel(await store.getMaterialLevel());
    this.lockEnabled = await store.isLockEnabled();
    this.hasPin = await store.hasPin();
    this.bioEnabled = await store.isBiometricEnabled();
    const status = await getBiometricStatus();
    this.bioAvailable = status.hardwareSupported;
    this.bioEnrolled = status.enrolled;
    this.reminderEnabled = await store.isReminderEnabled();
    this.reminderHour = await store.getReminderHour();
    this.reminderMinute = await store.getReminderMinute();
    this.reminderText = await store.getReminderText();
    this.geshenEnabled = await store.isGeshenEnabled();
    this.privacyMode = await store.isPrivacyModeEnabled();
  }

  // ---------------- 提醒 ----------------

  private reminderTimeLabel(): string {
    return `${pad2(this.reminderHour)}:${pad2(this.reminderMinute)}`;
  }

  /**
   * 提醒最终是走系统通知通道送达的，所以必须先把应用的通知开关打开。
   *
   * 实测：通知被关掉时 publishReminder 会直接失败（hilog: "notification not allowed" /
   * "The number of reminders exceeds the limit[0]"），此时界面若不提示，用户会以为"开了但没响"。
   */
  private async ensureNotificationAllowed(): Promise<boolean> {
    try {
      if (notificationManager.isNotificationEnabledSync()) {
        return true;
      }
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await notificationManager.requestEnableNotification(context);
      const after: boolean = await notificationManager.isNotificationEnabled();
      return after;
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, 'Reminder', 'request notification failed: %{public}s %{public}s', `${e.code}`, e.message);
      return false;
    }
  }

  /**
   * 写设置 + 重新发布提醒。
   * 文案输入是逐字符触发的，所以调用方用 `toast` 参数区分"要不要弹提示"。
   */
  private async persistReminder(toast: boolean): Promise<void> {
    const store = SettingsStore.getInstance();
    await store.setReminderEnabled(this.reminderEnabled);
    await store.setReminderHour(this.reminderHour);
    await store.setReminderMinute(this.reminderMinute);
    await store.setReminderText(this.reminderText);

    if (!this.reminderEnabled) {
      await ReminderScheduler.getInstance().cancelDaily();
      return;
    }
    const allowed: boolean = await this.ensureNotificationAllowed();
    if (!allowed) {
      this.reminderEnabled = false;
      await store.setReminderEnabled(false);
      this.getUIContext().getPromptAction().showToast({ message: '需要允许通知才能收到提醒' });
      return;
    }
    const config: DailyReminderConfig = {
      hour: this.reminderHour,
      minute: this.reminderMinute,
      text: this.reminderText.length > 0 ? this.reminderText : DEFAULT_REMINDER_TEXT
    };
    const scheduler = ReminderScheduler.getInstance();
    const ok: boolean = await scheduler.applyDaily(config);
    if (!ok) {
      if (scheduler.lastErrorCode === 1700002) {
        // 1700002：系统未开放后台提醒能力（部分机型需通过 AGC 能力校验）。
        // 这种情况下不假装失败，而是保留开关并降级为「打开应用时提醒」。
        if (toast) {
          this.getUIContext().getPromptAction().showToast({
            message: '当前设备不支持后台提醒，已改为打开应用时提醒'
          });
        }
        return;
      }
      // 其它错误（例如通知被系统关闭）就把开关退回关闭，避免"看起来开了但不会响"
      this.reminderEnabled = false;
      await store.setReminderEnabled(false);
      this.getUIContext().getPromptAction().showToast({ message: '提醒设置失败，请检查系统设置' });
      return;
    }
    if (toast) {
      this.getUIContext().getPromptAction().showToast({
        message: `已设置每天 ${this.reminderTimeLabel()} 提醒`
      });
    }
  }

  private async onToggleReminder(v: boolean): Promise<void> {
    this.reminderEnabled = v;
    await this.persistReminder(v);
  }

  private pickReminderTime(): void {
    if (!this.reminderEnabled) {
      return;
    }
    const selected = new Date();
    selected.setHours(this.reminderHour, this.reminderMinute, 0, 0);
    this.getUIContext().showTimePickerDialog({
      selected: selected,
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        this.reminderHour = value.hour;
        this.reminderMinute = value.minute;
        this.persistReminder(true);
      }
    });
  }

  private onReminderTextChange(value: string): void {
    this.reminderText = value;
    if (this.reminderTextTimer >= 0) {
      clearTimeout(this.reminderTextTimer);
    }
    this.reminderTextTimer = setTimeout(() => {
      this.reminderTextTimer = -1;
      this.persistReminder(false);
    }, 800);
  }

  private async onToggleGeshen(v: boolean): Promise<void> {
    this.geshenEnabled = v;
    await SettingsStore.getInstance().setGeshenEnabled(v);
    const scheduler = ReminderScheduler.getInstance();
    if (!v) {
      await scheduler.cancelGeshen();
      return;
    }
    const allowed: boolean = await this.ensureNotificationAllowed();
    if (!allowed) {
      this.geshenEnabled = false;
      await SettingsStore.getInstance().setGeshenEnabled(false);
      this.getUIContext().getPromptAction().showToast({ message: '需要允许通知才能收到提醒' });
      return;
    }
    this.getUIContext().getPromptAction().showToast({
      message: '葛神模式：记录后 8 小时提醒你再来一次'
    });
    // 开启时按"最近一次记录"安排：没有记录就等下次记录后再生效
    const records: Record[] = await RecordRepository.getInstance().getAll();
    const lastTs: number = records.length > 0 ? records[0].timestamp : 0;
    await scheduler.syncGeshenFromLastRecord(lastTs);
    this.getUIContext().getPromptAction().showToast({
      message: lastTs > 0 ? '已按最近一次记录安排提醒' : '已开启，下次记录后 8 小时提醒'
    });
  }

  private async onTogglePrivacy(v: boolean): Promise<void> {
    this.privacyMode = v;
    await SettingsStore.getInstance().setPrivacyModeEnabled(v);
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const mainWindow = await window.getLastWindow(context);
      await mainWindow.setWindowPrivacyMode(v);
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({ message: '隐私模式设置失败' });
    }
  }

  private async onToggleLock(v: boolean): Promise<void> {
    if (v) {
      if (this.hasPin) {
        await SettingsStore.getInstance().setLockEnabled(true);
        this.lockEnabled = true;
      } else {
        this.showPinSetup = true;
      }
    } else {
      if (this.hasPin) {
        this.showPinDisable = true;
      } else {
        await SettingsStore.getInstance().setLockEnabled(false);
        this.lockEnabled = false;
      }
    }
  }

  private async savePinSetup(): Promise<void> {
    if (this.pinInput1.length < 4 || this.pinInput1.length > 6) {
      this.getUIContext().getPromptAction().showToast({ message: 'PIN 需为 4-6 位数字' });
      return;
    }
    if (this.pinInput1 !== this.pinInput2) {
      this.getUIContext().getPromptAction().showToast({ message: '两次输入的 PIN 不一致' });
      return;
    }
    const salt = randomSalt();
    const hash = await hashPin(this.pinInput1, salt);
    const store = SettingsStore.getInstance();
    await store.setPinSalt(salt);
    await store.setPinHash(hash);
    await store.setLockEnabled(true);
    this.hasPin = true;
    this.lockEnabled = true;
    this.showPinSetup = false;
    this.pinInput1 = '';
    this.pinInput2 = '';
    this.getUIContext().getPromptAction().showToast({ message: '应用锁已开启' });
  }

  private async confirmDisable(): Promise<void> {
    const store = SettingsStore.getInstance();
    const salt = await store.getPinSalt();
    const hash = await store.getPinHash();
    const ok = await verifyPin(this.disablePinInput, salt, hash);
    if (!ok) {
      this.getUIContext().getPromptAction().showToast({ message: 'PIN 不正确' });
      return;
    }
    await store.resetLock();
    this.hasPin = false;
    this.lockEnabled = false;
    this.bioEnabled = false;
    this.showPinDisable = false;
    this.disablePinInput = '';
    this.getUIContext().getPromptAction().showToast({ message: '应用锁已关闭' });
  }

  private async onToggleBio(v: boolean): Promise<void> {
    if (v && !this.bioAvailable) {
      this.getUIContext().getPromptAction().showToast({ message: '设备不支持指纹/人脸' });
      return;
    }
    await SettingsStore.getInstance().setBiometricEnabled(v);
    this.bioEnabled = v;
    if (v && !this.bioEnrolled) {
      this.getUIContext().getPromptAction()
        .showToast({ message: '已开启，请先在「设置 > 生物识别和密码」中录入指纹或人脸' });
    }
  }

  private bioDesc(): string {
    if (!this.bioAvailable) {
      return '设备不支持';
    }
    if (!this.bioEnrolled) {
      return '需先录入指纹/人脸';
    }
    return '指纹 / 人脸';
  }

  private async selectMaterial(level: hdsMaterial.MaterialLevel): Promise<void> {
    if (this.materialLevel === level) {
      return;
    }
    this.materialLevel = level;
    await SettingsStore.getInstance().setMaterialLevel(level);
    this.getUIContext().getPromptAction().showToast({ message: '沉浸光感档位已切换' });
  }

  private materialDesc(): string {
    if (!supportsImmersiveMaterial()) {
      return '本机不支持沉浸光感';
    }
    return '根据设备性能自动调整视觉效果';
  }

  private async exportBackup(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const documentPicker = new picker.DocumentViewPicker(context);
      // 只传带后缀的文件名，不再传 fileSuffixChoices：
      // 两处都声明后缀时，不同文件管理器会拼成 xxx.json.json，或反过来把后缀吃掉。
      const uris: string[] = await documentPicker.save({
        newFileNames: [backupFileName(Date.now())]
      });
      if (uris.length === 0) {
        return;
      }
      const records = await RecordRepository.getInstance().getAll();
      const payload: BackupPayload = {
        app: '鹿了么',
        version: 1,
        exportedAt: Date.now(),
        records: records
      };
      const json = JSON.stringify(payload);
      const file = fileIo.openSync(uris[0],
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, json);
      } finally {
        fileIo.closeSync(file);
      }
      // 兜底校验：个别文件管理器会按"类型"重命名所选文件，后缀不对时至少把真实文件名告诉用户
      const savedName: string = uris[0].substring(uris[0].lastIndexOf('/') + 1);
      const suffixOk: boolean = savedName.toLowerCase().endsWith('.json');
      this.getUIContext().getPromptAction().showToast({
        message: suffixOk ? `已导出 ${records.length} 条记录` : `已导出 ${records.length} 条（${savedName}）`
      });
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({ message: '导出失败' });
    } finally {
      this.busy = false;
    }
  }

  private async importBackup(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const documentPicker = new picker.DocumentViewPicker(context);
      const uris: string[] = await documentPicker.select({ maxSelectNumber: 1 });
      if (uris.length === 0) {
        return;
      }
      const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
      let text = '';
      try {
        const stat = fileIo.statSync(file.fd);
        const buf = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buf);
        const decoder = util.TextDecoder.create('utf-8');
        text = decoder.decodeToString(new Uint8Array(buf));
      } finally {
        fileIo.closeSync(file);
      }
      const payload = JSON.parse(text) as BackupPayload;
      if (payload === null || payload === undefined ||
        typeof payload.version !== 'number' || !Array.isArray(payload.records)) {
        this.getUIContext().getPromptAction().showToast({ message: '备份文件格式不正确' });
        return;
      }
      const valid: Record[] = [];
      for (let i = 0; i < payload.records.length; i++) {
        const r = parseRecord(payload.records[i]);
        if (r !== null) {
          valid.push(r);
        }
      }
      if (valid.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '备份文件中没有有效记录' });
        return;
      }
      this.getUIContext().showAlertDialog({
        title: '导入备份',
        message: `将导入 ${valid.length} 条记录，并替换当前全部数据。是否继续？`,
        primaryButton: {
          value: '取消',
          action: () => {
          }
        },
        secondaryButton: {
          value: '导入',
          action: () => {
            this.doImport(valid);
          }
        }
      });
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({ message: '导入失败，文件可能已损坏' });
    } finally {
      this.busy = false;
    }
  }

  private async doImport(records: Record[]): Promise<void> {
    const repo = RecordRepository.getInstance();
    await repo.clearAll();
    for (let i = 0; i < records.length; i++) {
      await repo.add(records[i].timestamp, records[i].mood, records[i].note);
    }
    this.getUIContext().getPromptAction().showToast({ message: `已导入 ${records.length} 条记录` });
  }

  private clearAll(): void {
    this.getUIContext().showAlertDialog({
      title: '清空所有记录',
      message: '此操作将删除全部记录且无法恢复，确定继续吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        fontColor: $r('app.color.color_danger'),
        action: () => {
          this.doClearAll();
        }
      }
    });
  }

  private async doClearAll(): Promise<void> {
    await RecordRepository.getInstance().clearAll();
    this.getUIContext().getPromptAction().showToast({ message: '已清空全部记录' });
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize(13)
      .fontColor($r('app.color.color_text_secondary'))
      .width('100%')
      .margin({ top: 8, bottom: 4 })
  }

  /**
   * 应用锁行。
   *
   * 副标题依赖 `hasPin`（用户在弹出的 PIN 面板里设置/取消后会变），
   * 因此不能作为参数传给 @Builder —— @Builder 入参按值传递，会把首次构建时的
   * 文案固化下来，就会出现「刚设完 PIN，行里还写着未设置 PIN」。这里直接读 @State。
   */
  @Builder
  lockSettingRow() {
    Row() {
      Column({ space: 2 }) {
        Text('应用锁')
          .fontSize(15)
          .fontColor($r('app.color.color_text_primary'))
        Text(this.hasPin ? '启动时需输入 PIN' : '未设置 PIN')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .layoutWeight(1)
  }

  /** 生物识别行：副标题来自设备能力 + 锁状态，同样不能按值传进 @Builder */
  @Builder
  bioSettingRow() {
    Row() {
      Column({ space: 2 }) {
        Text('生物识别解锁')
          .fontSize(15)
          .fontColor($r('app.color.color_text_primary'))
        Text(this.bioDesc())
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .layoutWeight(1)
  }

  /** 生物识别开关可用性：必须先开应用锁、已设 PIN，且设备支持并已录入 */
  private bioToggleEnabled(): boolean {
    return this.lockEnabled && this.hasPin && this.bioAvailable;
  }

  /** 定时提醒行：副标题依赖开关与时间，零参直读 @State（@Builder 按值传参会被冻结） */
  @Builder
  reminderRow() {
    Row() {
      Column({ space: 2 }) {
        Text('定时提醒')
          .fontSize(15)
          .fontColor($r('app.color.color_text_primary'))
        Text(this.reminderEnabled ? `每天 ${this.reminderTimeLabel()}` : '关闭时不发送任何提醒')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .layoutWeight(1)
  }

  /** 葛神模式行 */
  @Builder
  geshenRow() {
    Row() {
      Column({ space: 2 }) {
        Text('葛神模式')
          .fontSize(15)
          .fontColor($r('app.color.color_text_primary'))
        Text(this.geshenEnabled ? '记录后 8 小时提醒一次' : '记录后 8 小时，提醒你变得更强')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .layoutWeight(1)
  }

  /** 防截屏行 */
  @Builder
  privacyRow() {
    Row() {
      Column({ space: 2 }) {
        Text('防截屏保护')
          .fontSize(15)
          .fontColor($r('app.color.color_text_primary'))
        Text(this.privacyMode ? '截屏与最近任务缩略图已遮罩' : '已关闭，允许截屏与任务预览')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .layoutWeight(1)
  }

  /** 提醒时间行：点击弹出系统时间选择器（关闭提醒时整行置灰） */
  @Builder
  reminderTimeRow() {
    Row() {
      Text('提醒时间')
        .fontSize(15)
        .fontColor($r('app.color.color_text_primary'))
      Blank()
      Text(this.reminderTimeLabel())
        .fontSize(15)
        .fontColor(this.reminderEnabled ? $r('app.color.color_primary') : $r('app.color.color_text_secondary'))
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('app.color.color_text_secondary')])
    }
    .width('100%')
    .height(ROW_HEIGHT)
    .padding({ left: CARD_PADDING, right: CARD_PADDING })
    .enabled(this.reminderEnabled)
    .opacity(this.reminderEnabled ? 1 : 0.4)
    .onClick(() => {
      this.pickReminderTime();
    })
    .accessibilityText('提醒时间')
  }

  /** 提醒文案：会直接出现在锁屏，所以明确告知用户 */
  @Builder
  reminderTextRow() {
    Column({ space: 6 }) {
      Text('提醒文案')
        .fontSize(15)
        .fontColor($r('app.color.color_text_primary'))
      TextInput({ text: this.reminderText, placeholder: DEFAULT_REMINDER_TEXT })
        .maxLength(30)
        .height(44)
        .borderRadius(10)
        .backgroundColor($r('app.color.color_bg'))
        .enabled(this.reminderEnabled)
        .onChange((v: string) => {
          this.onReminderTextChange(v);
        })
      Text('会显示在锁屏与通知中心')
        .fontSize(11)
        .fontColor($r('app.color.color_text_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: CARD_PADDING, right: CARD_PADDING, top: 12, bottom: 12 })
    .opacity(this.reminderEnabled ? 1 : 0.4)
  }

  @Builder
  pinSetupPanel() {
    Column({ space: 10 }) {
      Text('设置 PIN（4-6 位数字）')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_primary'))
        .width('100%')
      TextInput({ text: this.pinInput1, placeholder: '输入 PIN' })
        .type(InputType.NUMBER_PASSWORD)
        .maxLength(6)
        .height(44)
        .borderRadius(10)
        .backgroundColor($r('app.color.color_bg'))
        .onChange((v: string) => {
          this.pinInput1 = v;
        })
      TextInput({ text: this.pinInput2, placeholder: '再次输入 PIN' })
        .type(InputType.NUMBER_PASSWORD)
        .maxLength(6)
        .height(44)
        .borderRadius(10)
        .backgroundColor($r('app.color.color_bg'))
        .onChange((v: string) => {
          this.pinInput2 = v;
        })
      Button('开启应用锁')
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontColor($r('app.color.color_white'))
        .backgroundColor($r('app.color.color_primary'))
        .borderRadius(20)
        .onClick(() => {
          this.savePinSetup();
        })
    }
    .width('100%')
    .padding(CARD_PADDING)
    .borderRadius(CARD_RADIUS)
    .backgroundColor($r('app.color.color_card'))
  }

  @Builder
  pinDisablePanel() {
    Column({ space: 10 }) {
      Text('输入当前 PIN 以关闭应用锁')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_primary'))
        .width('100%')
      TextInput({ text: this.disablePinInput, placeholder: '当前 PIN' })
        .type(InputType.NUMBER_PASSWORD)
        .maxLength(6)
        .height(44)
        .borderRadius(10)
        .backgroundColor($r('app.color.color_bg'))
        .onChange((v: string) => {
          this.disablePinInput = v;
        })
      Button('确认关闭')
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontColor($r('app.color.color_white'))
        .backgroundColor($r('app.color.color_danger'))
        .borderRadius(20)
        .onClick(() => {
          this.confirmDisable();
        })
    }
    .width('100%')
    .padding(CARD_PADDING)
    .borderRadius(CARD_RADIUS)
    .backgroundColor($r('app.color.color_card'))
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 10 }) {
          this.sectionTitle('隐私锁')
          Column({ space: 0 }) {
            Row() {
              this.lockSettingRow()
              Toggle({ type: ToggleType.Switch, isOn: this.lockEnabled })
                .selectedColor($r('app.color.color_primary'))
                .onChange((v: boolean) => {
                  this.onToggleLock(v);
                })
                .accessibilityText('应用锁开关')
            }
            .width('100%')
            .padding({ left: CARD_PADDING, right: CARD_PADDING })
            .height(ROW_HEIGHT)
            Divider()
              .color($r('app.color.color_border'))
              .margin({ left: DIVIDER_INSET, right: DIVIDER_INSET })
            Row() {
              this.bioSettingRow()
              Toggle({ type: ToggleType.Switch, isOn: this.bioEnabled })
                .selectedColor($r('app.color.color_primary'))
                .enabled(this.bioToggleEnabled())
                .onChange((v: boolean) => {
                  this.onToggleBio(v);
                })
                .accessibilityText('生物识别解锁开关')
            }
            .width('100%')
            .padding({ left: CARD_PADDING, right: CARD_PADDING })
            .height(ROW_HEIGHT)
            // 不可用时整行置灰：避免"看起来能点、点了没反应"
            .opacity(this.bioToggleEnabled() ? 1 : 0.4)
            Divider()
              .color($r('app.color.color_border'))
              .margin({ left: DIVIDER_INSET, right: DIVIDER_INSET })
            Row() {
              this.privacyRow()
              Toggle({ type: ToggleType.Switch, isOn: this.privacyMode })
                .selectedColor($r('app.color.color_primary'))
                .onChange((v: boolean) => {
                  this.onTogglePrivacy(v);
                })
                .accessibilityText('防截屏保护开关')
            }
            .width('100%')
            .padding({ left: CARD_PADDING, right: CARD_PADDING })
            .height(ROW_HEIGHT)
          }
          .width('100%')
          .borderRadius(CARD_RADIUS)
          .backgroundColor($r('app.color.color_card'))

          if (this.showPinSetup) {
            this.pinSetupPanel()
          }
          if (this.showPinDisable) {
            this.pinDisablePanel()
          }

          this.sectionTitle('沉浸光感')
          Column({ space: 12 }) {
            Column({ space: 2 }) {
              Text('材质档位')
                .fontSize(15)
                .fontColor($r('app.color.color_text_primary'))
              Text(this.materialDesc())
                .fontSize(12)
                .fontColor($r('app.color.color_text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            // 四档等宽分段控件：不再把当前值单独贴在行尾（旧版会被屏幕右缘切掉）
            Row({ space: 8 }) {
              ForEach(MATERIAL_LEVEL_OPTIONS, (opt: MaterialLevelOption) => {
                Row() {
                  Text(opt.label)
                    .fontSize(13)
                    .fontColor(this.materialLevel === opt.key ?
                      $r('app.color.color_white') : $r('app.color.color_text_secondary'))
                }
                .layoutWeight(1)
                .height(34)
                .justifyContent(FlexAlign.Center)
                .borderRadius(17)
                .backgroundColor(this.materialLevel === opt.key ?
                  $r('app.color.color_primary') : $r('app.color.color_bg'))
                .stateStyles({
                  pressed: {
                    .backgroundColor($r('app.color.color_press'))
                  },
                  normal: {
                    .backgroundColor(this.materialLevel === opt.key ?
                      $r('app.color.color_primary') : $r('app.color.color_bg'))
                  }
                })
                .onClick(() => {
                  this.selectMaterial(opt.key);
                })
                .accessibilityText(opt.label)
              }, (opt: MaterialLevelOption) => opt.key.toString())
            }
            .width('100%')
          }
          .width('100%')
          .padding(CARD_PADDING)
          .borderRadius(CARD_RADIUS)
          .backgroundColor($r('app.color.color_card'))

          this.sectionTitle('提醒')
          Column({ space: 0 }) {
            Row() {
              this.reminderRow()
              Toggle({ type: ToggleType.Switch, isOn: this.reminderEnabled })
                .selectedColor($r('app.color.color_primary'))
                .onChange((v: boolean) => {
                  this.onToggleReminder(v);
                })
                .accessibilityText('定时提醒开关')
            }
            .width('100%')
            .padding({ left: CARD_PADDING, right: CARD_PADDING })
            .height(ROW_HEIGHT)
            Divider()
              .color($r('app.color.color_border'))
              .margin({ left: DIVIDER_INSET, right: DIVIDER_INSET })
            this.reminderTimeRow()
            Divider()
              .color($r('app.color.color_border'))
              .margin({ left: DIVIDER_INSET, right: DIVIDER_INSET })
            this.reminderTextRow()
            Divider()
              .color($r('app.color.color_border'))
              .margin({ left: DIVIDER_INSET, right: DIVIDER_INSET })
            Row() {
              this.geshenRow()
              Toggle({ type: ToggleType.Switch, isOn: this.geshenEnabled })
                .selectedColor($r('app.color.color_primary'))
                .onChange((v: boolean) => {
                  this.onToggleGeshen(v);
                })
                .accessibilityText('葛神模式开关')
            }
            .width('100%')
            .padding({ left: CARD_PADDING, right: CARD_PADDING })
            .height(ROW_HEIGHT)
          }
          .width('100%')
          .borderRadius(CARD_RADIUS)
          .backgroundColor($r('app.color.color_card'))

          this.sectionTitle('数据')
          Column({ space: 0 }) {
            this.actionRow('导出备份', '保存为 JSON 文件', () => {
              this.exportBackup();
            })
            Divider()
              .color($r('app.color.color_border'))
              .margin({ left: DIVIDER_INSET, right: DIVIDER_INSET })
            this.actionRow('导入备份', '替换当前数据', () => {
              this.importBackup();
            })
            Divider()
              .color($r('app.color.color_border'))
              .margin({ left: DIVIDER_INSET, right: DIVIDER_INSET })
            this.actionRow('清空所有记录', '删除全部数据', () => {
              this.clearAll();
            }, true)
          }
          .width('100%')
          .borderRadius(CARD_RADIUS)
          .backgroundColor($r('app.color.color_card'))

          this.sectionTitle('关于')
          Column({ space: 0 }) {
            this.versionRow()
            Divider()
              .color($r('app.color.color_border'))
              .margin({ left: DIVIDER_INSET, right: DIVIDER_INSET })
            this.aboutRow('隐私说明', '')
            Text('所有记录仅保存在本机，应用不联网、不上传任何数据。')
              .fontSize(13)
              .fontColor($r('app.color.color_text_secondary'))
              .width('100%')
              .lineHeight(20)
              .padding({ left: 16, right: 16, top: 12, bottom: 16 })
          }
          .width('100%')
          .borderRadius(CARD_RADIUS)
          .backgroundColor($r('app.color.color_card'))
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: PAGE_PADDING, bottom: PAGE_BOTTOM_PADDING })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg'))
  }

  /**
   * 版本行。零参 @Builder 内直接读 @State —— 若按 `aboutRow('版本', this.appVersion)` 传参，
   * 字符串会被按值固化在子树里，版本号一改就显示成旧值。
   */
  @Builder
  versionRow() {
    Row() {
      Text('版本')
        .fontSize(15)
        .fontColor($r('app.color.color_text_primary'))
      Blank()
      if (this.appVersion.length > 0) {
        Text(this.appVersion)
          .fontSize(15)
          .fontColor($r('app.color.color_text_secondary'))
      }
    }
    .width('100%')
    .height(ROW_HEIGHT)
    .padding({ left: CARD_PADDING, right: CARD_PADDING })
  }

  @Builder
  aboutRow(title: string, value: string) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor($r('app.color.color_text_primary'))
      Blank()
      if (value.length > 0) {
        Text(value)
          .fontSize(15)
          .fontColor($r('app.color.color_text_secondary'))
      }
    }
    .width('100%')
    .height(ROW_HEIGHT)
    .padding({ left: CARD_PADDING, right: CARD_PADDING })
  }

  @Builder
  actionRow(title: string, desc: string, action: () => void, danger: boolean = false) {
    Row() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(15)
          .fontColor(danger ? $r('app.color.color_danger') : $r('app.color.color_text_primary'))
        if (desc.length > 0) {
          Text(desc)
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(16)
        .fontColor($r('app.color.color_text_secondary'))
    }
    .width('100%')
    .height(ROW_HEIGHT)
    .padding({ left: CARD_PADDING, right: CARD_PADDING })
    .borderRadius(0)
    .stateStyles({
      pressed: {
        .backgroundColor($r('app.color.color_press'))
      },
      normal: {
        .backgroundColor(Color.Transparent)
      }
    })
    .onClick(() => {
      action();
    })
  }
}
