/**
 * 鹿了么 - 锁屏页
 *
 * PIN 输入（6 位）或生物识别解锁。
 * 解锁成功后置 AppStorage('appUnlocked') = true 并返回首页。
 */
import { SettingsStore } from '../data/SettingsStore';
import { verifyPin, getBiometricStatus, startBiometricAuth } from '../logic/SecurityUtil';
import { LOCK_UNLOCKED_KEY } from '../common/Constants';

@Component
export struct LockPage {
  @State pin: string = '';
  @State errorMsg: string = '';
  @State bioEnabled: boolean = false;
  @State bioAvailable: boolean = false;
  @State bioEnrolled: boolean = false;
  private salt: string = '';
  private hash: string = '';
  private verifying: boolean = false;

  async aboutToAppear(): Promise<void> {
    const store = SettingsStore.getInstance();
    this.salt = await store.getPinSalt();
    this.hash = await store.getPinHash();
    this.bioEnabled = await store.isBiometricEnabled();
    if (this.bioEnabled) {
      const status = await getBiometricStatus();
      this.bioAvailable = status.hardwareSupported;
      this.bioEnrolled = status.enrolled;
    }
  }

  private unlock(): void {
    AppStorage.setOrCreate(LOCK_UNLOCKED_KEY, true);
    this.queryNavigationInfo()?.pathStack.pop();
  }

  private async verify(): Promise<void> {
    if (this.verifying) {
      return;
    }
    this.verifying = true;
    try {
      const ok = await verifyPin(this.pin, this.salt, this.hash);
      if (ok) {
        this.unlock();
      } else {
        this.pin = '';
        this.errorMsg = 'PIN 不正确，请重试';
        this.getUIContext().getPromptAction().showToast({ message: 'PIN 不正确' });
      }
    } finally {
      this.verifying = false;
    }
  }

  private onKey(key: string): void {
    if (key === 'del') {
      this.pin = this.pin.slice(0, -1);
      return;
    }
    if (this.pin.length >= 6) {
      return;
    }
    this.pin += key;
    if (this.pin.length === 6) {
      this.verify();
    }
  }

  private async biometric(): Promise<void> {
    const ok = await startBiometricAuth('解锁鹿了么');
    if (ok) {
      this.unlock();
    } else if (!this.bioEnrolled) {
      this.getUIContext().getPromptAction()
        .showToast({ message: '未录入指纹/人脸，请先在「设置 > 生物识别和密码」中录入' });
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '验证失败，请重试或输入 PIN' });
    }
  }

  @Builder
  keyView(key: string) {
    if (key.length === 0) {
      // 空占位
      Column()
        .width(72)
        .height(72)
    } else {
      Text(key)
        .width(72)
        .height(72)
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_primary'))
        .textAlign(TextAlign.Center)
        .borderRadius(36)
        .backgroundColor($r('app.color.color_card'))
        .stateStyles({
          pressed: {
            .backgroundColor($r('app.color.color_primary_soft'))
          },
          normal: {
            .backgroundColor($r('app.color.color_card'))
          }
        })
        .onClick(() => {
          this.onKey(key);
        })
    }
  }

  build() {
    NavDestination() {
      Column({ space: 20 }) {
        Blank()
          .layoutWeight(1)
        Text('🦌')
          .fontSize(48)
        Text('鹿了么')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))

        Row({ space: 10 }) {
          ForEach([0, 1, 2, 3, 4, 5], (i: number) => {
            Circle({ width: 14, height: 14 })
              .fill(i < this.pin.length ?
                $r('app.color.color_primary') : $r('app.color.color_border'))
          }, (i: number) => i.toString())
        }
        .margin({ top: 10 })

        Text(this.errorMsg)
          .fontSize(12)
          .fontColor($r('app.color.color_danger'))
          .height(18)

        Column({ space: 14 }) {
          Row({ space: 20 }) {
            this.keyView('1')
            this.keyView('2')
            this.keyView('3')
          }
          Row({ space: 20 }) {
            this.keyView('4')
            this.keyView('5')
            this.keyView('6')
          }
          Row({ space: 20 }) {
            this.keyView('7')
            this.keyView('8')
            this.keyView('9')
          }
          Row({ space: 20 }) {
            this.keyView('')
            this.keyView('0')
            this.keyView('del')
          }
        }

        if (this.bioEnabled && this.bioAvailable) {
          Button('指纹 / 人脸解锁')
            .fontSize(14)
            .fontColor($r('app.color.color_primary'))
            .backgroundColor($r('app.color.color_primary_soft'))
            .borderRadius(22)
            .height(44)
            .onClick(() => {
              this.biometric();
            })
        }

        Text('忘记 PIN 时，只能通过清除应用数据恢复')
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
        Blank()
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.color_bg'))
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      // 未解锁不允许返回
      return true;
    })
  }
}
