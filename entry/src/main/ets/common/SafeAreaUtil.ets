/**
 * 鹿了么 - 安全区工具
 *
 * 获取系统安全区（状态栏 / 手势导航条）尺寸，用于沉浸式布局。
 */
import { window, UIContext } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

export interface SafeAreaInsets {
  /** 顶部状态栏高度（vp） */
  top: number;
  /** 底部手势导航条高度（vp） */
  bottom: number;
}

/** 加载系统安全区尺寸（px 转 vp）；失败时返回保守默认值 */
export async function loadSafeAreaInsets(ui: UIContext): Promise<SafeAreaInsets> {
  try {
    const host = ui.getHostContext();
    if (host === undefined || host === null) {
      return { top: 24, bottom: 16 };
    }
    const win = await window.getLastWindow(host as common.UIAbilityContext);
    const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const top = ui.px2vp(area.topRect.height);
    const bottom = ui.px2vp(area.bottomRect.height);
    return {
      top: top > 0 ? top : 24,
      bottom: bottom > 0 ? bottom : 16
    };
  } catch (err) {
    return { top: 24, bottom: 16 };
  }
}
