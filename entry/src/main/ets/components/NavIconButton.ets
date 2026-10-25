/**
 * 顶栏图标按钮（日历翻月、后续其它工具位共用）。
 *
 * 为什么是 @Component 而不是 @Builder：
 * @Builder 的入参是**按值传递**的，父组件状态变化时 builder 内部那棵子树不会重建，
 * `.enabled()` / `.opacity()` 会永久停在创建时的值——右箭头因此在「当前月 = 禁用」
 * 这一帧被写死后再也点不动。改成带 @Prop 的组件后，`enabled` 会随父组件一起刷新。
 */
@Component
export struct NavIconButton {
  /** 图标本身不会变，普通成员即可（Resource 不适合走 @Prop 深拷贝） */
  icon: Resource = $r('sys.symbol.chevron_left');
  /** 无障碍描述 */
  desc: string = '';
  /**
   * 是否可用：不可用时置灰并拦截点击。
   * 注意不能叫 enabled——CustomComponent 自带 enabled 属性，同名会编译报错。
   */
  @Prop active: boolean = true;
  onTap: () => void = () => {
  };

  build() {
    Column() {
      SymbolGlyph(this.icon)
        .fontSize(20)
        .fontColor([$r('app.color.color_text_secondary')])
    }
    .width(36)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .borderRadius(10)
    .enabled(this.active)
    .opacity(this.active ? 1 : 0.3)
    .stateStyles({
      pressed: {
        .backgroundColor($r('app.color.color_press'))
      },
      normal: {
        .backgroundColor(Color.Transparent)
      }
    })
    .onClick(() => {
      if (this.active) {
        this.onTap();
      }
    })
    .accessibilityText(this.desc)
  }
}
