# 鹿了么 · UI 升级改造计划（可执行版）

> 本文档为**独立任务说明书**，供另一个开发 Agent 直接执行。
> 前置条件：持有本仓库代码（HarmonyOS ArkTS 工程，入口 `entry/src/main/ets`）。
> 目标：在不改动数据层/逻辑层的前提下，完成一轮 UI 体验升级。
> 本文所有"当前代码"引用均以本仓库当前 HEAD 为准；如代码已变，按「关键词」定位。

---

## 0. 背景与总体目标

「鹿了么」是一个本地记录类应用（日历热力图 + 统计 + 设置 + 隐私锁），当前 UI 的三大问题：

1. **导航冗余**：首页头部右侧有"统计/设置"文字入口，与底部胶囊 Tab 完全重复。
2. **交互手感差**：大量"文本/容器当按钮"的可点元素没有按压反馈（无 ripple/pressed 态），触控目标偏小。
3. **一致性欠缺**：三页头部不统一、趋势图颜色硬编码不随深色模式、统计卡片度量格式不统一、空状态文案三处不一致。

**硬性约束（违反即返工）**

- 只允许改 UI 层：`pages/`、`components/`、`resources/`、`common/Constants.ets`。
- **禁止修改**：`data/`（RecordRepository/SettingsStore）、`logic/`（StatsCalculator/CalendarUtil/SecurityUtil，含其单元测试）、`model/RecordModel.ets` 的接口结构、`EntryAbility.ets` 的沉浸式窗口逻辑。
- 遵循 ArkTS 严格模式：不允许 `any`、对象字面量必须带类型、回调参数必须写类型。
- 颜色一律走 `color.json` 资源（深浅两套都要改/新增），除 Canvas 绘制的特殊情况外禁止硬编码色值。
- 必须同时考虑**浅色/深色**两套主题；保留现有沉浸式（全屏 + `backgroundEffect` 毛玻璃 + `expandSafeArea`）方案。
- 完成后必须能通过编译（DevEco Studio 构建或 `hvigor`），不得引入未使用变量导致 linter 报错。

---

## 1. 改动清单（按优先级）

### P0-A 统一三页头部，删除首页重复入口

**文件**：`entry/src/main/ets/pages/Index.ets`

**现状**（约 200–239 行 `HeaderBar()` Builder）：首页头部 = 左侧"鹿了么"标题 + 右侧"统计""设置"两个 `Text` 可点入口；而底部胶囊 Tab（约 530–554 行）已有完全相同功能的"统计/设置"。

**改法**：

1. 删除 `HeaderBar()` 中右侧两个 `Text('统计')` / `Text('设置')` 及其 `onClick`，只保留左侧标题，右侧留空（或放一个当前月份徽标等装饰，不做导航功能）。
2. 将改造后的头部与 `Stats.ets`（约 106–125 行）、`Settings.ets`（约 382–401 行）的头部结构统一为同一套：
   - 高度统一为 48（`Stats`/`Settings` 已是 48，首页当前是 54，统一为 48）；
   - 背景 `color_header_bg` + `backgroundEffect({ radius: 20, saturation: 1.5, brightness: 1.0 })` + `expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])` 三者保持一致。
3. **可选（推荐）**：把头部抽成公共 Builder 或独立组件（如 `components/PageHeader.ets`，props：标题文字），三页复用，杜绝再次分叉。

**验收**：首页/统计/设置三页顶部视觉与行为一致；首页不再出现"统计/设置"文字入口；底部胶囊仍可正常切换 Tab。

---

### P0-B 全量补按压反馈与触控热区

原则：**凡是可点击元素，必须有可见的按压态**。ArkTS 实现方式：`.stateStyles({ pressed: ..., normal: ... })`（背景色/缩放变化），或改用 `Button`。文字类元素（非 Button）用 `stateStyles` 改背景色即可。

**改动点清单（文件 + 位置 + 做法）**

