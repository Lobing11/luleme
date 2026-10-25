import { MonthCount } from '../logic/StatsCalculator';
import { common } from '@kit.AbilityKit';

@Component
export struct TrendChart {
  @Prop @Watch('onDataChange') data: MonthCount[] = [];

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;
  private barColor: string = '#FF5E7E';
  private labelColor: string = '#8A8A8E';
  private colorsLoaded: boolean = false;

  onDataChange(): void {
    if (this.ready) {
      this.loadColors();
      this.draw();
    }
  }

  private loadColors(): void {
    if (this.colorsLoaded) {
      return;
    }
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const rm = ctx.resourceManager;
    const barRaw = rm.getColorSync($r('app.color.color_primary').id);
    const labelRaw = rm.getColorSync($r('app.color.color_text_secondary').id);
    this.barColor = '#' + barRaw.toString(16).padStart(8, '0').slice(-6);
    this.labelColor = '#' + labelRaw.toString(16).padStart(8, '0').slice(-6);
    this.colorsLoaded = true;
  }

  private draw(): void {
    const ctx = this.context;
    const w = ctx.width;
    const h = ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    ctx.clearRect(0, 0, w, h);
    const n = this.data.length;
    if (n === 0) {
      return;
    }
    let max = 0;
    for (let i = 0; i < n; i++) {
      if (this.data[i].count > max) {
        max = this.data[i].count;
      }
    }
    if (max === 0) {
      max = 1;
    }
    const padL = 10;
    const padR = 10;
    const padT = 22;
    const padB = 28;
    const plotW = w - padL - padR;
    const plotH = h - padT - padB;
    const slot = plotW / n;
    const barW = Math.min(28, slot * 0.55);
    for (let i = 0; i < n; i++) {
      const cx = padL + slot * i + slot / 2;
      const barH = Math.max(2, (this.data[i].count / max) * plotH);
      const x = cx - barW / 2;
      const y = padT + plotH - barH;
      ctx.fillStyle = this.barColor;
      ctx.fillRect(x, y, barW, barH);
      ctx.fillStyle = this.labelColor;
      ctx.font = '10vp sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(this.data[i].count.toString(), cx, y - 4);
      ctx.fillText((this.data[i].month + 1).toString() + '月', cx, h - 8);
    }
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height(180)
      .onReady(() => {
        this.ready = true;
        this.loadColors();
        this.draw();
      })
  }
}
