# UI 优化记录（第二轮）—— 悬浮底栏与安全边距修复

> 依据《经验书》（Musehroom 复盘）与用户提供的《UI布局Bug.md》逐条修复。
> 验证方式：hvigor 构建 + 真机（5KTUT25424027859，1272×2860px，density 3.5 → 363.4vp）
> `uitest screenCap` / `uitest dumpLayout` 实测，坐标均以 dumpLayout 的物理像素为准。

## 一、问题清单与修复

| # | 问题（用户报告） | 根因 | 修复 |
|---|---|---|---|
| ① | 底栏最右项被截断，右下角多出一个带齿轮的悬浮「设置」圆钮并溢出屏幕右缘 | `HdsTabsFloatingStyle.miniBar` 配置了 `miniBarBuilder`，HdsTabs 把「胶囊栏 + 迷你栏」**并排**布局：胶囊栏被压缩到 x=964 止，迷你栏被挤到 992–1188，标题被压成竖排文字（宽仅 42px）并突破屏幕 | 删除 `miniBar` 配置与 `buildMiniBar()`；本应用不需要「滚动收起为迷你栏」的交互 |
| ② | 「沉浸光感」卡片右侧红色「自适应」被屏幕右缘切断 | 该行是 `Row{ settingRow(...); Text(材质档位标签) }`，`settingRow` 根节点 `width('100%')` 与兄弟节点抢宽度，Row 总宽溢出内容区（实测 Text 到 1160–1272） | 改为语义化卡片：标题 + 副标题在上，四档**等宽分段控件**在下（`layoutWeight(1)`），当前档位靠高亮表达，删掉行尾重复标签 |
| ③ | 卡片内容超出安全边距 / Toggle 右侧被切 | 同一个 `width('100%')` 冲突：`Toggle` 实测在 1166–1272，完全跑到卡片（56–1216）之外 | `settingRow()` 根节点改 `layoutWeight(1)`，文字区弹性、开关保持在卡片内 |
| ④ | 「生物识别解锁」已写「设备不支持」但开关仍像可点 | 只对 `Toggle` 做了 `.enabled()`，整行仍是正常样式 | 新增 `bioToggleEnabled()`（应用锁开 + 已设 PIN + 设备支持），行内 `opacity(0.4)` 置灰，语义与视觉一致 |
| ⑤ | 同级别菜单分割线不统一 | 隐私锁/数据卡 `Divider` 无 margin（全宽贴卡边），关于卡内缩 16 | 统一为 `margin({left: DIVIDER_INSET, right: DIVIDER_INSET})`，与行内文字左边缘对齐 |
| ⑥ | 底栏白色药丸底座右边界被破坏 | 同 ①（迷你栏挤占宽度，胶囊底色被截） | 移除迷你栏后药丸恢复完整居中（实测 `[223,2636][1049,2832]`，左右各 223px 对称） |
| ⑦ | 「沉浸光感 · 低端设备自动降级」太技术化 | 文案问题 | 改为「根据设备性能自动调整视觉效果」 |

## 二、顺带发现的严重问题（本次一并修复）

1. **日历页首屏主操作不可达**：`CalendarHeatmap` 内层 `Grid` 未设高度，默认撑满父容器剩余空间（实测
   `Grid [56,555][1216,2860]`，高 2305px），把图例、三张迷你统计卡、空态和「＋ 记一笔」全部挤出屏幕
   （dumpLayout 里连 Button 节点都不存在）。
   → Grid 显式高度（`rows × 40vp + 行间距`，`CELL_HEIGHT` 常量），页面改为「上半可滚动 + 主按钮常驻底部」，
   底部预留 `PAGE_BOTTOM_PADDING (80vp)` 躲开悬浮栏。
2. **统计页每行只剩第一张卡**：`statCard()` 根节点 `width('100%')`，三张卡各占满整行，后两张被挤出可视区。
   → 改 `layoutWeight(1)`，两行各 3 张卡等分。
3. **Scroll 内容不足一屏时垂直居中**：统计页/记录编辑页顶部出现大片空白。
   → 两处 `Scroll` 补 `.align(Alignment.Top)`。
4. **空态副标题被裁**：文案过长且无左右留白。
   → `EmptyState` 副标题加 `padding(16)` + `lineHeight(18)`，文案精简；`EmptyState` 的装饰 emoji 改为可选参数。

## 三、设计 token（经验书 §2.4）

新增 `entry/src/main/ets/common/DesignTokens.ets`，页面不再散落魔法数字：

```
PAGE_PADDING 16 / CARD_PADDING 16 / CARD_RADIUS 16 / CARD_GAP 12
ROW_HEIGHT 52 / DIVIDER_INSET 16
BAR_RESERVED 64 / PAGE_BOTTOM_PADDING 80 / BUTTON_MIN_HEIGHT 48
```

`Index.ets`、`Settings.ets`、`Stats.ets`、`RecordEdit.ets` 已全部改用 token；
颜色仍只走 `resources/base|dark/element/color.json`（深浅主题各一套），未引入任何硬编码色值。

## 四、图标体系（经验书 §2.4 符号经验）

底栏三项与翻月箭头由 emoji / 文本符号换成 `SymbolGlyph`（选中态用 `fontColor` 变色）：

