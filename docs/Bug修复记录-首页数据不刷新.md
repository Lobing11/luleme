# Bug 修复记录 —— 首页不显示「今天之前」的记录

> 用户反馈：**「今天之前的记录在首页不能正常显示」**。
> 验证环境：真机 5KTUT25424027859（1272×2860px），系统时间 2026-10-25 10:3x（CST），
> 构建 `hvigorw assembleHap --mode module -p product=default -p buildMode=debug` → BUILD SUCCESSFUL。

## 一、真机复现（修复前）

| 步骤 | 现象 |
|---|---|
| 首页点 10-23 → 详情面板「添加一条记录」→ 保存 | toast「已记录」，自动弹栈回首页 |
| 回到首页 | 仍是 **今日 0 / 本月 0 / 连续 0**，23 号格子无高亮、无计数，空态「还没有记录」照旧 |
| 再点 23 号 | 详情面板依旧「暂无记录」（读到的是旧的 `this.records`） |
| 切到「统计」再切回「日历」 | 截图与切前**逐字节相同**（sha256 一致），切 Tab 也不刷新 |
| `aa force-stop` 后重启 | 23 号=1、25 号=3，今日 3 / 本月 4 —— **数据其实已经落库，只是首页从不刷新** |

结论：不是「历史日期存错了」，而是**首页读库的时机缺失**。补记历史日期后看起来就像「今天之前的记录不显示」。

## 二、根因一：首页只在 `aboutToAppear` / `onPageShow` 读库

`entry/src/main/ets/pages/Index.ets` 的 `refresh()` 原来只被这两处调用。而新增/编辑页是
Navigation 里的 **NavDestination**（`pushPathByName(ROUTE_RECORD_EDIT, param)`），
`RecordEdit` 保存后调用 `pathStack.pop()` 只是把 NavDestination 弹掉，
**@Entry 页的 `onPageShow` 不会重新触发**，于是整个首页停留在进入详情前的那一版。

第二轮改动把 `statsTick++` 从 HdsTabs 的 `onChange` 移进了 `refresh()`（为了「切 Tab 不读库」），
也顺带删掉了最后一个间接刷新点，所以连切 Tab 也无法自愈。

### 根因二：初始化竞态被空 catch 吞掉

`entry/src/main/ets/entryability/EntryAbility.ets:19` 是 `RecordRepository.getInstance().init(this.context);`
——**发了不等**。而 `Index.aboutToAppear()` 紧接着就 `refresh()`：若 `getRdbStore` 还没返回，
`requireStore()` 直接 `throw new Error('RecordRepository not initialized')`，
而 `refresh()` 里是 `catch (err) {}` 空实现，异常被静默吞掉 → 冷启动可能整页 0 / 空态，日志里毫无线索。

## 三、修复：写库广播 + 初始化 Promise 化

### A. `entry/src/main/ets/data/RecordRepository.ets`

1. **变更广播**：新增 `export type RecordsChangedHandler = () => void;`，`add/update/remove/clearAll`
   写成功后统一 `notifyChanged()`（先 `listeners.slice()` 快照再遍历，避免回调内取消订阅导致错位），
   配套 `subscribe()/unsubscribe()`。所有写入口（新增、编辑、删除、清空、导入）因此天然统一。
2. **初始化 Promise 化**：`init()` 缓存 `initPromise`，`requireStore()` 改成 `async`，句柄未就绪时
   先 `await this.initPromise`，仍为空才抛错 —— 「谁先读库」不再有竞态。

### B. `entry/src/main/ets/pages/Index.ets`

```ts
// Index.ets:77-97
private onRecordsChanged: () => void = () => { this.refresh(); };
aboutToAppear() { … subscribe(this.onRecordsChanged); this.refresh(); … }
aboutToDisappear() { … unsubscribe(this.onRecordsChanged); }
```

- `selectTab(idx)`（Index.ets:292-295）与 `onSelected`（Index.ets:627）在**回到日历 Tab** 时补一次 `refresh()`，
  兜住「在设置页清空/导入后返回日历」（手势滑动切 Tab 也走这条）。
