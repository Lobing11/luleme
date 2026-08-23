/**
 * 鹿了么 - 首页
 *
 * 底部标签栏（日历 / 统计 / 设置）+ 沉浸式光感：
 * 顶部头部扩展到状态栏（毛玻璃），底部标签栏毛玻璃并延伸到手势导航条。
 * 路由：RecordEdit / Lock 通过 Navigation 压栈。
 */
import { Record } from '../model/RecordModel';
import { moodEmoji, formatDateTime } from '../model/RecordModel';
import { RecordRepository } from '../data/RecordRepository';
import { SettingsStore } from '../data/SettingsStore';
import { CalendarHeatmap } from '../components/CalendarHeatmap';
import { RecordEdit } from './RecordEdit';
import { StatsPage } from './Stats';
import { SettingsPage } from './Settings';
import { LockPage } from './Lock';
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

@Entry
@Component
struct Index {
  pathStack: NavPathStack = new NavPathStack();
  private tabsController: TabsController = new TabsController();

  @State currentTab: number = 0;
  @State statsTick: number = 0;
  @State insets: SafeAreaInsets = { top: 24, bottom: 16 };

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

  aboutToAppear(): void {
    const now = new Date();
    this.viewYear = now.getFullYear();
    this.viewMonth = now.getMonth();
    this.refresh();
    this.loadInsets();
  }

  private async loadInsets(): Promise<void> {
    this.insets = await loadSafeAreaInsets(this.getUIContext());
  }

