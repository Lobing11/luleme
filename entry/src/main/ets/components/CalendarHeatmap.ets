/**
 * 鹿了么 - 日历热力图组件
 *
 * 展示某自然月的 7 列日历，按当日记录次数着色（HEAT_COLORS 五档）。
 * 点击某一天通过 onDayTap 回调通知父组件。
 */
import { buildMonthGrid, weekdayHeaders } from '../logic/CalendarUtil';
import { HEAT_COLORS, heatLevel } from '../common/Constants';

@Component
export struct CalendarHeatmap {
  /** 展示的年份 */
  year: number = 2025;
  /** 展示的月份（0-11） */
  month: number = 0;
  /** 日号 -> 当日次数 */
  dayCounts: Map<number, number> = new Map<number, number>();
  /** 今天在展示月内的日号；若展示的不是当月则为 0 */
  todayDay: number = 0;
  /** 点击某一天的回调，参数为日号 1-31 */
  onDayTap: (day: number) => void = () => {
  };

  private countOf(day: number): number {
    const c = this.dayCounts.get(day);
    return c === undefined ? 0 : c;
  }

  private textColorFor(day: number): ResourceColor {
    const level = heatLevel(this.countOf(day));
    if (level >= 3) {
      return $r('app.color.color_white');
    }
    return $r('app.color.color_text_primary');
  }

  private isToday(day: number): boolean {
    return this.todayDay > 0 && day === this.todayDay;
  }

  @Builder
  cellView(day: number | null) {
    if (day !== null) {
      Column({ space: 0 }) {
        Text(day.toString())
          .fontSize(14)
          .fontWeight(this.isToday(day) ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.textColorFor(day))
        if (this.countOf(day) > 0) {
          Text(this.countOf(day) > 9 ? '9+' : this.countOf(day).toString())
            .fontSize(9)
            .fontColor(this.textColorFor(day))
        } else {
          Text(' ')
            .fontSize(9)
        }
      }
      .width('100%')
      .height(44)
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(HEAT_COLORS[heatLevel(this.countOf(day))])
      .border({
        width: this.isToday(day) ? 1.5 : 0,
        color: $r('app.color.color_primary')
      })
      .onClick(() => {
        this.onDayTap(day);
      })
    } else {
      // 占位格
      Column()
        .width('100%')
        .height(44)
    }
  }

  build() {
    Column({ space: 6 }) {
      Row() {
        ForEach(weekdayHeaders(), (wd: string, idx: number) => {
          Text(wd)
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
        }, (wd: string, idx: number) => idx.toString())
      }
      .width('100%')

      Grid() {
        ForEach(this.cells(), (cell: number | null, idx: number) => {
          GridItem() {
            this.cellView(cell)
          }
        }, (cell: number | null, idx: number) => idx.toString())
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(4)
      .columnsGap(4)
      .width('100%')
    }
    .width('100%')
  }

  private cells(): (number | null)[] {
    return buildMonthGrid(this.year, this.month);
  }
}
