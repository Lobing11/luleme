import { RecordRepository } from '../data/RecordRepository';
import { Record } from '../model/RecordModel';
import { TrendChart } from '../components/TrendChart';
import { EmptyState } from '../components/EmptyState';
import { StatTile } from '../components/StatTile';
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
import { CARD_PADDING, CARD_RADIUS, PAGE_BOTTOM_PADDING, PAGE_PADDING } from '../common/DesignTokens';

@Component
export struct StatsPage {
  @Prop @Watch('onTick') refreshTick: number = 0;

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
  rowCards() {
    Row({ space: 10 }) {
      StatTile({ title: '本月次数', value: this.monthTotal.toString(), unit: '次' })
      StatTile({ title: '当前连续', value: this.streak.toString(), unit: '天' })
      StatTile({ title: '总次数', value: this.grandTotal.toString(), unit: '次' })
    }
    .width('100%')
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          this.rowCards()
          Row({ space: 10 }) {
            StatTile({ title: '最长间隔', value: this.maxGap.toString(), unit: '天' })
            StatTile({ title: '平均间隔', value: this.avgGap.toString(), unit: '天' })
            StatTile({ title: '距上次', value: this.sinceLastValue(), unit: this.sinceLastUnit() })
          }
          .width('100%')

          Column({ space: 10 }) {
            Text('近 6 个月趋势')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_text_primary'))
              .width('100%')
            if (this.grandTotal === 0) {
              EmptyState({ title: '暂无数据', desc: '还没有记录，先去记一笔吧' })
            } else {
              TrendChart({ data: this.trend })
            }
          }
          .width('100%')
          .padding(CARD_PADDING)
          .borderRadius(CARD_RADIUS)
          .backgroundColor($r('app.color.color_card'))
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: PAGE_PADDING, bottom: PAGE_BOTTOM_PADDING })
      }
      .width('100%')
      .layoutWeight(1)
      // 内容不足一屏时默认居中会导致上下大片空白，强制顶部对齐
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg'))
  }

  private sinceLastValue(): string {
    if (this.sinceLast < 0) {
      return '—';
    }
    if (this.sinceLast === 0) {
      return '0';
    }
    return this.sinceLast.toString();
  }

  private sinceLastUnit(): string {
    if (this.sinceLast < 0) {
      return '';
    }
    return '天';
  }
}
