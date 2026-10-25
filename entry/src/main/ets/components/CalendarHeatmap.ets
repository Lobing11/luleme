import { buildMonthGrid, weekdayHeaders } from '../logic/CalendarUtil';
import { HEAT_COLORS, heatLevel } from '../common/Constants';

/** 日期格高度（vp）：兼顾触控热区与首屏高度，6 行月份也不会把内容顶出屏幕 */
const CELL_HEIGHT: number = 40;
/** 日期格间距（vp） */
const GRID_GAP: number = 4;

/**
 * 月历热力图。
 *
 * 注意：year / month / dayCounts / todayDay 必须是 @Prop。
 * 普通成员变量只在组件创建时赋值一次，父组件换月时**不会**重新推进来，
 * 表现就是「标题变了、网格还停在上个月」——选中日高亮跨月残留也是这么来的。
 */
@Component
export struct CalendarHeatmap {
  @Prop year: number = 2025;
  @Prop month: number = 0;
  /** 下标 = 日（1-31），0 号位留空；用数组而不是 Map，@Prop 能可靠地做深拷贝与刷新 */
  @Prop dayCounts: number[] = [];
  /** 今天的日号；不在本月时为 0（此时不画"今天"的描边） */
  @Prop todayDay: number = 0;
  onDayTap: (day: number) => void = () => {
  };

  private countOf(day: number): number {
    if (day < 0 || day >= this.dayCounts.length) {
      return 0;
    }
    return this.dayCounts[day];
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
            .fontSize(10)
            .fontColor(this.textColorFor(day))
            .maxLines(1)
            .constraintSize({ maxWidth: '100%' })
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Text(' ')
            .fontSize(10)
        }
      }
      .width('100%')
      .height(CELL_HEIGHT)
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(HEAT_COLORS[heatLevel(this.countOf(day))])
      // 「今天」用细描边标记（1.2vp），比原来的 1.5 更克制，也不会被高热度底色吞掉
      .border({
        width: this.isToday(day) ? 1.2 : 0,
        color: $r('app.color.color_text_primary')
      })
      .stateStyles({
        pressed: {
          .backgroundColor($r('app.color.color_press'))
          .scale({ x: 0.96, y: 0.96 })
        },
        normal: {
          .backgroundColor(HEAT_COLORS[heatLevel(this.countOf(day))])
          .scale({ x: 1, y: 1 })
        }
      })
      .onClick(() => {
        this.onDayTap(day);
      })
      .accessibilityText(`${day}日，${this.countOf(day)}次`)
    } else {
      Column()
        .width('100%')
        .height(CELL_HEIGHT)
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

      // 必须显式给定高度：Grid 默认会撑满父容器剩余空间，
      // 会把页面下方的图例、统计卡和主按钮全部挤出屏幕。
      Grid() {
        ForEach(this.cells(), (cell: number | null, idx: number) => {
          GridItem() {
            this.cellView(cell)
          }
        // key 必须带上年月：只按 index 做 key 时，换月后新数组的 key 与旧数组完全一致，
        // ArkUI 会复用旧节点且不重新布局，网格就"冻结"在上个月（选中日高亮跨月残留也是它）。
        }, (cell: number | null, idx: number) => `${this.year}-${this.month}-${idx}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(GRID_GAP)
      .columnsGap(GRID_GAP)
      .width('100%')
      .height(this.gridHeight())
    }
    .width('100%')
  }

  /** 行数 × 单元高度 + 行间距（最后一行不计间距） */
  private gridHeight(): number {
    const rows: number = Math.ceil(this.cells().length / 7);
    return rows * CELL_HEIGHT + (rows - 1) * GRID_GAP;
  }

  private cells(): (number | null)[] {
    return buildMonthGrid(this.year, this.month);
  }
}