- `refresh()` 的 `catch` 不再空实现：`console.error('[Index] refresh failed: ' + e.message)`。

## 四、顺带修掉同源 Bug：编辑页把日期显示成「今天」

验证修复时发现：从 10-22 记录的「编辑」进入，**页面显示 2026年10月25日 10:4x**（即打开页面的那一秒），
而记录本身是 22 日 12:00。`hilog` 探针证明 `getById` 读到的 `ts` 正确、`dateMs` 也已赋值正确，
只是**界面没重绘**。

根因还是 @Builder 入参按值传递：

```ts
// 修复前
this.settingRow('日期', this.dateLabel(), () => { this.pickDate(); })   // 字符串被固化在子树里
@Builder settingRow(label: string, value: string, action: () => void) { … Text(value) … }
```

`dateLabel()` 在 @Builder 调用时求值一次，之后 `dateMs` 变化不会再重算，于是日期/时间永远停在首帧。
（与第二轮「统计数字恒为 0」同一个坑，只是发生在 @Builder 参数上。）

修复：拆成**零参 @Builder**、内部直接读 @State ——

```ts
// RecordEdit.ets: 日期/时间两行
@Builder dateRow() { Row() { … Text(this.dateLabel()) … }.onClick(() => { this.pickDate(); }) }
@Builder timeRow() { Row() { … Text(this.timeLabel()) … }.onClick(() => { this.pickTime(); }) }
```

同一个坑一并处理了 `entry/src/main/ets/pages/Settings.ets:407/422`：`应用锁` 与 `生物识别解锁` 的副标题
原本把 `this.hasPin ? … : …` / `this.bioDesc()` 当参数传进 `settingRow(title, desc)`，
必然停在首帧（设置完 PIN 仍显示「未设置 PIN」）。现在改为 `lockSettingRow()` / `bioSettingRow()`
两个零参 @Builder，原文案逻辑不变。

## 五、修复后验证（真机）

| 场景 | 期望 | 实测 |
|---|---|---|
| 冷启动 | 历史记录可见 | 20=1、23=1、25=3，今日 3 / 本月 5 / 连续 1（无需重启） |
| 20 号面板「添加一条记录」保存 | 首页立即变化 | 20 号=2、本月 6 次 |
| 面板内删除 | 首页立即回落 | 20 号=1、本月 6，面板列表同步 |
| 「＋ 记一笔」（今天） | 今日计数刷新 | 25 号=4、今日 4 次、本月 6，空态消失 |
| 22 号记录「编辑」→ 改心情 → 保存 | 日期保持 22 号 | 面板显示 10-22 12:00 + 😌；首页 22=1、本月不变（未被挪到今天） |
| 编辑页日期栏 | 显示记录真实时间 | 2026年10月22日 / 12:00（修复前显示 2026年10月25日 / 当前时刻） |
| 切到 2026 年 9 月 | 跨月记录可见 | 9/5=1、9/18=1，本月 2 次，网格重排正确 |
| 统计页 | 与日历一致 | 总次数 10（8 月 2、9 月 2、10 月 6），趋势图三柱一致 |
| 日历→统计→设置→日历 | 不丢数据、不重影 | 往返后截图 sha256 与离开前一致 |
| `hilog` | 无新增异常 | 仅既有 `HDS_tabs ParseProp failed parse property barSideMargin/barBottomMargin` |

## 六、已知遗留

1. `HDS_tabs: ParseProp failed parse property barSideMargin / barBottomMargin`：UIDesignKit 浮动栏对这两个
   属性的解析告警（既有问题，本轮未动 `barFloatingStyle`），底栏实际渲染正常。
2. 「清空全部记录」与 PIN 设置流程会经由同一个 `notifyChanged()` / 状态机制刷新，
   但为避免破坏测试数据与锁状态，未在真机执行这两个破坏性流程。
3. 首页在**跨零点**时不会自动把「今日」翻页（需要一次交互或回到前台）；如有需要可加前台计时器。
4. 备注输入框（TextInput 的 `text` 参数）在编辑已有备注的记录时依赖组件参数更新，
   本次未构造带备注的记录专门验证。
