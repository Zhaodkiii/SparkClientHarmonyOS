import { RemoteExaminationReportWithAttachments } from
  '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { ItemDraft, MedicalReportRecognitionDraft } from
  '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import {
  EXAMINATION_REPORT_CATEGORY_ALL,
  ExaminationReportCategory,
  examinationCategoryIcon,
  examinationCategoryTitle
} from '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportCategory';
import { ExaminationReportDraftMapping } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDraftMapping';
import { MedicalReportResultSupport } from
  '../../../../MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportResultSupport';
import { Logger } from '../../../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../../../Foundation/Logging/LogModule';
import { AddImagingReportItemSheet } from './AddImagingReportItemSheet';
import { AddLabItemSheet } from './AddLabItemSheet';
import { AddPathologyReportItemSheet } from './AddPathologyReportItemSheet';
import {
  EXAM_FORM_PAGE_BACKGROUND,
  ExamFormAddItemButton,
  ExamFormBottomBar,
  ExamFormCard,
  ExamFormDateField,
  ExamFormDivider,
  ExamFormInsetCard,
  ExamFormBindMenuItem,
  ExamFormMenuPickerRow,
  ExamFormTextAreaField,
  ExamFormTextField,
  SparkLabExamCategoryCascadeRow
} from './ExamFormFieldSupport';
import { ExamReportFormContext } from './ExamReportFormContext';
import { ExamReportFormModeKind } from './ExamReportFormMode';

/**
 * 医疗检查报告编辑表单。对齐 iOS `ExamReportFormView`：
 * 支持 create / serverEdit / localEdit 三种模式。
 */
@Component
export struct ExamReportFormView {
  @Prop formContext: ExamReportFormContext = new ExamReportFormContext();
  @Prop @Watch('onFormSessionChanged') formSession: number = 0;
  onLocalSubmit?: (draft: MedicalReportRecognitionDraft) => void;
  onServerSaved?: (draft: MedicalReportRecognitionDraft) => void;
  onCreated?: (reportID: number, draft: MedicalReportRecognitionDraft) => void;
  onCancel?: () => void;

  @State private pageType: ExaminationReportCategory = 'laboratory';
  @State private category: string = 'laboratory';
  @State private title: string = '';
  @State private hospital: string = '';
  @State private doctor: string = '';
  @State private content: string = '';
  @State private date: string = '';
  @State private examDay: Date = new Date();
  @State private formKeyboardVisible: boolean = false;
  @State private labPrimaryCategory: string = '';
  @State private labSubCategory: string = '';
  @State private items: ItemDraft[] = [];
  @State private editingItem?: ItemDraft = undefined;
  @State private isSaving: boolean = false;
  @State private errorText: string = '';

  aboutToAppear(): void {
    this.seedFromProps();
  }

  private onFormSessionChanged(): void {
    this.seedFromProps();
  }

  private modeKind(): ExamReportFormModeKind {
    return this.formContext.modeKind;
  }

  private modeLogLabel(): string {
    return this.modeKind();
  }

  private seedFromProps(): void {
    let seed = new MedicalReportRecognitionDraft();
    if (this.modeKind() === ExamReportFormModeKind.LOCAL_EDIT && this.formContext.existingDraft) {
      seed = ExaminationReportDraftMapping.cloneDraft(this.formContext.existingDraft);
    } else if (this.modeKind() === ExamReportFormModeKind.SERVER_EDIT && this.formContext.existingReport) {
      seed = ExaminationReportDraftMapping.examinationDraftFromReport(this.formContext.existingReport);
    } else {
      seed.category = 'laboratory';
      seed.title = '';
      seed.details = [];
    }

    this.pageType = MedicalReportResultSupport.categoryOf(seed.category);
    this.category = seed.category ?? this.pageType;
    this.title = seed.title;
    this.hospital = seed.hospital ?? '';
    this.doctor = seed.doctor ?? '';
    this.content = seed.content ?? '';
    const rawDate = (seed.date ?? '').trim();
    const resolvedDate = rawDate.length > 0 ? rawDate : ExaminationReportDraftMapping.todayDateText();
    this.date = resolvedDate;
    this.examDay = ExaminationReportDraftMapping.parseDate(resolvedDate);
    const clonedItems: ItemDraft[] = [];
    for (let i = 0; i < seed.details.length; i++) {
      clonedItems.push(ExaminationReportDraftMapping.cloneItemDraft(seed.details[i]));
    }
    this.items = clonedItems;
    if (this.pageType === 'laboratory' && seed.details.length > 0) {
      this.labPrimaryCategory = seed.details[0].category ?? '';
      this.labSubCategory = seed.details[0].subCategory ?? '';
    } else {
      this.labPrimaryCategory = '';
      this.labSubCategory = '';
    }
    this.editingItem = undefined;
    this.errorText = '';
  }

