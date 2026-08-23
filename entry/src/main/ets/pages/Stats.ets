/**
 * 鹿了么 - 统计页（底部标签栏内的标签页）
 *
 * 展示：本月次数 / 当前连续 / 总次数 / 最长间隔 / 平均间隔 / 距上次，
 * 以及近 6 个月趋势柱状图。
 */
import { RecordRepository } from '../data/RecordRepository';
import { Record } from '../model/RecordModel';
import { TrendChart } from '../components/TrendChart';
import {
  MonthCount,
  currentStreak,
  countInMonth,
  countToday,
  totalCount,
  intervalStats,
  daysSinceLast,
  monthCounts
} from '../logic/StatsCalculator';
import { loadSafeAreaInsets, SafeAreaInsets } from '../common/SafeAreaUtil';

@Component
export struct StatsPage {
  /** 父页面切换到此标签时递增，触发重新加载 */
  @Prop @Watch('onTick') refreshTick: number = 0;
  @State insets: SafeAreaInsets = { top: 24, bottom: 16 };

  @State records: Record[] = [];
  @State monthTotal: number = 0;
  @State streak: number = 0;
  @State todayTotal: number = 0;
  @State grandTotal: number = 0;
  @State maxGap: number = 0;
  @State avgGap: number = 0;
  @State sinceLast: number = -1;
  @State trend: MonthCount[] = [];

  aboutToAppear(): void {
    this.load();
    this.loadInsets();
  }

  private async loadInsets(): Promise<void> {
    this.insets = await loadSafeAreaInsets(this.getUIContext());
  }

  onTick(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const now = Date.now();
    const all = await RecordRepository.getInstance().getAll();
    this.records = all;
    const cur = new Date(now);
    this.monthTotal = countInMonth(all, cur.getFullYear(), cur.getMonth());
    this.streak = currentStreak(all, now);
    this.todayTotal = countToday(all, now);
    this.grandTotal = totalCount(all);
    const gaps = intervalStats(all, now);
    this.maxGap = gaps.max;
    this.avgGap = gaps.avg;
    const since = daysSinceLast(all, now);
    this.sinceLast = since === null ? -1 : since;
    this.trend = monthCounts(all, now, 6);
  }

  @Builder
  statCard(title: string, value: string, unit: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(12)
        .fontColor($r('app.color.color_text_secondary'))
      Row({ space: 2 }) {
        Text(value)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
        if (unit.length > 0) {
          Text(unit)
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
        }
      }
    }
    .width('100%')
    .height(88)
    .justifyContent(FlexAlign.Center)
    .borderRadius(16)
    .backgroundColor($r('app.color.color_card'))
  }

  @Builder
  rowCards() {
    Row({ space: 10 }) {
      this.statCard('本月次数', this.monthTotal.toString(), '次')
      this.statCard('当前连续', this.streak.toString(), '天')
      this.statCard('总次数', this.grandTotal.toString(), '次')
    }
    .width('100%')
  }

  build() {
    Column() {
      // 沉浸式头部
      Column() {
        Row() {
          Text('统计')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_primary'))
          Blank()
        }
        .width('100%')
        .height(48)
      }
      .width('100%')
      .padding({ top: this.insets.top })
      .backgroundColor($r('app.color.color_header_bg'))
      .backgroundEffect({
        radius: 20,
        saturation: 1.5,
        brightness: 1.0
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Scroll() {
        Column({ space: 12 }) {
          this.rowCards()
          Row({ space: 10 }) {
            this.statCard('最长间隔', this.maxGap.toString(), '天')
            this.statCard('平均间隔', this.avgGap.toString(), '天')
            this.statCard('距上次', this.sinceLastLabel(), '')
          }
          .width('100%')

          Column({ space: 10 }) {
            Text('近 6 个月趋势')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_text_primary'))
              .width('100%')
            if (this.grandTotal === 0) {
              Column() {
                Text('还没有记录，先去记一笔吧')
                  .fontSize(13)
                  .fontColor($r('app.color.color_text_secondary'))
              }
              .width('100%')
              .height(180)
              .justifyContent(FlexAlign.Center)
            } else {
              TrendChart({ data: this.trend })
            }
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor($r('app.color.color_card'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 64 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg'))
  }

  private sinceLastLabel(): string {
    if (this.sinceLast < 0) {
      return '—';
    }
    if (this.sinceLast === 0) {
      return '今天';
    }
    return this.sinceLast + '天';
  }
}