| 位置 | 当前代码特征 | 做法 |
| --- | --- | --- |
| `pages/Index.ets` 月份切换箭头 `‹`/`›`（约 398–413 行） | `Text` + `.onClick`，padding 14 | 加 `.stateStyles`：pressed 时背景 `color_primary_soft`、圆角 8；同时把 padding 增大到 16~18 扩大热区 |
| `components/CalendarHeatmap.ets` 日历格子（约 42–69 行） | `Column` + `.onClick` | 加 `.stateStyles`：pressed 背景加深一档（可用 `color_primary_soft` 或透明度遮罩）、缩放 0.96 |
| `pages/Index.ets` 记录行"编辑/删除"按钮（约 313–329 行） | `Button` 高 30 | 高度提到 **36**，删除按钮加 pressed 变色（`stateStyles`）；行内间距保持 |
| `pages/Index.ets` 胶囊 Tab 项（约 251–269 行 `capsuleItem`） | `Column` + `.onClick` | 加 `.stateStyles`：pressed 背景 `color_primary_soft`（选中态已是该色，可按 `currentTab === idx` 分别给 pressed/normal） |
| `pages/Settings.ets` 各设置行 / 数据行（`settingRow`/`actionRow`/`aboutRow`，约 273–536 行） | `Row` + `.onClick` | 加 `.stateStyles`：pressed 背景 `color_primary_soft` 淡化版（可新增资源 `color_press` = `#1AFF5E7E` 之类的低透明度主色，两套主题都加） |
| `pages/RecordEdit.ets` 日期/时间行（`settingRow`，约 220–240 行） | `Row` + `.onClick` | 同上 |
| `pages/Lock.ets` 数字键（约 85–105 行 `keyView`） | `Text` + `.onClick` | 加 `.stateStyles`：pressed 背景 `color_primary_soft` |

**新增资源建议**（`resources/base/element/color.json` 与 `dark/element/color.json` 同时加）：

```json
{ "name": "color_press", "value": "#14FF5E7E" }        // 浅色：主色 8% 透明
{ "name": "color_press", "value": "#26FF5E7E" }        // 深色：主色 15% 透明
```

**验收**：逐一点击上述元素，均有肉眼可见的按压态；无元素因 `stateStyles` 背景与选中态冲突导致看不清。

---

### P1-A 趋势图颜色走资源 + 深色适配

**文件**：`entry/src/main/ets/components/TrendChart.ets`

**现状**（55–57 行）：

```ts
ctx.fillStyle = '#FF5E7E';   // 柱体，硬编码
ctx.fillStyle = '#8A8A8E';   // 轴文字，硬编码
```

**改法**：Canvas 内不能直接用 `$r()`，需通过 ResourceManager 取色：

1. 在 `draw()` 前取一次颜色（存成员变量，避免每帧查询）：

```ts
import { common } from '@kit.AbilityKit';
private barColor: string = '#FF5E7E';
private labelColor: string = '#8A8A8E';
private colorsLoaded: boolean = false;

private loadColors(): void {
  if (this.colorsLoaded) { return; }
  const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
  const rm = ctx.resourceManager;
  this.barColor = rm.getColorSync($r('app.color.color_primary').id).toString(16).padStart(6, '0');
  this.labelColor = rm.getColorSync($r('app.color.color_text_secondary').id).toString(16).padStart(6, '0');
  this.barColor = '#' + this.barColor;
  this.labelColor = '#' + this.labelColor;
  this.colorsLoaded = true;
}
```

2. 在 `onReady` 与 `onDataChange` 的 `draw()` 调用前执行 `this.loadColors()`。
3. 深色适配：`color_primary` 深浅两套值一致（已是 #FF5E7E），`color_text_secondary` 两套值不同（浅 #8A8A8E / 深 #9E9598），取资源后自动适配；同时将字号 `'10vp sans-serif'` 中的 `vp` 保留，随主题无需改。
4. 主题切换时刷新：若监听 `ConfigurationConstant` 成本高，可接受"重进统计页/切 Tab 时刷新"（`refreshTick` 机制已存在，切 Tab 会重载）；在代码注释中说明该限制。

**注意**：`getColorSync` 返回 ARGB 数值（0xAARRGGBB），转 hex 时**必须丢弃 alpha 前两位**，用 `.toString(16).slice(-6)` 更稳妥。

**验收**：浅色下柱体为主色粉、文字为浅灰；切深色后文字变深色主题的灰，柱体不变；无编译错误。

---

### P1-B 图标体系：Emoji → 矢量资源（至少胶囊 Tab）

**现状**：胶囊 Tab 用 Emoji（`🗓️📊⚙️`，`Index.ets` 约 532–534 行）；月份箭头用文本 `‹`/`›`；设置行箭头用 `›`。Emoji 跨设备渲染不一致、不能随主题变色。