- 日历 `sys.symbol.calendar`
- 统计 `sys.symbol.square_grid_2x2`（SDK 符号表 `sysResource.js` 中不存在 `chart_bar`，编译期报
  `Unknown resource name 'chart_bar'`，故改用语义相近的九宫格）
- 设置 `sys.symbol.gearshape`
- 翻月 `sys.symbol.chevron_left` / `sys.symbol.chevron_right`，热区由 26sp 文本改为 36×36

> 符号名可用性以 `$DEVECO/sdk/default/openharmony/ets/build-tools/ets-loader/sysResource.js`
> 的 `symbol: { ... }` 段（3846 条）为准，不要凭印象写名字。

## 五、点击「跟手性」与转场（第三批改动）

用户反馈：点 Tab 后高亮不跟手、标题和内容"生硬闪现"。

**根因**：`HdsTabs` 的两个回调语义不同——`onSelected` 在**切换动画开始时**触发，
`onChange` 在**动画结束后**才触发。旧代码只在 `onChange` 里改 `currentTab`，
于是高亮/标题永远慢一个动画周期（150ms），点击与反馈之间就有了断层。

**改法**（`pages/Index.ets`）：

1. 点击走 `selectTab(idx)`：先**同步**置 `currentTab`（高亮、标题同一帧切换），再驱动
   `tabsController.changeIndex(idx)` 做内容位移。
2. 内容过渡：`@State contentAlpha / contentOffsetY`，切换瞬间置 `0.86 / 6vp`，
   下一帧用 `animateTo({ duration: 220, curve: Curve.FastOutSlowIn })` 回到 `1 / 0`，
   三页根容器统一挂 `.opacity().translate()`——淡入 + 轻微上浮，掩盖内容重建的一帧。
3. 防连点：`lastTabSwitchMs` + 120ms 冷却，且 `idx === currentTab` 直接返回。
4. `onSelected` 兜住手势滑动（滑动不走 `selectTab`），`onChange` 只做状态兜底。
5. 数据与渲染解耦：`statsTick++` 从 `onChange` 移进 `refresh()`——切 Tab 不再触发任何读库，
   只有数据真的变了才通知统计页重算。
6. `.cachedMaxCount(3, TabsCacheMode.CACHE_BOTH_SIDE)`：已构建过的页面保持存活，
   来回切换不再重建（实测启动时仍只有日历页节点，说明 ArkUI 不会预构建 TabContent，
   该 API 只保证"不被销毁"）。

> 关于"预加载"：HdsTabs 没有公开的预构建接口，`TabContent` 仍按需构建。本应用数据全在本地
> SQLite（6 条记录），`getAll()` 是毫秒级，加上页面驻留与淡入过渡，首帧观感已经连贯，
> 没有再引入 prefetch 机制的必要。

## 六、另一个真 Bug：统计数字恒为 0（已修）

- 现象：日历页「今日/本月/连续」与统计页六张卡全部显示 0，但**趋势图数字是对的**。
- 定位：`StatsPage.load()` 里打 `hilog` 探针，输出 `n=6 / month=2 / total=6`——数据与计算都没问题。
- 根因：ArkUI 的 `@Builder` **参数按值传递**，`statCard(title, value, unit)`、
  `statMini(title, value, unit)` 把数值当参数传进 builder，`load()` 异步返回后 `@State` 变了，
  builder 内部那棵子树却不会重建，于是永远停在初始值 0。趋势图是 `@Component + @Prop`，所以正常。
- 修复：抽出 `components/StatTile.ets`（`@Component` + `@Prop title/value/unit`），
  两个页面共用；`layoutWeight(1)` 放在组件根节点，仍能参与父 `Row` 的等分布局。
- 验收：统计页 `本月次数 2 / 当前连续 1 / 总次数 6 / 最长间隔 37 天 / 平均间隔 15.8 天 / 距上次 0 天`；
  日历页 `今日 2 次 / 本月 2 次 / 连续 1 天`，与数据库一致。

## 七、验收

- `hvigorw assembleHap` BUILD SUCCESSFUL；无未使用 import / 无未使用组件（删除死代码 `components/PageHeader.ets`）。
- 真机走查：日历 / 统计 / 设置 / 记录编辑 / 日期详情面板 / PIN 面板，截图见 `docs/screenshots/`。
- 底栏实测：`TabBar [223,2636][1049,2832]`，三个 tab 均分（各 71vp），无溢出、无重复入口。
- 设置页实测：`Toggle` 回到卡片内容区内（行内 112–1160），「自适应」不再被切。
- Tab 交互实测：连续快速点击 日历→设置→日历→设置→统计，最终落在统计页且标题、高亮一致；
  手势左滑从统计到设置，标题同步为「设置」。

## 八、已知遗留

- 深色模式未在真机切换验证（系统侧无可用 shell 开关）；所有配色均取自双主题 token，风险低，
  但建议在系统「设置 → 显示和亮度 → 深色模式」下各页走查一遍。
- 底栏采用系统默认浮动药丸宽度（约 236vp，居中）。若希望与卡片同宽（331vp），可在
  `barFloatingStyle()` 里加 `barWidth: { smallWidth: 'calc(100% - 32vp)' }`——实测该写法当前会被
  忽略（TabBar 仍为全宽 0–1272），需要后续确认 HDS 的取值语义。
