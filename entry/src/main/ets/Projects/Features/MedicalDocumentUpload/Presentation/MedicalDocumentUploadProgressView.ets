import {
  MedicalDocumentUploadFlowStep,
  MedicalDocumentUploadFlowStepKind,
  MedicalDocumentUploadStepOutcome
} from '../Domain/MedicalDocumentUploadFlowStep';
import {
  MedicalDocumentKind,
  medicalDocumentKindAllCases,
  medicalDocumentKindPickerLabel
} from '../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadProgressStep } from '../Domain/MedicalDocumentUploadProgress';
import { MedicalUploadL10n } from '../Domain/SupportingModels';
import { MedicalDocumentUploadViewModel } from './MedicalDocumentUploadViewModel';

/** bindMenu 用的显式菜单项（ArkTS 禁止内联对象字面量）。 */
class MedicalUploadProgressMenuItem {
  value: string = '';
  action: () => void = () => {};

  constructor(value: string, action: () => void) {
    this.value = value;
    this.action = action;
  }
}

/** 整体识别态；对齐 iOS `MedicalDocumentUploadStep.CompletionOutcome` 的整体聚合语义。 */
type MedicalUploadOverallOutcome = 'pending' | 'running' | 'failed' | 'success';

/**
 * 识别进度页。
 * 对齐参考包 iOS `MedicalDocumentUploadProgressView.swift`：
 * 渐变描边卡片 + 头部（图标/标题/状态徽标/耗时）+ 分隔线 + 步骤列表（状态图标/标题/副标题/耗时/操作）+
 * 底部按钮随整体状态切换（进行中只有取消；失败态为返回选择/重新识别/继续识别三个动作）。
 * 低置信 / fallback 时展示确认与手动改类型，对齐 HOS-MED-UPLOAD-0007。
 */