**改法（分两步，先做胶囊）**：

1. 胶囊 Tab 图标替换为矢量资源：
   - 方式 A（推荐，工作量小）：用系统 `SymbolGlyph`（`$r('sys.symbol.calendar')`、`$r('sys.symbol.chart_bar')`、`$r('sys.symbol.gearshape')` 之类），配合 `.fontColor(选中 ? color_primary : color_text_secondary)`，天然支持主题与选中变色。若目标 API 版本不支持 `SymbolGlyph`，改用方式 B。
   - 方式 B：新增 3 组 SVG 资源（`resources/base/media/icon_tab_calendar.svg` 等，需确认工程 SVG 支持；若不支持 SVG，用矢量绘制 `Shape` 组件代替），选中/未选中两态可用颜色属性控制。
2. 月份箭头 `‹`/`›` 与设置行 `›`：本轮**保留文本符号**（成本最低、效果可接受），但按 P0-B 扩大热区并加按压态即可。是否替换为矢量图标列为"可选后续项"，不阻塞本计划。

**验收**：胶囊图标在浅/深色下均清晰，选中态变主色；图标不因系统 Emoji 字体差异走样。

---

### P1-C 日历热力"最高档"与"今天"描边视觉区分

**文件**：`resources/base/element/color.json` + `resources/dark/element/color.json`、`components/CalendarHeatmap.ets`

**问题**：`heat_4` 与 `color_primary` 同值（#FF5E7E），而"今天"格子描边也是主色 1.5px，高热度格与"今天"视觉混淆。

**改法（二选一，推荐 A）**：

- 方案 A：`heat_4` 调深一档，与主色拉开：浅色 `#E84A6C`（或 `#D94062`）、深色 `#E84A6C`（保持统一深粉）。`heat_3` 可相应微调保持渐变连续。
- 方案 B：保留 `heat_4` 不变，把"今天"描边改为深色 `color_text_primary` 或加粗到 2，并在"今天"格子上加一个小圆点标记（`Circle` 组件，位置右上角）。

**验收**：高热度日与"今天"日可一眼区分；渐变档位依然连续可辨。

---

### P2-A 统计卡片度量格式统一

**文件**：`entry/src/main/ets/pages/Stats.ets`

**问题**："本月次数/当前连续/总次数/最长间隔/平均间隔"都是"数字+单位"，唯独"距上次"是 `—`/`今天`/`N天` 无单位（约 172–180 行 `sinceLastLabel`）。

**改法**：

1. 让"距上次"也走"数值+单位"：返回值改为 `{ value: string, unit: string }`，例如 `—`+`''`、`0`+`'天'`（"今天"改为 0 天）、`N`+`'天'`。
2. 若保留"今天"文案，则卡片标题旁加小字说明；**推荐直接统一为数字**，六张卡视觉完全对齐。
3. 同步检查 `statCard`（约 68–91 行）中无单位分支（`unit.length > 0`）是否还需保留，可保留兼容。

**验收**：六张卡全部为"大数字 + 单位"样式，无例外文案。

---

### P2-B 空状态统一组件

**文件**：`pages/Index.ets`（约 457–470 行"还没有记录"）、`pages/Stats.ets`（约 143–151 行"还没有记录，先去记一笔吧"）、`pages/Index.ets` daySheet（约 344–352 行"这一天没有记录"）

**改法**：新建 `components/EmptyState.ets`：

```ts
@Component
export struct EmptyState {
  title: string = '暂无数据';
  desc: string = '';
  build() {
    Column({ space: 8 }) {
      Text('🦌').fontSize(36)
      Text(this.title).fontSize(15).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_primary'))
      if (this.desc.length > 0) {
        Text(this.desc).fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 24, bottom: 24 })
  }
}
```

三处替换为 `<EmptyState title=... desc=... />`（首页空态保留"点击下方「记一笔」"引导语放入 desc）。

**验收**：三处空态视觉一致；文案仍包含原有引导信息。

---

### P2-C 小字号与热区收尾

