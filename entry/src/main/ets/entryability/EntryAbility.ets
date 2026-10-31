import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { RecordRepository } from '../data/RecordRepository';
import { SettingsStore } from '../data/SettingsStore';
import { LOCK_UNLOCKED_KEY } from '../common/Constants';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  /** 主窗口引用：隐私模式开关变化 / 回到前台时都需要重新下发 */
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    // 初始化本地数据层（幂等）
    AppStorage.setOrCreate(LOCK_UNLOCKED_KEY, false);
    RecordRepository.getInstance().init(this.context);
    SettingsStore.getInstance().init(this.context);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 沉浸式：窗口铺满全屏，并隐藏状态栏与手势导航条，真正做到全屏显示
    try {
      const mainWindow = windowStage.getMainWindowSync();
      this.mainWindow = mainWindow;
      mainWindow.setWindowLayoutFullScreen(true);
      mainWindow.setSpecificSystemBarEnabled('status', false);
      mainWindow.setSpecificSystemBarEnabled('navigation', false);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set fullscreen. Cause: %{public}s', JSON.stringify(err));
    }

    // 隐私模式：截屏 / 录屏 / 任务切换缩略图遮罩（默认开启，设置页可关）
    this.applyPrivacyMode();

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    this.mainWindow = null;
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    this.applyPrivacyMode();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  /**
   * 下发窗口隐私模式。
   *
   * setWindowPrivacyMode(true) 后，截屏、录屏与最近任务缩略图都会被遮罩，
   * 是这类"本机私密记录"应用最该有的开关；失败只记日志，不影响启动。
   */
  private async applyPrivacyMode(): Promise<void> {
    if (this.mainWindow === null) {
      return;
    }
    try {
      const enabled = await SettingsStore.getInstance().isPrivacyModeEnabled();
      await this.mainWindow.setWindowPrivacyMode(enabled);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set privacy mode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onBackground(): void {
    // Ability has back to background：要求下次回到前台时重新解锁
    AppStorage.setOrCreate(LOCK_UNLOCKED_KEY, false);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
