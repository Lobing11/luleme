/**
 * 鹿了么 - 近 N 月趋势柱状图（Canvas 自绘）
 */
import { MonthCount } from '../logic/StatsCalculator';

@Component
export struct TrendChart {
  /** 按月统计数据（升序） */
  @Prop @Watch('onDataChange') data: MonthCount[] = [];

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  onDataChange(): void {
    if (this.ready) {
      this.draw();
    }
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
      ctx.fillStyle = '#FF5E7E';
      ctx.fillRect(x, y, barW, barH);
      ctx.fillStyle = '#8A8A8E';
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
        this.draw();
      })
  }
}