1. **字号下限**：热力格计数角标 9vp（`CalendarHeatmap.ets` 约 51 行）、胶囊标签 10vp（`Index.ets` 约 256 行）、图例 11vp——统一提到 **10/11/12vp**，并给计数角标加 `maxLines(1)` 防止大字体溢出。
2. **热力格"9+"宽度**：格内计数 `Text` 加 `.constraintSize({ maxWidth: '100%' })` 与 `textOverflow`，避免大字体下撑破格子。
3. **daySheet 背景**：`Index.ets` daySheet 用 `color_bg`（约 378 行），与页面同色、层次弱，改为 `color_card`，并保持 16 圆角（弹层本身已有）。
4. **设置页"隐私说明"排版**：`Settings.ets` 约 469–475 行说明文字紧贴行底，改为独立段落：行高 20、上下 padding 12、与上方 `Divider` 间距 8。

**验收**：系统字体调大 1.5 档后无文字截断/撑破；弹层与页面背景有明确层次；设置页关于区块排版整齐。

---

### P2-D 无障碍（低成本项）

- `components/CalendarHeatmap.ets` 每个格子加 `.accessibilityText('${day}日，${count}次')`（用 `countOf(day)` 拼）。
- `pages/Index.ets` 月份箭头加 `.accessibilityText('上个月'/'下个月')`。
- 胶囊 Tab 项加 `.accessibilityText(label)`。

**验收**：开启无障碍朗读后，关键控件有可读描述。

---

## 2. 执行顺序与任务拆分

建议按以下顺序提交（每个阶段可独立编译、自测，便于回滚）：

1. **阶段 1（P0-A）**：统一头部、删重复入口 —— 纯删改，风险最低。
2. **阶段 2（P0-B）**：全量按压态 + 热区 —— 新增 `color_press` 资源 + 各文件 `.stateStyles`。
3. **阶段 3（P1-A）**：趋势图资源化取色。
4. **阶段 4（P1-B / P1-C）**：胶囊图标矢量资源化；热力档位与"今天"区分。
5. **阶段 5（P2 全部）**：统计卡片统一、空态组件、字号/热区收尾、无障碍。

> 若接手 Agent 时间有限，**阶段 1–2 为必做**，阶段 3–5 可协商裁剪；裁减时保持文档中"验收"口径不变。

---

## 3. 自测与验收清单（每阶段完成后执行）

- [ ] `hvigor` / DevEco Studio 构建通过，无编译错误、无未使用变量警告。
- [ ] Previewer + 真机各跑一遍：首页（含月份切换、点日历弹层、增删记录）、统计页、设置页（开关 PIN 面板、导出/导入弹窗）、锁屏页。
- [ ] 浅色 / 深色（跟随系统）两种模式各过一遍上述路径。
- [ ] 逐项对照第 1 节各改动点的"验收"口径。
- [ ] `logic/StatsCalculator` 等单元测试不受影响（本计划不应触碰，跑一遍确认）。
- [ ] 底部胶囊切换、记录编辑页返回等原有交互无回归。

---

## 4. 风险与注意

1. **`stateStyles` 与 `backgroundEffect` 共存**：头部/胶囊已有毛玻璃，给其内部元素加按压背景时，按压色应加在内容元素上而非毛玻璃容器上，避免模糊叠色发灰。
2. **`getColorSync` 的 ARGB 转 hex**：必须丢 alpha（`toString(16).slice(-6)`），否则 Canvas 颜色带 alpha 会偏透明。
3. **SymbolGlyph 可用性**：先确认工程的 `compatibleSdkVersion`/`targetSdkVersion`（`build-profile.json5`）是否支持；不支持就退到方式 B，不要强行用。
4. **旧文档行号失效**：`docs/调试与修改指南.md` 的行号基于旧版本，本次改动后如有余力，顺手更新该文档中涉及 `Index.ets` 头部/胶囊/日历的行号说明；至少在本计划完成后在文档顶部标注"行号以本次 UI 升级后为准"。
5. **不要顺手重构**：除计划内改动外，不做代码风格、命名、数据流重构，控制 diff 范围，便于 review 与回滚。

---

## 5. 非目标（明确不做）

- 不改数据层/逻辑层/模型结构（含导入导出格式、统计口径）。
- 不引入第三方 UI 库或图标库（保持零依赖）。
- 不做品牌视觉重设计（换主色、改整体风格）。
- 不加新功能页（引导页、登录、云同步等）。
- 不处理既有深色色板"偏暗红棕"的整体重调（可记录为后续议题，本次只保证新改动在深色下可读）。