  private navTitle(): string {
    if (this.modeKind() === ExamReportFormModeKind.CREATE) {
      return '新增医疗检查报告';
    }
    if (this.modeKind() === ExamReportFormModeKind.LOCAL_EDIT) {
      return '编辑检查报告';
    }
    return '更新检查报告';
  }

  private saveTitle(): string {
    if (this.modeKind() === ExamReportFormModeKind.LOCAL_EDIT) {
      return '完成';
    }
    if (this.modeKind() === ExamReportFormModeKind.SERVER_EDIT) {
      return '更新';
    }
    return '保存';
  }

  private buildDraft(): MedicalReportRecognitionDraft {
    const fallbackCategory = this.category.trim().length > 0 ? this.category.trim() : this.pageType;
    const normalizedItems: ItemDraft[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const row = ExaminationReportDraftMapping.cloneItemDraft(this.items[i]);
      if ((row.category ?? '').trim().length === 0) {
        row.category = fallbackCategory;
      }
      normalizedItems.push(row);
    }
    const draft = new MedicalReportRecognitionDraft();
    draft.category = fallbackCategory;
    draft.title = this.title.trim();
    draft.hospital = this.hospital.trim().length > 0 ? this.hospital.trim() : undefined;
    draft.doctor = this.doctor.trim().length > 0 ? this.doctor.trim() : undefined;
    draft.content = this.content;
    draft.date = this.date.trim().length > 0 ? this.date.trim() : undefined;
    draft.details = normalizedItems;
    if (this.formContext.existingDraft) {
      draft.attachmentFileIds = this.formContext.existingDraft.attachmentFileIds.slice();
    }
    return draft;
  }

  private dismissAfterSave(): void {
    if (this.onCancel) {
      this.onCancel();
    }
  }

  private async saveNow(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    const draft = this.buildDraft();
    this.errorText = '';
    const fields = new LogFields();
    fields.operation = 'exam_report_form.save';
    fields.detail = `mode=${this.modeLogLabel()};items=${this.items.length}`;
    Logger.info('exam_report_form.save_start', LogModule.HOME, fields);
    this.isSaving = true;

    try {
      if (this.modeKind() === ExamReportFormModeKind.LOCAL_EDIT) {
        if (this.onLocalSubmit) {
          this.onLocalSubmit(draft);
        }
        Logger.info('exam_report_form.local_submit', LogModule.HOME, fields);
        this.dismissAfterSave();
        return;
      }

      if (this.modeKind() === ExamReportFormModeKind.SERVER_EDIT) {
        const report = this.formContext.existingReport;
        const service = this.formContext.mutationService;
        if (!report || !service) {
          this.errorText = '保存配置缺失';
          Logger.warn('exam_report_form.server_config_missing', LogModule.HOME, fields);
          return;
        }
        await service.updateReportWithDraft(report, draft);
        if (this.onServerSaved) {
          this.onServerSaved(draft);
        }
        Logger.info('exam_report_form.server_saved', LogModule.HOME, fields);
        this.dismissAfterSave();
        return;
      }

      if (this.modeKind() === ExamReportFormModeKind.CREATE) {
        const service = this.formContext.mutationService;
        if (!service || this.formContext.memberID <= 0) {
          this.errorText = '保存配置缺失';
          Logger.warn('exam_report_form.create_config_missing', LogModule.HOME, fields);
          return;
        }
        const newID = await service.createReportWithDraft(
          this.formContext.memberID,
          draft,
          this.formContext.medicalCaseID
        );
        if (this.onCreated) {
          this.onCreated(newID, draft);
        }
        const createdFields = new LogFields();
        createdFields.operation = 'exam_report_form.create_saved';
        createdFields.detail = `id=${newID}`;
        Logger.info('exam_report_form.create_saved', LogModule.HOME, createdFields);
        this.dismissAfterSave();
      }
    } catch (e) {
      this.errorText = `${e}`;
      const errorFields = new LogFields();
      errorFields.operation = 'exam_report_form.save_failed';
      errorFields.detail = `${e}`;
      Logger.warn('exam_report_form.save_failed', LogModule.HOME, errorFields);
    } finally {
      this.isSaving = false;
    }
  }

