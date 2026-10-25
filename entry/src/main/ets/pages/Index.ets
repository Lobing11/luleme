import { Record } from '../model/RecordModel';
import { moodEmoji, formatDateTime } from '../model/RecordModel';
import { RecordRepository } from '../data/RecordRepository';
import { SettingsStore } from '../data/SettingsStore';
import { CalendarHeatmap } from '../components/CalendarHeatmap';
import { RecordEdit } from './RecordEdit';
import { StatsPage } from './Stats';
import { SettingsPage } from './Settings';
import { LockPage } from './Lock';
import { EmptyState } from '../components/EmptyState';
import { StatTile } from '../components/StatTile';
import { NavIconButton } from '../components/NavIconButton';
import {
  HdsNavigation,
  HdsTabs,
  HdsTabsController,
  hdsMaterial,
  HdsNavigationTitleBarOptions,
  HdsTabsFloatingStyle,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { buildSystemMaterialParams, sanitizeMaterialLevel } from '../common/MaterialConfig';
import {
  ROUTE_RECORD_EDIT,
  ROUTE_LOCK,
  RecordEditParam,
  LOCK_UNLOCKED_KEY,
  HEAT_COLORS
} from '../common/Constants';
import {
  countInMonth,
  countToday,
  currentStreak,
  totalCount,
  recordsOnDay,
  countByDayOfMonth
} from '../logic/StatsCalculator';
import { shiftMonth } from '../logic/CalendarUtil';
import { loadSafeAreaInsets, SafeAreaInsets } from '../common/SafeAreaUtil';
import {
  CARD_GAP,
  CARD_PADDING,
  CARD_RADIUS,
  PAGE_BOTTOM_PADDING,
  PAGE_PADDING
} from '../common/DesignTokens';

@Entry
@Component
struct Index {
  pathStack: NavPathStack = new NavPathStack();
  private tabsController: HdsTabsController = new HdsTabsController();

  @State currentTab: number = 0;
  /** 页面内容切换时的淡入/微位移（由 selectTab 驱动，掩盖新页面首帧构建的开销） */
  @State contentAlpha: number = 1;
  @State contentOffsetY: number = 0;
  /** 上一个 Tab 切换时间戳，用于丢弃连点产生的重复切换 */
  private lastTabSwitchMs: number = 0;
  @State statsTick: number = 0;
  @State insets: SafeAreaInsets = { top: 24, bottom: 16 };
  @State materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;

  @State records: Record[] = [];
  @State viewYear: number = 2025;
  @State viewMonth: number = 0;
  @State monthTotal: number = 0;
  @State todayTotal: number = 0;
  @State streak: number = 0;
  @State grandTotal: number = 0;

  @State showDaySheet: boolean = false;
  @State sheetDateMs: number = 0;
  @State sheetTitle: string = '';
  @State sheetRecords: Record[] = [];

  /**
   * 记录变更回调：任何页面（新增 / 编辑 / 删除 / 清空 / 导入）写库后都会广播，
   * 首页在这里重读数据。之前没有这条通道，弹栈回首页时 onPageShow 不会触发，
   * 日历热力图和今日/本月/连续三个数字就永远停在进入详情前的那一版。
   */
  private onRecordsChanged: () => void = () => {
    this.refresh();
  };

  aboutToAppear(): void {
    const now = new Date();
    this.viewYear = now.getFullYear();
    this.viewMonth = now.getMonth();
    RecordRepository.getInstance().subscribe(this.onRecordsChanged);
    this.refresh();
    this.loadInsets();
  }

  aboutToDisappear(): void {
    RecordRepository.getInstance().unsubscribe(this.onRecordsChanged);
  }

  private async loadInsets(): Promise<void> {
    this.insets = await loadSafeAreaInsets(this.getUIContext());
  }

  onPageShow(): void {
    this.refresh();
    this.checkLock();
    this.loadMaterialLevel();
  }

  private async loadMaterialLevel(): Promise<void> {
    const stored = await SettingsStore.getInstance().getMaterialLevel();
    this.materialLevel = sanitizeMaterialLevel(stored);
  }

  private async checkLock(): Promise<void> {
    const enabled = await SettingsStore.getInstance().isLockEnabled();
    if (!enabled) {
      return;
    }
    const unlocked = AppStorage.get<boolean>(LOCK_UNLOCKED_KEY) ?? false;
    if (!unlocked) {
      this.pathStack.pushPathByName(ROUTE_LOCK, null, false);
    }
  }

  private async refresh(): Promise<void> {
    try {
      const all = await RecordRepository.getInstance().getAll();
      this.records = all;
      this.recomputeStats();
      // 数据变了才通知统计页重算；切换 Tab 本身不再触发任何数据读取
      this.statsTick++;
    } catch (err) {
      // 读库失败时保留上一版数据，但要把原因留在日志里
      // （此前这里是空 catch，初始化竞态被静默吞掉，排查时没有任何线索）
      const e = err as Error;
      console.error(`[Index] refresh failed: ${e.message}`);
    }
  }

  private recomputeStats(): void {
    const now = Date.now();
    this.monthTotal = countInMonth(this.records, this.viewYear, this.viewMonth);
    this.todayTotal = countToday(this.records, now);
    this.streak = currentStreak(this.records, now);
    this.grandTotal = totalCount(this.records);
  }

  private todayDayOfView(): number {
    const now = new Date();
    if (now.getFullYear() === this.viewYear && now.getMonth() === this.viewMonth) {
      return now.getDate();
    }
    return 0;
  }

  private monthLabel(): string {
    return `${this.viewYear}年${this.viewMonth + 1}月`;
  }

  private prevMonth(): void {
    const m = shiftMonth(this.viewYear, this.viewMonth, -1);
    this.viewYear = m.year;
    this.viewMonth = m.month;
    this.recomputeStats();
  }

  private nextMonth(): void {
    const now = new Date();
    if (this.viewYear === now.getFullYear() && this.viewMonth === now.getMonth()) {
      return;
    }
    const m = shiftMonth(this.viewYear, this.viewMonth, 1);
    this.viewYear = m.year;
    this.viewMonth = m.month;
    this.recomputeStats();
  }

  private dayCountsOfView(): Map<number, number> {
    return countByDayOfMonth(this.records, this.viewYear, this.viewMonth);
  }

  /**
   * 把「日 → 次数」的 Map 摊平成下标数组（0 号位留空），供 @Prop 传参。
   * @Prop 对 Map 的深拷贝不可靠，数组能保证换月时网格一定拿到新数据。
   */
  private dayCountsArray(): number[] {
    const counts: number[] = new Array<number>(32).fill(0);
    const map = this.dayCountsOfView();
    map.forEach((value: number, key: number) => {
      if (key >= 1 && key <= 31) {
        counts[key] = value;
      }
    });
    return counts;
  }

  private onDayTap(day: number): void {
    const d = new Date(this.viewYear, this.viewMonth, day, 0, 0, 0, 0);
    const dayStart = d.getTime();
    this.sheetDateMs = dayStart;
    this.sheetTitle = `${this.viewYear}年${this.viewMonth + 1}月${day}日`;
    this.sheetRecords = recordsOnDay(this.records, dayStart);
    this.showDaySheet = true;
  }

  private addRecord(): void {
    const param: RecordEditParam = {};
    this.pathStack.pushPathByName(ROUTE_RECORD_EDIT, param);
  }

  private addForSheetDate(): void {
    const param: RecordEditParam = { date: this.sheetDateMs };
    this.showDaySheet = false;
    this.pathStack.pushPathByName(ROUTE_RECORD_EDIT, param);
  }

  private editRecord(id: number): void {
    this.showDaySheet = false;
    const param: RecordEditParam = { id: id };
    this.pathStack.pushPathByName(ROUTE_RECORD_EDIT, param);
  }

  private confirmDelete(id: number): void {
    this.getUIContext().showAlertDialog({
      title: '删除这条记录？',
      message: '删除后无法恢复',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.color_danger'),
        action: () => {
          this.deleteRecord(id);
        }
      }
    });
  }

  private async deleteRecord(id: number): Promise<void> {
    await RecordRepository.getInstance().remove(id);
    await this.refresh();
    this.sheetRecords = recordsOnDay(this.records, this.sheetDateMs);
    this.getUIContext().getPromptAction().showToast({ message: '已删除' });
  }

  @Builder
  PageMap(name: string) {
    if (name === ROUTE_RECORD_EDIT) {
      RecordEdit()
    } else if (name === ROUTE_LOCK) {
      LockPage()
    }
  }

  private currentTitle(): string {
    if (this.currentTab === 1) {
      return '统计';
    }
    if (this.currentTab === 2) {
      return '设置';
    }
    return '鹿了么';
  }

  /**
   * 底部 Tab 切换（跟手 + 防连点 + 转场）
   *
   * 之前的问题：高亮状态只在 HdsTabs 的 onChange 里更新，而 onChange 是在**切换动画结束后**
   * 才回调的，所以手指点下去到高亮变色之间有一段空窗，主观上就是"点了没反应"。
   * 现在的顺序：
   *   1) 同步改 currentTab —— 同一帧内高亮/标题就变（跟手）；
   *   2) 新内容以略低的透明度和 6vp 位移起帧；
   *   3) 交给 HdsTabs 做内容翻转，下一帧再把透明度/位移动画回正常值（淡入 + 轻微上滑）。
   */
  private selectTab(idx: number): void {
    if (idx === this.currentTab) {
      return;
    }
    const now = Date.now();
    if (now - this.lastTabSwitchMs < 120) {
      return; // 连点冷却：丢弃 120ms 内的重复点击，避免事件排队
    }
    this.lastTabSwitchMs = now;

    this.currentTab = idx;
    this.contentAlpha = 0.86;
    this.contentOffsetY = 6;
    this.tabsController.changeIndex(idx);
    if (idx === 0) {
      // 回到日历时补一次读库：其他 Tab 里清空/导入数据后，日历页也能立刻对齐
      this.refresh();
    }

    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: 220,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.contentAlpha = 1;
        this.contentOffsetY = 0;
      });
    }, 16);
  }

  /** 标题栏沉浸光感（HdsNavigation.titleBar.style） */
  private titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: buildSystemMaterialParams(this.materialLevel)
      },
      content: {
        title: {
          mainTitle: this.currentTitle()
        }
      },
      enableComponentSafeArea: true
    };
  }

  /**
   * 底部悬浮导航沉浸光感（HdsTabs.barFloatingStyle）
   *
   * 注意：这里**不再配置 miniBar**。配置 miniBar 后 HdsTabs 会把「胶囊栏 + 迷你栏」
   * 并排布局，胶囊栏被压缩、迷你栏被推到屏幕右缘之外，导致：
   *   1) 右下角出现第二个齿轮「设置」入口（与胶囊栏重复）；
   *   2) 迷你栏标题被挤压成竖排文字并溢出屏幕（旧版 UI 的显示异常）。
   * 该应用不需要「滚动收起为迷你栏」的行为，故整体移除。
   */
  private barFloatingStyle(): HdsTabsFloatingStyle {
    return {
      barSideMargin: PAGE_PADDING,
      barBottomMargin: 8 + this.insets.bottom,
      systemMaterialEffect: buildSystemMaterialParams(this.materialLevel)
    };
  }

  @Builder
  capsuleItem(icon: Resource, label: string, idx: number) {
    Column({ space: 2 }) {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([this.currentTab === idx ?
          $r('app.color.color_primary') : $r('app.color.color_text_secondary')])
      Text(label)
        .fontSize(11)
        .fontColor(this.currentTab === idx ?
          $r('app.color.color_primary') : $r('app.color.color_text_secondary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .borderRadius(20)
    .backgroundColor(this.currentTab === idx ?
      $r('app.color.color_primary_soft') : Color.Transparent)
    .stateStyles({
      pressed: {
        .backgroundColor($r('app.color.color_press'))
      },
      normal: {
        .backgroundColor(this.currentTab === idx ?
          $r('app.color.color_primary_soft') : Color.Transparent)
      }
    })
    .onClick(() => {
      this.selectTab(idx);
    })
    .accessibilityText(label)
  }

  @Builder
  recordRow(r: Record) {
    Row({ space: 10 }) {
      Text(moodEmoji(r.mood))
        .fontSize(22)
      Column({ space: 2 }) {
        Text(formatDateTime(r.timestamp))
          .fontSize(14)
          .fontColor($r('app.color.color_text_primary'))
        if (r.note.length > 0) {
          Text(r.note)
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button('编辑')
        .fontSize(12)
        .height(36)
        .fontColor($r('app.color.color_primary'))
        .backgroundColor($r('app.color.color_primary_soft'))
        .stateStyles({
          pressed: {
            .backgroundColor($r('app.color.color_press'))
          },
          normal: {
            .backgroundColor($r('app.color.color_primary_soft'))
          }
        })
        .onClick(() => {
          this.editRecord(r.id);
        })
      Button('删除')
        .fontSize(12)
        .height(36)
        .fontColor($r('app.color.color_danger'))
        .backgroundColor($r('app.color.color_card'))
        .border({ width: 1, color: $r('app.color.color_danger') })
        .stateStyles({
          pressed: {
            .backgroundColor($r('app.color.color_press'))
          },
          normal: {
            .backgroundColor($r('app.color.color_card'))
          }
        })
        .onClick(() => {
          this.confirmDelete(r.id);
        })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  daySheet() {
    Column({ space: 8 }) {
      Text(this.sheetTitle)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
      Divider()
        .color($r('app.color.color_border'))
      if (this.sheetRecords.length === 0) {
        // 空态在内容区居中，主按钮始终贴在面板底部
        Column() {
          EmptyState({ title: '暂无记录', desc: '点击下方按钮添加一条记录' })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 4 }) {
          ForEach(this.sheetRecords, (r: Record) => {
            ListItem() {
              this.recordRow(r)
            }
          }, (r: Record) => r.id.toString())
        }
        .layoutWeight(1)
        .width('100%')
      }
      Button('添加一条记录')
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontColor($r('app.color.color_white'))
        .backgroundColor($r('app.color.color_primary'))
        .borderRadius(22)
        .onClick(() => {
          this.addForSheetDate();
        })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor($r('app.color.color_card'))
  }

  build() {
    HdsNavigation(this.pathStack) {
      Stack({ alignContent: Alignment.Bottom }) {
      HdsTabs({ index: this.currentTab, controller: this.tabsController }) {
        TabContent() {
          Column() {
            // 上半部分可滚动：热力图 + 图例 + 迷你统计 + 空态
            Scroll() {
              Column({ space: CARD_GAP }) {
                Column({ space: 8 }) {
                  Row() {
                    Text(this.monthLabel())
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.color_text_primary'))
                    Blank()
                    Row({ space: 4 }) {
                      NavIconButton({
                        icon: $r('sys.symbol.chevron_left'),
                        desc: '上个月',
                        active: true,
                        onTap: () => {
                          this.prevMonth();
                        }
                      })
                      NavIconButton({
                        icon: $r('sys.symbol.chevron_right'),
                        desc: '下个月',
                        active: this.canGoNextMonth(),
                        onTap: () => {
                          this.nextMonth();
                        }
                      })
                    }
                  }
                  .width('100%')
                  .height(36)

                  CalendarHeatmap({
                    year: this.viewYear,
                    month: this.viewMonth,
                    dayCounts: this.dayCountsArray(),
                    todayDay: this.todayDayOfView(),
                    onDayTap: (day: number) => {
                      this.onDayTap(day);
                    }
                  })

                  Row({ space: 6 }) {
                    Text('少')
                      .fontSize(12)
                      .fontColor($r('app.color.color_text_secondary'))
                    ForEach(HEAT_COLORS, (c: Resource, idx: number) => {
                      Circle({ width: 10, height: 10 })
                        .fill(c)
                    }, (c: Resource, idx: number) => idx.toString())
                    Text('多')
                      .fontSize(12)
                      .fontColor($r('app.color.color_text_secondary'))
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.End)
                }
                .width('100%')
                .padding(CARD_PADDING)
                .borderRadius(CARD_RADIUS)
                .backgroundColor($r('app.color.color_card'))

                Row({ space: 10 }) {
                  StatTile({ title: '今日', value: this.todayTotal.toString(), unit: '次', tileHeight: 72,
                    valueFontSize: 22 })
                  StatTile({ title: '本月', value: this.monthTotal.toString(), unit: '次', tileHeight: 72,
                    valueFontSize: 22 })
                  StatTile({ title: '连续', value: this.streak.toString(), unit: '天', tileHeight: 72,
                    valueFontSize: 22 })
                }
                .width('100%')

                if (this.grandTotal === 0) {
                  EmptyState({ title: '还没有记录', desc: '点击下方按钮开始记录，点日历格可查看当天详情' })
                    .width('100%')
                }
              }
              .width('100%')
              .padding({ top: 12, bottom: 16 })
            }
            .width('100%')
            .layoutWeight(1)
            .align(Alignment.Top)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)

            // 主操作常驻底部：不再依赖剩余高度，任何屏幕都能点到
            Button('＋ 记一笔')
              .width('100%')
              .constraintSize({ minHeight: 50 })
              .fontSize(17)
              .fontColor($r('app.color.color_white'))
              .backgroundColor($r('app.color.color_primary'))
              .borderRadius(25)
              .margin({ top: 8 })
              .onClick(() => {
                this.addRecord();
              })
              .accessibilityText('记一笔')
          }
          .width('100%')
          .height('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: PAGE_BOTTOM_PADDING })
          .backgroundColor($r('app.color.color_bg'))
          // 切换 Tab 时的淡入 + 轻微上滑，掩盖首帧构建的耗时
          .opacity(this.contentAlpha)
          .translate({ y: this.contentOffsetY })
          .bindSheet($$this.showDaySheet, this.daySheet(), {
            height: 440,
            showClose: true,
            dragBar: true,
            backgroundColor: $r('app.color.color_card')
          })
        }
        .tabBar(this.capsuleItem($r('sys.symbol.calendar'), '日历', 0))

        TabContent() {
          Column() {
            StatsPage({ refreshTick: this.statsTick })
          }
          .width('100%')
          .height('100%')
          .opacity(this.contentAlpha)
          .translate({ y: this.contentOffsetY })
        }
        .tabBar(this.capsuleItem($r('sys.symbol.square_grid_2x2'), '统计', 1))

        TabContent() {
          Column() {
            SettingsPage()
          }
          .width('100%')
          .height('100%')
          .opacity(this.contentAlpha)
          .translate({ y: this.contentOffsetY })
        }
        .tabBar(this.capsuleItem($r('sys.symbol.gearshape'), '设置', 2))
      }
      .barPosition(BarPosition.End)
      .barBackgroundColor(Color.Transparent)
      .barOverlap(true)
      .barFloatingStyle(this.barFloatingStyle())
      .animationDuration(150)
      // 预加载：三个页面首次渲染时就全部构建好，避免首次点「统计」现场构建 Canvas 图表造成卡顿
      .cachedMaxCount(3, TabsCacheMode.CACHE_BOTH_SIDE)
      // onSelected 在切换动画**开始**时回调（onChange 在结束时），用它兜住手势滑动切换的场景
      .onSelected((idx: number) => {
        if (this.currentTab !== idx) {
          const backToCalendar: boolean = idx === 0;
          this.currentTab = idx;
          if (backToCalendar) {
            this.refresh();
          }
        }
      })
      .onChange((idx: number) => {
        // 动画结束：只做状态对齐，不再在这里触发统计页重算（数据变化由 refresh() 通知）
        if (this.currentTab !== idx) {
          this.currentTab = idx;
        }
      })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.color_bg'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .titleBar(this.titleBarOptions())
    .mode(NavigationMode.Stack)
    .navDestination(this.PageMap)
  }

  /** 只有往回看时才允许继续往后翻月（当前月不能再往后） */
  private canGoNextMonth(): boolean {
    const now = new Date();
    return !(this.viewYear === now.getFullYear() && this.viewMonth === now.getMonth());
  }
}
