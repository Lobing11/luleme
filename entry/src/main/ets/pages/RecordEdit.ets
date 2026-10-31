/**
 * 鹿了么 - 记录新增 / 编辑页
 *
 * 通过 NavDestination 挂载在首页 Navigation 上。
 * 参数：RecordEditParam（id 存在时为编辑，否则新增；date 可预设日期）。
 */
import { RecordRepository } from '../data/RecordRepository';
import { Record } from '../model/RecordModel';
import { MOODS, DEFAULT_MOOD, MoodOption } from '../model/RecordModel';
import { RecordEditParam } from '../common/Constants';
import { ReminderScheduler } from '../logic/ReminderScheduler';
import { CARD_RADIUS, PAGE_PADDING } from '../common/DesignTokens';

const DATE_PICKER_START: number = 2015;
const DATE_PICKER_END: number = 2035;

@Component
export struct RecordEdit {
  @State editing: boolean = false;
  @State recordId: number = 0;
  @State dateMs: number = Date.now();
  @State mood: number = DEFAULT_MOOD;
  @State note: string = '';
  @State saving: boolean = false;

  private async setup(param: RecordEditParam | null): Promise<void> {
    if (param !== null && param.id !== undefined && param.id > 0) {
      const record: Record | null = await RecordRepository.getInstance().getById(param.id);
      if (record !== null) {
        this.editing = true;
        this.recordId = record.id;
        this.dateMs = record.timestamp;
        this.mood = record.mood;
        this.note = record.note;
        return;
      }
    }
    // 新增
    this.editing = false;
    this.recordId = 0;
    if (param !== null && param.date !== undefined && param.date > 0) {
      // 预设到该日中午，避免时区边界问题
      this.dateMs = param.date + 12 * 60 * 60 * 1000;
    } else {
      this.dateMs = Date.now();
    }
    this.mood = DEFAULT_MOOD;
    this.note = '';
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      const repo = RecordRepository.getInstance();
      if (this.editing) {
        await repo.update(this.recordId, this.dateMs, this.mood, this.note);
        this.getUIContext().getPromptAction().showToast({ message: '已保存修改' });
      } else {
        await repo.add(this.dateMs, this.mood, this.note);
        // 葛神模式：每次新增记录后重建"8 小时后"的一次性提醒（开关关闭时内部直接返回）。
        // 这里用当前时间而不是记录时间：补记昨天的记录时，仍然应该是"从此刻起 8 小时"，
        // 否则触发时间会落在过去，系统会直接拒收。
        await ReminderScheduler.getInstance().onRecordCreated(Date.now());
        this.getUIContext().getPromptAction().showToast({ message: '已记录' });
      }
      this.queryNavigationInfo()?.pathStack.pop();
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试' });
    } finally {
      this.saving = false;
    }
  }

  private pickDate(): void {
    const cur = new Date(this.dateMs);
    this.getUIContext().showDatePickerDialog({
      start: new Date(DATE_PICKER_START, 0, 1),
      end: new Date(DATE_PICKER_END, 11, 31),
      selected: cur,
      onDateAccept: (value: Date) => {
        const merged = new Date(
          value.getFullYear(),
          value.getMonth(),
          value.getDate(),
          cur.getHours(),
          cur.getMinutes()
        );
        this.dateMs = merged.getTime();
      }
    });
  }

  private pickTime(): void {
    const cur = new Date(this.dateMs);
    this.getUIContext().showTimePickerDialog({
      selected: cur,
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        const merged = new Date(
          cur.getFullYear(),
          cur.getMonth(),
          cur.getDate(),
          value.hour,
          value.minute
        );
        this.dateMs = merged.getTime();
      }
    });
  }

  @Builder
  moodRow() {    Row({ space: 8 }) {
      ForEach(MOODS, (m: MoodOption, idx: number) => {
        Column({ space: 2 }) {
          Text(m.emoji)
            .fontSize(26)
          Text(m.label)
            .fontSize(10)
            .fontColor(this.mood === m.value ?
              $r('app.color.color_primary') : $r('app.color.color_text_secondary'))
        }
        .width(56)
        .padding({ top: 8, bottom: 6 })
        .borderRadius(12)
        .backgroundColor(this.mood === m.value ?
          $r('app.color.color_primary_soft') : $r('app.color.color_card'))
        .border({
          width: this.mood === m.value ? 1.5 : 1,
          color: this.mood === m.value ?
            $r('app.color.color_primary') : $r('app.color.color_border')
        })
        .onClick(() => {
          this.mood = m.value;
        })
      }, (m: MoodOption, idx: number) => m.value.toString())
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          // 日期 / 时间
          Column({ space: 0 }) {
            this.dateRow()
            Divider()
              .color($r('app.color.color_border'))
            this.timeRow()
          }
          .width('100%')
          .padding(PAGE_PADDING)
          .borderRadius(CARD_RADIUS)
          .backgroundColor($r('app.color.color_card'))

          // 心情
          Column({ space: 10 }) {
            Text('心情')
              .fontSize(14)
              .fontColor($r('app.color.color_text_secondary'))
              .width('100%')
            this.moodRow()
          }
          .width('100%')
          .padding(PAGE_PADDING)
          .borderRadius(CARD_RADIUS)
          .backgroundColor($r('app.color.color_card'))

          // 备注
          Column({ space: 10 }) {
            Text('备注')
              .fontSize(14)
              .fontColor($r('app.color.color_text_secondary'))
              .width('100%')
            TextArea({ text: this.note, placeholder: '记录此刻的感受（仅保存在本机）…' })
              .width('100%')
              .height(120)
              .backgroundColor($r('app.color.color_bg'))
              .borderRadius(12)
              .onChange((value: string) => {
                this.note = value;
              })
          }
          .width('100%')
          .padding(PAGE_PADDING)
          .borderRadius(CARD_RADIUS)
          .backgroundColor($r('app.color.color_card'))

          Button(this.editing ? '保存修改' : '记一笔')
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontColor($r('app.color.color_white'))
            .backgroundColor($r('app.color.color_primary'))
            .borderRadius(24)
            .onClick(() => {
              this.save();
            })
        }
        .width('100%')
        .padding(PAGE_PADDING)
      }
      .width('100%')
      // 内容不足一屏时 Scroll 默认垂直居中（页面顶部会出现大片空白），强制顶部对齐
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .height('100%')
      .backgroundColor($r('app.color.color_bg'))
    }
    .title(this.editing ? '编辑记录' : '新增记录')
    .onReady((ctx: NavDestinationContext) => {
      let param: RecordEditParam | null = null;
      if (ctx.pathInfo.param !== null && ctx.pathInfo.param !== undefined) {
        param = ctx.pathInfo.param as RecordEditParam;
      }
      this.setup(param);
    })
  }

  /**
   * 日期行。
   *
   * 这里刻意**不把日期字符串当参数传给 @Builder**：@Builder 的入参是按值传递的，
   * `settingRow(label, this.dateLabel(), …)` 会把第一次构建时算出的字符串固化在子树里，
   * 之后 `dateMs` 变成记录的真实时间也不会重绘 —— 表现为「编辑 22 号的记录，日期栏却显示今天」。
   * 改为零参 @Builder，内部直接读 @State，构建出的 Text 才能跟着状态更新。
   */
  @Builder
  dateRow() {
    Row() {
      Text('日期')
        .fontSize(15)
        .fontColor($r('app.color.color_text_primary'))
      Blank()
      Text(this.dateLabel())
        .fontSize(15)
        .fontColor($r('app.color.color_primary'))
      Text('›')
        .fontSize(16)
        .fontColor($r('app.color.color_text_secondary'))
        .margin({ left: 6 })
    }
    .width('100%')
    .height(44)
    .borderRadius(0)
    .stateStyles({
      pressed: {
        .backgroundColor($r('app.color.color_press'))
      },
      normal: {
        .backgroundColor(Color.Transparent)
      }
    })
    .onClick(() => {
      this.pickDate();
    })
    .accessibilityText('日期')
  }

  @Builder
  timeRow() {
    Row() {
      Text('时间')
        .fontSize(15)
        .fontColor($r('app.color.color_text_primary'))
      Blank()
      Text(this.timeLabel())
        .fontSize(15)
        .fontColor($r('app.color.color_primary'))
      Text('›')
        .fontSize(16)
        .fontColor($r('app.color.color_text_secondary'))
        .margin({ left: 6 })
    }
    .width('100%')
    .height(44)
    .borderRadius(0)
    .stateStyles({
      pressed: {
        .backgroundColor($r('app.color.color_press'))
      },
      normal: {
        .backgroundColor(Color.Transparent)
      }
    })
    .onClick(() => {
      this.pickTime();
    })
    .accessibilityText('时间')
  }

  private dateLabel(): string {
    const d = new Date(this.dateMs);
    return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
  }

  private timeLabel(): string {
    const d = new Date(this.dateMs);
    const hh = String(d.getHours()).padStart(2, '0');
    const mi = String(d.getMinutes()).padStart(2, '0');
    return `${hh}:${mi}`;
  }
}
