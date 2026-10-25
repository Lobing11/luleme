import { picker, fileIo } from '@kit.CoreFileKit';
import { common, bundleManager } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { hdsMaterial } from '@kit.UIDesignKit';
import { SettingsStore } from '../data/SettingsStore';
import { RecordRepository } from '../data/RecordRepository';
import { Record, parseRecord } from '../model/RecordModel';
import { hashPin, verifyPin, randomSalt, getBiometricStatus } from '../logic/SecurityUtil';
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
      const uris: string[] = await documentPicker.save({
        newFileNames: ['luleme_backup.json'],
        fileSuffixChoices: ['json']
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
      this.getUIContext().getPromptAction().showToast({ message: `已导出 ${records.length} 条记录` });
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