@Component
export struct MedicalDocumentUploadProgressView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  @StorageProp('topRectHeight') private topRectHeightPx: number = 0;
  /** 对齐 iOS `isShowingOCRText` + OCR 全文 sheet。 */
  @State private isShowingOCRText: boolean = false;

  private topSafeInset(): number {
    return this.topRectHeightPx > 0 ? this.getUIContext().px2vp(this.topRectHeightPx) : 24;
  }

  private stepLabel(kind: MedicalDocumentUploadFlowStepKind): string {
    return MedicalDocumentUploadFlowStep.label(kind);
  }

  private outcomeLabel(outcome: MedicalDocumentUploadStepOutcome): string {
    return MedicalDocumentUploadFlowStep.outcomeLabel(outcome);
  }

  private confirmationKinds(): MedicalDocumentKind[] {
    return medicalDocumentKindAllCases().filter((kind: MedicalDocumentKind): boolean =>
      kind !== MedicalDocumentKind.AUTO
    );
  }

  private typeChangeMenuItems(): MedicalUploadProgressMenuItem[] {
    const kinds = this.confirmationKinds();
    const items: MedicalUploadProgressMenuItem[] = [];
    for (let i = 0; i < kinds.length; i++) {
      const kind = kinds[i];
      items.push(new MedicalUploadProgressMenuItem(
        medicalDocumentKindPickerLabel(kind),
        (): void => this.viewModel.selectManualKindAndContinue(kind)
      ));
    }
    return items;
  }

  private confirmationHint(): string {
    const resolution = this.viewModel.typeResolution;
    if (resolution === undefined) {
      return '自动类型置信度较低，请确认或手动指定类型后继续。';
    }
    if (resolution.reason === 'ai_fallback_default') {
      return `当前为 AI 兜底「${resolution.kindLabel}」（置信度 ${resolution.confidence.toFixed(2)}），不是高可信结论。请确认或改选类型。`;
    }
    return `当前判定为「${resolution.kindLabel}」（${resolution.sourceLabel}，置信度 ${resolution.confidence.toFixed(2)}）。如不正确，请改选类型。`;
  }

  /** 对齐 iOS `progress?.overallOutcome`：任一失败→failed；任一进行中→running；全部终态→success；否则 pending。 */
  private overallOutcome(): MedicalUploadOverallOutcome {
    const progress = this.viewModel.progress;
    if (progress === undefined) {
      return 'pending';
    }
    const steps = progress.steps;
    if (steps.some((s: MedicalDocumentUploadProgressStep): boolean =>
      s.outcome === MedicalDocumentUploadStepOutcome.FAILED)) {
      return 'failed';
    }
    if (steps.some((s: MedicalDocumentUploadProgressStep): boolean =>
      s.outcome === MedicalDocumentUploadStepOutcome.RUNNING)) {
      return 'running';
    }
    if (steps.length > 0 && steps.every((s: MedicalDocumentUploadProgressStep): boolean => s.isTerminalSuccess)) {
      return 'success';
    }
    return 'pending';
  }

  /** 只展示已开始/已结束的步骤（不含 pending），对齐 iOS `visibleSteps`。 */
  private visibleSteps(): MedicalDocumentUploadProgressStep[] {
    return (this.viewModel.progress?.steps ?? []).filter(
      (s: MedicalDocumentUploadProgressStep): boolean => s.outcome !== MedicalDocumentUploadStepOutcome.PENDING
    );
  }

  /** 对齐 iOS `formattedTimeString`：已用时 X 分 X 秒（预计约 X 分钟/秒）。 */
  private formattedTimeString(): string {
    const progress = this.viewModel.progress;
    const elapsed = progress?.elapsedSeconds ?? 0;
    const estimated = progress?.estimatedSeconds;
    if (elapsed <= 0 && !(estimated !== undefined && estimated > 0)) {
      return '';
    }
    const elapsedMin = Math.floor(elapsed / 60);
    const elapsedSec = elapsed % 60;
    const elapsedPart = elapsedMin === 0 ? `已用时 ${elapsedSec} 秒` : `已用时 ${elapsedMin} 分 ${elapsedSec} 秒`;
    if (estimated === undefined || estimated <= 0) {
      return elapsedPart;
    }
    if (estimated < 60) {
      return `${elapsedPart}（预计约 ${estimated} 秒）`;
    }
    const estMin = Math.ceil(estimated / 60);
    return `${elapsedPart}（预计约 ${estMin} 分钟）`;
  }

  private formattedElapsedDuration(ms: number): string {
    if (ms < 1000) {
      return `${ms}ms`;
    }
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return minutes === 0 ? `${seconds}s` : `${minutes}m ${seconds}s`;
  }

  private ocrTextForDisplay(): string {
    const text = this.viewModel.pipelineOCRText;
    if (text === undefined || text.length === 0) {
      return '暂无 OCR 内容';
    }
    return text;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        Blank().layoutWeight(1)

        if (this.viewModel.needsManualModeSelection) {
          this.LowConfidenceConfirmCard()
        } else if (this.viewModel.progress !== undefined) {
          this.ProgressCard()
        } else {
          Column({ space: 12 }) {
            LoadingProgress().width(48).height(48)
            Text(MedicalUploadL10n.text('medical.upload.processing.preparing'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
        }

        Blank().layoutWeight(1)

        this.ActionButtons()
      }
      .width('100%')
      .height('100%')
      .padding({
        top: this.topSafeInset() + 54,
        left: 20,
        right: 20,
        bottom: 20
      })

      if (this.isShowingOCRText) {
        this.OCRTextSheet()
      }
    }
    .width('100%')
    .height('100%')
  }

  // MARK: - 进度卡片（对齐 iOS ProgressCardView：头部 + 分隔线 + 步骤列表 + 渐变描边）

  @Builder
  private ProgressCard() {
    Column({ space: 12 }) {
      this.CardHeader()
      Divider().color('#EDEDF0').strokeWidth(1)
      this.StepsList()
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#F7F7FA')
    .borderRadius(16)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)', offsetX: 0, offsetY: 4 })
    .border({
      width: 2,
      color: '#6C8CFF',
      radius: 16
    })
  }

  @Builder
  private CardHeader() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.doc_text'))
        .fontSize(22)
        .fontColor(['#5856D6'])
        .fontWeight(FontWeight.Bold)

      Column({ space: 4 }) {
        Text(this.viewModel.progress?.title ?? '')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .width('100%')

        Row({ space: 8 }) {
          Text(this.viewModel.progress?.statusLabel ?? '')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#5856D6')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('rgba(88,86,214,0.12)')
            .borderRadius(20)

          if (this.formattedTimeString().length > 0) {
            Text(this.formattedTimeString())
              .fontSize(12)
              .fontColor('#8E8E93')
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private StepsList() {
    Column({ space: 14 }) {
      ForEach(this.visibleSteps(), (step: MedicalDocumentUploadProgressStep) => {
        this.StepRow(step)
      }, (step: MedicalDocumentUploadProgressStep): string =>
        `${step.kind}-${step.outcome}-${step.resultSummary}-${step.elapsedMilliseconds}`)
    }
    .width('100%')
  }

  @Builder
  private StepRow(step: MedicalDocumentUploadProgressStep) {
    Row({ space: 12 }) {
      this.StateIcon(step.outcome)

      Column({ space: 4 }) {
        Text(this.stepLabel(step.kind))
          .fontSize(15)
          .fontWeight(step.outcome === MedicalDocumentUploadStepOutcome.RUNNING ?
            FontWeight.Medium : FontWeight.Regular)
          .fontColor(step.outcome === MedicalDocumentUploadStepOutcome.PENDING ? '#8E8E93' : '#1C1C1E')
        if (step.resultSummary.length > 0 && !this.showsOCRAction(step)) {
          Text(step.resultSummary)
            .fontSize(12)
            .fontColor('#8E8E93')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        if (step.elapsedMilliseconds > 0) {
          Text(`任务耗时：${this.formattedElapsedDuration(step.elapsedMilliseconds)}`)
            .fontSize(11)
            .fontColor('#AEAEB2')
        }
        this.StepOperations(step)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  private showsOCRAction(step: MedicalDocumentUploadProgressStep): boolean {
    return step.kind === MedicalDocumentUploadFlowStepKind.OCR &&
      step.isTerminalSuccess &&
      (this.viewModel.pipelineOCRText?.length ?? 0) > 0;
  }

  /** 状态图标：pending 空心圆 / running 转圈 / success-skipped 蓝色勾 / failed 红色叉。对齐 iOS `StateIcon`。 */
  @Builder
  private StateIcon(outcome: MedicalDocumentUploadStepOutcome) {
    Stack({ alignContent: Alignment.Center }) {
      if (outcome === MedicalDocumentUploadStepOutcome.PENDING) {
        Circle()
          .width(24)
          .height(24)
          .fill(Color.Transparent)
          .stroke('#D1D1D6')
          .strokeWidth(2)
      } else if (outcome === MedicalDocumentUploadStepOutcome.RUNNING) {
        LoadingProgress()
          .width(24)
          .height(24)
          .color('#0A84FF')
      } else if (outcome === MedicalDocumentUploadStepOutcome.SUCCESS ||
        outcome === MedicalDocumentUploadStepOutcome.SKIPPED) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(24)
          .fontColor(['#0A84FF'])
      } else {
        SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
          .fontSize(24)
          .fontColor(['#D93025'])
      }
    }
    .width(28)
    .height(28)
  }

  /** 每个步骤的操作区：OCR 查看全文 / 类型改选 / 失败重试。对齐 iOS `stepOperations` + 失败重试按钮。 */
  @Builder
  private StepOperations(step: MedicalDocumentUploadProgressStep) {
    if (this.showsOCRAction(step)) {
      Button(step.resultSummary.length > 0 ? step.resultSummary : 'OCR 全文')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0A84FF')
        .backgroundColor(Color.Transparent)
        .padding(0)
        .onClick(() => {
          this.isShowingOCRText = true;
        })
    } else if (step.kind === MedicalDocumentUploadFlowStepKind.TYPE_RECOGNITION &&
      step.outcome === MedicalDocumentUploadStepOutcome.FAILED) {
      Text('改类型')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0A84FF')
        .bindMenu(this.typeChangeMenuItems())
    } else if (step.outcome === MedicalDocumentUploadStepOutcome.FAILED) {
      Button('重试')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0A84FF')
        .backgroundColor(Color.Transparent)
        .padding(0)
        .onClick(() => this.viewModel.resumeRecognitionTask())
    }
  }

  // MARK: - 底部操作按钮：随整体状态切换，对齐 iOS `actionButtons`

  @Builder
  private ActionButtons() {
    if (this.viewModel.needsManualModeSelection) {
      // 低置信确认卡片自带操作，这里不再重复渲染底部按钮。
    } else {
      Row({ space: 16 }) {
        if (this.overallOutcome() === 'running') {
          Button(MedicalUploadL10n.text('medical.upload.action.cancel'))
            .fontSize(15)
            .fontColor('#8E8E93')
            .backgroundColor(Color.Transparent)
            .onClick(() => this.viewModel.cancelRecognition())
        } else if (this.overallOutcome() === 'failed') {
          Button('返回选择')
            .layoutWeight(1)
            .height(48)
            .fontSize(15)
            .fontColor('#8E8E93')
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.viewModel.resetRecognitionState();
              this.viewModel.returnToPickingPreservingFiles();
            })

          Button('重新识别')
            .layoutWeight(1)
            .height(48)
            .fontSize(15)
            .fontColor('#8E8E93')
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.viewModel.resetRecognitionState();
              this.viewModel.startRecognitionTask();
            })

          Button('继续识别')
            .layoutWeight(1)
            .height(48)
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor('#0A84FF')
            .borderRadius(10)
            .onClick(() => this.viewModel.resumeRecognitionTask())
        }
        // success / skipped / pending：不展示按钮，对齐 iOS EmptyView（自动跳转结果页）。
      }
      .width('100%')
    }
  }

  // MARK: - 低置信确认卡片

  @Builder
  private LowConfidenceConfirmCard() {
    Column({ space: 12 }) {
      Text('请确认报告识别类型')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
        .width('100%')
      Text(this.confirmationHint())
        .fontSize(13)
        .fontColor('#777777')
        .width('100%')
      Text('或手动选择类型：')
        .fontSize(13)
        .fontColor('#555555')
        .width('100%')
        .margin({ top: 4 })
      ForEach(this.confirmationKinds(), (kind: MedicalDocumentKind) => {
        Button(medicalDocumentKindPickerLabel(kind))
          .width('100%')
          .height(44)
          .fontColor('#1C1C1E')
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E5E5EA' })
          .borderRadius(10)
          .onClick(() => this.viewModel.selectManualKindAndContinue(kind))
      }, (kind: MedicalDocumentKind): string => `${kind}`)

      Row({ space: 16 }) {
        Button('返回选择')
          .layoutWeight(1)
          .height(48)
          .fontColor('#333333')
          .backgroundColor('#E9E9ED')
          .borderRadius(10)
          .onClick(() => this.viewModel.returnToPickingPreservingFiles())
        Button('确认此类型')
          .layoutWeight(1)
          .height(48)
          .fontColor(Color.White)
          .backgroundColor('#0A84FF')
          .borderRadius(10)
          .onClick(() => this.viewModel.confirmDetectedType())
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#F7F7FA')
    .borderRadius(16)
  }

  // MARK: - OCR 全文（对齐 iOS `.sheet(isPresented: $isShowingOCRText)` + `OCRTextUIKitView`）

  @Builder
  private OCRTextSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.35)')
        .onClick(() => {
          this.isShowingOCRText = false;
        })

      Column({ space: 12 }) {
        Row() {
          Text('OCR 全文')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1C1E')
            .layoutWeight(1)
          Button('完成')
            .fontSize(14)
            .fontColor('#0A84FF')
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.isShowingOCRText = false;
            })
        }
        .width('100%')

        Scroll() {
          Text(this.ocrTextForDisplay())
            .fontSize(14)
            .fontColor('#1C1C1E')
            .lineHeight(22)
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .align(Alignment.TopStart)
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('70%')
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
  }
}
