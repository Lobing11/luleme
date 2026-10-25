@Component
export struct EmptyState {
  title: string = '暂无数据';
  desc: string = '';
  /** 顶部插画（emoji），传空串则只显示文案 */
  emoji: string = '🦌';

  build() {
    Column({ space: 8 }) {
      if (this.emoji.length > 0) {
        Text(this.emoji)
          .fontSize(36)
      }
      Text(this.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_primary'))
        .textAlign(TextAlign.Center)
      if (this.desc.length > 0) {
        // 左右留白 + 允许换行：副标题不再顶到卡片/屏幕边缘被裁掉
        Text(this.desc)
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .textAlign(TextAlign.Center)
          .lineHeight(18)
          .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 16, bottom: 8 })
  }
}