  onPageShow(): void {
    this.refresh();
    this.checkLock();
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
    } catch (err) {
      // 数据库未初始化等异常，静默处理
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

  /** 沉浸式头部：扩展到状态栏 + 毛玻璃光感 */
  @Builder
  HeaderBar() {
    Column() {
      Row() {
        Text('鹿了么')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
        Blank()
        Text('统计')
          .fontSize(14)
          .fontColor(this.currentTab === 1 ?
            $r('app.color.color_primary') : $r('app.color.color_text_secondary'))
          .padding({ left: 14, right: 8, top: 8, bottom: 8 })
          .onClick(() => {
            this.tabsController.changeIndex(1);
          })
        Text('设置')
          .fontSize(14)
          .fontColor(this.currentTab === 2 ?
            $r('app.color.color_primary') : $r('app.color.color_text_secondary'))
          .padding({ left: 14, right: 8, top: 8, bottom: 8 })
          .onClick(() => {
            this.tabsController.changeIndex(2);
          })
      }
      .width('100%')
      .height(54)
    }
    .width('100%')
    .padding({ top: this.insets.top })
    .backgroundColor($r('app.color.color_header_bg'))
    // 沉浸式光感：背景光效（模糊半径 + 饱和度 + 亮度），比 backgroundBlurStyle 更通透
    .backgroundEffect({
      radius: 20,          // 模糊半径，越大越朦胧
      saturation: 1.5,     // 饱和度 >1 时透出背景更鲜艳（光感）
      brightness: 1.0
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /** Tabs 自身的透明标签（不可见，仅占位，交互交给悬浮胶囊） */
  @Builder
  InvisibleTabCell(idx: number) {
    Column()
      .width('100%')
      .height('100%')
  }

  /** 悬浮胶囊里的标签项 */
  @Builder
  capsuleItem(icon: string, label: string, idx: number) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(20)
      Text(label)
        .fontSize(10)
        .fontColor(this.currentTab === idx ?
          $r('app.color.color_primary') : $r('app.color.color_text_secondary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .borderRadius(20)
    .backgroundColor(this.currentTab === idx ?
      $r('app.color.color_primary_soft') : Color.Transparent)
    .onClick(() => {
      this.tabsController.changeIndex(idx);
    })
  }

  @Builder
  statMini(title: string, value: number, unit: string) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(12)
        .fontColor($r('app.color.color_text_secondary'))
      Row({ space: 2 }) {
        Text(value.toString())
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
        Text(unit)
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
      }
    }
    .layoutWeight(1)
    .height(72)
    .justifyContent(FlexAlign.Center)
    .borderRadius(14)
    .backgroundColor($r('app.color.color_card'))
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
        .height(30)
        .fontColor($r('app.color.color_primary'))
        .backgroundColor($r('app.color.color_primary_soft'))
        .onClick(() => {
          this.editRecord(r.id);
        })
      Button('删除')
        .fontSize(12)
        .height(30)
        .fontColor($r('app.color.color_danger'))
        .backgroundColor($r('app.color.color_card'))
        .border({ width: 1, color: $r('app.color.color_danger') })
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
        Column() {
          Text('这一天没有记录')
            .fontSize(13)
            .fontColor($r('app.color.color_text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
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
    .backgroundColor($r('app.color.color_bg'))
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Bottom }) {
      Tabs({ barPosition: BarPosition.End, index: this.currentTab, controller: this.tabsController }) {
        // 标签 1：日历
        TabContent() {
          Column() {
            this.HeaderBar()

            // 日历卡片
            Column({ space: 8 }) {
              Row() {
                Text(this.monthLabel())
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.color_text_primary'))
                Blank()
                Text('‹')
                  .fontSize(26)
                  .fontColor($r('app.color.color_text_secondary'))
                  .padding({ left: 14, right: 14 })
                  .onClick(() => {
                    this.prevMonth();
                  })
                Text('›')
                  .fontSize(26)
                  .fontColor($r('app.color.color_text_secondary'))
                  .padding({ left: 14, right: 14 })
                  .enabled(this.isCurrentMonth())
                  .opacity(this.isCurrentMonth() ? 1 : 0.3)
                  .onClick(() => {
                    this.nextMonth();
                  })
              }
              .width('100%')

              CalendarHeatmap({
                year: this.viewYear,
                month: this.viewMonth,
                dayCounts: this.dayCountsOfView(),
                todayDay: this.todayDayOfView(),
                onDayTap: (day: number) => {
                  this.onDayTap(day);
                }
              })

              Row({ space: 6 }) {
                Text('少')
                  .fontSize(11)
                  .fontColor($r('app.color.color_text_secondary'))
                ForEach(HEAT_COLORS, (c: Resource, idx: number) => {
                  Circle({ width: 10, height: 10 })
                    .fill(c)
                }, (c: Resource, idx: number) => idx.toString())
                Text('多')
                  .fontSize(11)
                  .fontColor($r('app.color.color_text_secondary'))
              }
              .width('100%')
              .justifyContent(FlexAlign.End)
            }
            .width('100%')
            .padding(16)
            .margin({ top: 12, left: 16, right: 16 })
            .borderRadius(16)
            .backgroundColor($r('app.color.color_card'))

            // 当月概览
            Row({ space: 10 }) {
              this.statMini('今日', this.todayTotal, '次')
              this.statMini('本月', this.monthTotal, '次')
              this.statMini('连续', this.streak, '天')
            }
            .width('100%')
            .margin({ top: 12, left: 16, right: 16 })

            if (this.grandTotal === 0) {
              Column({ space: 6 }) {
                Text('还没有记录')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.color_text_primary'))
                Text('点击下方「记一笔」开始，点击日历上的日期可查看详情')
                  .fontSize(12)
                  .fontColor($r('app.color.color_text_secondary'))
                  .textAlign(TextAlign.Center)
              }
              .width('100%')
              .margin({ top: 24, left: 16, right: 16 })
            }

            Blank()
              .layoutWeight(1)

            Button('＋ 记一笔')
              .width('100%')
              .height(50)
              .fontSize(17)
              .fontColor($r('app.color.color_white'))
              .backgroundColor($r('app.color.color_primary'))
              .borderRadius(25)
              // 内容延伸到栏下后，底部留出胶囊的高度，避免按钮被胶囊遮挡
              .margin({ left: 16, right: 16, bottom: 64 })
              .onClick(() => {
                this.addRecord();
              })
          }
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.color_bg'))
          .bindSheet($$this.showDaySheet, this.daySheet(), {
            height: 440,
            showClose: true,
            dragBar: true,
            backgroundColor: $r('app.color.color_bg')
          })
        }
        .tabBar(this.InvisibleTabCell(0))

        // 标签 2：统计
        TabContent() {
          StatsPage({ refreshTick: this.statsTick })
        }
        .tabBar(this.InvisibleTabCell(1))

        // 标签 3：设置
        TabContent() {
          SettingsPage()
        }
        .tabBar(this.InvisibleTabCell(2))
      }
      .barHeight(54)

      .barBackgroundColor(Color.Transparent)
      // 内容延伸到栏下（沉浸式），配合悬浮胶囊使用
      .barOverlap(true)
      // 即时切换：去掉默认滑动动画，避免切换时掉帧卡顿
      .animationDuration(150)
      .onChange((idx: number) => {
        this.currentTab = idx;
        if (idx === 1) {
          // 等切换动画播完再刷新统计，避免与动画抢帧
          setTimeout(() => {
            this.statsTick++;
          }, 220);
        }
      })

      // 悬浮胶囊标签栏：覆盖在底部，四周留白 + 毛玻璃光感 + 阴影
      Row() {
        Row({ space: 4 }) {
          this.capsuleItem('🗓️', '日历', 0)
          this.capsuleItem('📊', '统计', 1)
          this.capsuleItem('⚙️', '设置', 2)
        }
        .height(46)
        .padding({ left: 8, right: 8 })
        .borderRadius(23)
        .backgroundColor($r('app.color.color_tabbar_bg'))
        .backgroundEffect({
          radius: 20,
          saturation: 1.5,
          brightness: 1.0
        })
        .shadow({
          radius: 18,
          color: '#33000000',
          offsetX: 0,
          offsetY: 6
        })
        .margin({ left: 24, right: 24 })
      }
      .width('100%')
      .margin({ bottom: 8 + this.insets.bottom })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.color_bg'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .mode(NavigationMode.Stack)
    .navDestination(this.PageMap)
  }

  private isCurrentMonth(): boolean {
    const now = new Date();
    return !(this.viewYear === now.getFullYear() && this.viewMonth === now.getMonth());
  }
}
