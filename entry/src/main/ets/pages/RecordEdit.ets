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
  moodRow() {
    Row({ space: 8 }) {
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
            this.settingRow('日期', this.dateLabel(), () => {
              this.pickDate();
            })
            Divider()
              .color($r('app.color.color_border'))
            this.settingRow('时间', this.timeLabel(), () => {
              this.pickTime();
            })
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
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
          .padding(16)
          .borderRadius(16)
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
          .padding(16)
          .borderRadius(16)
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
        .padding(16)
      }
      .width('100%')
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

  @Builder
  settingRow(label: string, value: string, action: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.color_text_primary'))
      Blank()
      Text(value)
        .fontSize(15)
        .fontColor($r('app.color.color_primary'))
      Text('›')
        .fontSize(16)
        .fontColor($r('app.color.color_text_secondary'))
        .margin({ left: 6 })
    }
    .width('100%')
    .height(44)
    .onClick(() => {
      action();
    })
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
