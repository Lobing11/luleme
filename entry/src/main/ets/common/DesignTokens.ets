/**
 * 鹿了么 - 设计 token（间距 / 圆角 / 尺寸）
 *
 * 目的：把散落各页的魔法数字收敛到一处，保证三页视觉一致，
 * 后续调整（例如统一放大字号、换圆角）只改这里。
 * 颜色仍走 resources/base+dark/element/color.json（深浅主题各一套）。
 */

/** 页面左右安全内边距（与底部悬浮导航栏侧边距保持一致） */
export const PAGE_PADDING: number = 16;

/** 卡片内边距 */
export const CARD_PADDING: number = 16;

/** 卡片圆角 */
export const CARD_RADIUS: number = 16;

/** 卡片之间的纵向间距 */
export const CARD_GAP: number = 12;

/** 列表行统一高度（设置行 / 数据行 / 关于行） */
export const ROW_HEIGHT: number = 52;

/** 分割线相对卡片边缘的内缩，与行内文字左边缘对齐 */
export const DIVIDER_INSET: number = 16;

/** 底部悬浮导航栏占位高度（56 栏高 + 8 底距），页面内容底部需预留 */
export const BAR_RESERVED: number = 64;

/** 内容区底部留白：躲开悬浮导航栏，保证最后一个卡片/按钮完整可见 */
export const PAGE_BOTTOM_PADDING: number = BAR_RESERVED + 16;

/** 主按钮最小高度（用 minHeight 而非固定高度，兼容大字号） */
export const BUTTON_MIN_HEIGHT: number = 48;