  private itemSheetVisible(): boolean {
    return this.editingItem !== undefined;
  }

  private closeItemEditor(): void {
    this.editingItem = undefined;
  }

  private openItemEditor(item?: ItemDraft): void {
    if (item) {
      this.editingItem = ExaminationReportDraftMapping.cloneItemDraft(item);
      return;
    }
    const draft = new ItemDraft();
    draft.id = ExaminationReportDraftMapping.newItemId();
    if (this.pageType === 'laboratory') {
      draft.category = this.labPrimaryCategory.trim().length > 0 ? this.labPrimaryCategory.trim() : undefined;
      draft.subCategory = this.labSubCategory.trim().length > 0 ? this.labSubCategory.trim() : undefined;
    }
    this.editingItem = draft;
  }

  private mergeEditedItem(newItem: ItemDraft): void {
    const replacingId = this.editingItem?.id ?? newItem.id;
    let found = false;
    const next: ItemDraft[] = [];
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].id === replacingId) {
        next.push(ExaminationReportDraftMapping.cloneItemDraft(newItem));
        found = true;
      } else {
        next.push(this.items[i]);
      }
    }
    if (!found) {
      next.push(ExaminationReportDraftMapping.cloneItemDraft(newItem));
    }
    this.items = next;
    this.closeItemEditor();
  }

  private chipSubtitle(item: ItemDraft): string {
    if (this.pageType === 'laboratory') {
      return `结果 ${item.resultValue ?? '—'}`;
    }
    const diag = (item.diagnosis ?? '').trim();
    if (diag.length > 0) {
      return diag.length > 80 ? `${diag.substring(0, 80)}…` : diag;
    }
    const part = (item.bodyPart ?? '').trim();
    if (part.length > 0) {
      return part;
    }
    return item.resultValue ?? '—';
  }

  private setPageType(next: ExaminationReportCategory): void {
    this.pageType = next;
    this.category = next;
  }

  private keyboardFocusChanged(visible: boolean): void {
    this.formKeyboardVisible = visible;
  }

  private emptyStateTitle(isPathology: boolean): string {
    if (this.pageType === 'laboratory') {
      return '暂无检验项目';
    }
    return isPathology ? '暂无病理项目' : '暂无影像项目';
  }

  private emptyStateSubtitle(isPathology: boolean): string {
    if (this.pageType === 'laboratory') {
      return '点击上方按钮添加检验指标';
    }
    return isPathology ? '点击上方按钮录入病理所见' : '点击上方按钮录入影像所见';
  }

  private emptyStateHint(isPathology: boolean): string {
    if (this.pageType === 'laboratory') {
      return '支持录入结果值、参考范围与异常标记';
    }
    return isPathology ? '可填写部位、诊断与检查结论' : '可填写部位、所见与诊断印象';
  }

  private addItemButtonLabel(isPathology: boolean): string {
    if (this.pageType === 'laboratory') {
      return '添加检验项目';
    }
    return isPathology ? '添加病理项目' : '添加影像项目';
  }

  private categoryMenuOptions(): ExamFormBindMenuItem[] {
    const options: ExamFormBindMenuItem[] = [];
    for (let i = 0; i < EXAMINATION_REPORT_CATEGORY_ALL.length; i++) {
      const category = EXAMINATION_REPORT_CATEGORY_ALL[i];
      options.push(new ExamFormBindMenuItem(examinationCategoryTitle(category), (): void => {
        this.setPageType(category);
      }));
    }
    return options;
  }

  private dismissKeyboard(): void {
    this.formKeyboardVisible = false;
  }

  @Builder
  private itemChip(item: ItemDraft) {
    Column({ space: 6 }) {
      Text((item.itemName ?? '').length > 0 ? (item.itemName ?? '') : '未命名项目')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
        .width('100%')
      Text(this.chipSubtitle(item))
        .fontSize(13)
        .fontColor('#8E8E93')
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F9F9FB')
    .borderRadius(12)
    .border({ width: 1, color: '#EBEBF0' })
    .onClick(() => {
      this.openItemEditor(item);
    })
  }

  @Builder
  private itemChipList() {
    Column({ space: 8 }) {
      ForEach(this.items, (item: ItemDraft) => {
        this.itemChip(item)
      }, (item: ItemDraft): string => `exam-item-${item.id}`)
    }
    .width('100%')
  }

  @Builder
  private emptyState(isPathology: boolean) {
    Column({ space: 10 }) {
      SymbolGlyph(examinationCategoryIcon(this.pageType))
        .fontSize(52)
        .fontColor(['#D1D1D6'])
        .opacity(0.65)
      Text(this.emptyStateTitle(isPathology))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8E8E93')
        .width('100%')
        .textAlign(TextAlign.Center)
      Text(this.emptyStateSubtitle(isPathology))
        .fontSize(14)
        .fontColor('#AEAEB2')
        .width('100%')
        .textAlign(TextAlign.Center)
      Text(this.emptyStateHint(isPathology))
        .fontSize(12)
        .fontColor('#C7C7CC')
        .width('100%')
        .textAlign(TextAlign.Center)
        .lineHeight(18)
    }
    .width('100%')
    .padding({ top: 20, bottom: 20, left: 12, right: 12 })
  }

  @Builder
  private laboratoryModule() {
    Column({ space: 16 }) {
      SparkLabExamCategoryCascadeRow({
        primaryTitle: '默认一级分类',
        secondaryTitle: '默认二级分类',
        primaryPlaceholder: '如 血常规',
        secondaryPlaceholder: '如 肝功能（可选）',
        primaryRequired: true,
        primary: $labPrimaryCategory,
        secondary: $labSubCategory
      })
      ExamFormAddItemButton({
        label: this.addItemButtonLabel(false),
        onTap: (): void => {
          this.openItemEditor();
        }
      })
      if (this.items.length === 0) {
        this.emptyState(false)
      }
      this.itemChipList()
    }
    .width('100%')
  }

  @Builder
  private imagingPathologyModule(isPathology: boolean) {
    Column({ space: 16 }) {
      ExamFormAddItemButton({
        label: this.addItemButtonLabel(isPathology),
        onTap: (): void => {
          this.openItemEditor();
        }
      })
      if (this.items.length === 0) {
        this.emptyState(isPathology)
      }
      this.itemChipList()
    }
    .width('100%')
  }

  @Builder
  private examTypeSection() {
    ExamFormInsetCard({ title: '检查类型' }) {
      Column({ space: 16 }) {
        ExamFormMenuPickerRow({
          label: '',
          displayValue: examinationCategoryTitle(this.pageType),
          placeholder: '请选择检查类型',
          required: false,
          menuOptions: this.categoryMenuOptions()
        })
        this.examTypeModule()
      }
      .width('100%')
    }
  }

  @Builder
  private examTypeModule() {
    if (this.pageType === 'laboratory') {
      this.laboratoryModule()
    } else if (this.pageType === 'pathology') {
      this.imagingPathologyModule(true)
    } else {
      this.imagingPathologyModule(false)
    }
  }

  @Builder
  private itemSheetBody(draft: ItemDraft) {
    if (this.pageType === 'laboratory') {
      AddLabItemSheet({
        initialDraft: draft,
        onSubmit: (item: ItemDraft) => {
          this.mergeEditedItem(item);
        },
        onCancel: () => {
          this.closeItemEditor();
        }
      })
    } else if (this.pageType === 'pathology') {
      AddPathologyReportItemSheet({
        initialDraft: draft,
        onSubmit: (item: ItemDraft) => {
          this.mergeEditedItem(item);
        },
        onCancel: () => {
          this.closeItemEditor();
        }
      })
    } else {
      AddImagingReportItemSheet({
        initialDraft: draft,
        onSubmit: (item: ItemDraft) => {
          this.mergeEditedItem(item);
        },
        onCancel: () => {
          this.closeItemEditor();
        }
      })
    }
  }

  @Builder
  private itemSheetContent() {
    if (this.editingItem !== undefined) {
      this.itemSheetBody(this.editingItem)
    } else {
      Column()
    }
  }

  @Builder
  private basicInfoCard() {
    ExamFormCard({
      title: '基本信息',
      titleIcon: $r('sys.symbol.calendar')
    }) {
      Column({ space: 18 }) {
        ExamFormDateField({
          label: '检查日期',
          examDay: $examDay,
          dateText: $date
        })

        ExamFormDivider()

        ExamFormTextField({
          label: '报告标题',
          placeholder: '如 苏州大学附属第四医院检验报告单',
          required: true,
          value: $title,
          onKeyboardFocus: (visible: boolean): void => {
            this.keyboardFocusChanged(visible);
          }
        })

        this.examTypeSection()

        ExamFormDivider()

        ExamFormTextField({
          label: '医院',
          placeholder: '如 苏州市立医院',
          value: $hospital,
          onKeyboardFocus: (visible: boolean): void => {
            this.keyboardFocusChanged(visible);
          }
        })
        ExamFormTextField({
          label: '医生',
          placeholder: '如 王医生',
          value: $doctor,
          onKeyboardFocus: (visible: boolean): void => {
            this.keyboardFocusChanged(visible);
          }
        })

        ExamFormDivider()

        ExamFormTextAreaField({
          label: '报告内容',
          placeholder: '检查所见、印象或补充说明',
          value: $content,
          onKeyboardFocus: (visible: boolean): void => {
            this.keyboardFocusChanged(visible);
          }
        })
      }
      .width('100%')
    }
  }

  @Builder
  private formHeader() {
    Text(this.navTitle())
      .fontSize(17)
      .fontWeight(FontWeight.Medium)
      .fontColor('#1C1C1E')
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding({ left: 20, right: 20, top: 8, bottom: 12 })
  }

  build() {
    Column() {
      this.formHeader()

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(13)
          .fontColor('#FF3B30')
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 8 })
      }

      Scroll() {
        Column({ space: 16 }) {
          this.basicInfoCard()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      ExamFormBottomBar({
        canSubmit: !this.isSaving,
        saveTitle: this.saveTitle(),
        keyboardVisible: this.formKeyboardVisible,
        onKeyboardDone: (): void => {
          this.dismissKeyboard();
        },
        onCancel: () => {
          const fields = new LogFields();
          fields.operation = 'exam_report_form.cancel';
          fields.detail = `mode=${this.modeLogLabel()}`;
          Logger.info('exam_report_form.cancel', LogModule.HOME, fields);
          if (this.onCancel) {
            this.onCancel();
          }
        },
        onSave: () => {
          void this.saveNow();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(EXAM_FORM_PAGE_BACKGROUND)
    .bindSheet(this.itemSheetVisible(), this.itemSheetContent, {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: false,
      backgroundColor: EXAM_FORM_PAGE_BACKGROUND,
      onDisappear: () => {
        this.closeItemEditor();
      }
    })
  }
}
