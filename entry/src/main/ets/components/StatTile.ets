import { CARD_RADIUS } from '../common/DesignTokens';

/**
 * 统计数字小卡（首页「今日 / 本月 / 连续」与统计页六张卡共用）。
 *
 * 为什么写成 @Component 而不是 @Builder：
 * @Builder 的参数是**按值传递**的，父组件拿到异步数据后更新 @State 时，builder 内部
 * 早已用初始值（0）渲染好的 UI 不会重建，于是出现「数据库里有记录、趋势图也对，
 * 但卡片上的数字一直停在 0」的假象。改用带 @Prop 的组件后，父组件状态变化会把新值
 * 同步进来并触发重绘。
 */
@Component
export struct StatTile {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop unit: string = '';
  /** 卡片高度：首页迷你卡 72vp，统计页 88vp */
  tileHeight: number = 88;
  /** 数值字号：首页 22fp，统计页 26fp */
  valueFontSize: number = 26;

  build() {
    Column({ space: 2 }) {
      Text(this.title)
        .fontSize(12)
        .fontColor($r('app.color.color_text_secondary'))
      Row({ space: 2 }) {
        Text(this.value)
          .fontSize(this.valueFontSize)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
        if (this.unit.length > 0) {
          Text(this.unit)
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
        }
      }
    }
    // layoutWeight(1)：让同一行里的卡片等分宽度。若写成 width('100%')，
    // 每张卡都会占满整行，后两张会被挤出可视区。
    .layoutWeight(1)
    .height(this.tileHeight)
    .justifyContent(FlexAlign.Center)
    .borderRadius(CARD_RADIUS)
    .backgroundColor($r('app.color.color_card'))
  }
}
