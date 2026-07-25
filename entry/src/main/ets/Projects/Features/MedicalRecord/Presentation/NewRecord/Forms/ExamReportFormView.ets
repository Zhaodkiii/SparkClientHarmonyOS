import { RemoteExaminationReportWithAttachments } from
  '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { ItemDraft, MedicalReportRecognitionDraft } from
  '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import {
  ExaminationReportCategory,
  examinationCategoryTitle
} from '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportCategory';
import { ExaminationReportDraftMapping } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDraftMapping';
import { ExaminationReportServerMutationService } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportServerMutationService';
import { MedicalReportResultSupport } from
  '../../../../MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportResultSupport';
import { AddImagingReportItemSheet } from './AddImagingReportItemSheet';
import { AddLabItemSheet } from './AddLabItemSheet';
import { AddPathologyReportItemSheet } from './AddPathologyReportItemSheet';
import { ExamFormBottomBar, ExamFormTextAreaField, ExamFormTextField } from './ExamFormFieldSupport';
import { ExamReportFormModeKind } from './ExamReportFormMode';

/**
 * 医疗检查报告编辑表单。对齐 iOS `ExamReportFormView`：
 * 支持 create / serverEdit / localEdit 三种模式。
 */
@Component
export struct ExamReportFormView {
  @Prop modeKind: ExamReportFormModeKind = ExamReportFormModeKind.SERVER_EDIT;
  @Prop @Watch('onFormSessionChanged') formSession: number = 0;
  existingReport?: RemoteExaminationReportWithAttachments;
  existingDraft?: MedicalReportRecognitionDraft;
  mutationService?: ExaminationReportServerMutationService;
  onLocalSubmit?: (draft: MedicalReportRecognitionDraft) => void;
  onServerSaved?: (draft: MedicalReportRecognitionDraft) => void;
  onCancel?: () => void;

  @State private pageType: ExaminationReportCategory = 'laboratory';
  @State private category: string = 'laboratory';
  @State private title: string = '';
  @State private hospital: string = '';
  @State private doctor: string = '';
  @State private content: string = '';
  @State private date: string = '';
  @State private labPrimaryCategory: string = '';
  @State private labSubCategory: string = '';
  @State private items: ItemDraft[] = [];
  @State private showItemSheet: boolean = false;
  @State private editingItem: ItemDraft = new ItemDraft();
  @State private isSaving: boolean = false;
  @State private errorText: string = '';

  aboutToAppear(): void {
    this.seedFromProps();
  }

  private onFormSessionChanged(): void {
    this.seedFromProps();
  }

  private seedFromProps(): void {
    let seed = new MedicalReportRecognitionDraft();
    if (this.modeKind === ExamReportFormModeKind.LOCAL_EDIT && this.existingDraft) {
      seed = ExaminationReportDraftMapping.cloneDraft(this.existingDraft);
    } else if (this.modeKind === ExamReportFormModeKind.SERVER_EDIT && this.existingReport) {
      seed = ExaminationReportDraftMapping.examinationDraftFromReport(this.existingReport);
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
    this.date = (seed.date ?? '').length > 0 ? (seed.date ?? '') : ExaminationReportDraftMapping.todayDateText();
    const clonedItems: ItemDraft[] = [];
    for (let i = 0; i < seed.details.length; i++) {
      clonedItems.push(ExaminationReportDraftMapping.cloneItemDraft(seed.details[i]));
    }
    this.items = clonedItems;
    if (this.pageType === 'laboratory' && seed.details.length > 0) {
      this.labPrimaryCategory = seed.details[0].category ?? '';
      this.labSubCategory = seed.details[0].subCategory ?? '';
    }
  }

  private navTitle(): string {
    if (this.modeKind === ExamReportFormModeKind.CREATE) {
      return '新建检查报告';
    }
    if (this.modeKind === ExamReportFormModeKind.LOCAL_EDIT) {
      return '编辑检查报告';
    }
    return '更新检查报告';
  }

  private saveTitle(): string {
    if (this.modeKind === ExamReportFormModeKind.LOCAL_EDIT) {
      return '完成';
    }
    if (this.modeKind === ExamReportFormModeKind.SERVER_EDIT) {
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
    if (this.existingDraft) {
      draft.attachmentFileIds = this.existingDraft.attachmentFileIds.slice();
    }
    return draft;
  }

  private async saveNow(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    const draft = this.buildDraft();
    this.errorText = '';

    if (this.modeKind === ExamReportFormModeKind.LOCAL_EDIT) {
      if (this.onLocalSubmit) {
        this.onLocalSubmit(draft);
      }
      if (this.onCancel) {
        this.onCancel();
      }
      return;
    }

    if (this.modeKind === ExamReportFormModeKind.SERVER_EDIT) {
      const report = this.existingReport;
      const service = this.mutationService;
      if (!report || !service) {
        this.errorText = '保存配置缺失';
        return;
      }
      this.isSaving = true;
      try {
        await service.updateReportWithDraft(report, draft);
        if (this.onServerSaved) {
          this.onServerSaved(draft);
        }
        if (this.onCancel) {
          this.onCancel();
        }
      } catch (e) {
        this.errorText = `${e}`;
      } finally {
        this.isSaving = false;
      }
      return;
    }

    this.errorText = '新建模式尚未接入';
  }

  private mergeEditedItem(newItem: ItemDraft, replacingId: string): void {
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
    this.showItemSheet = false;
  }

  private presentNewLabItem(): void {
    const draft = new ItemDraft();
    draft.id = ExaminationReportDraftMapping.newItemId();
    draft.category = this.labPrimaryCategory.trim().length > 0 ? this.labPrimaryCategory.trim() : undefined;
    draft.subCategory = this.labSubCategory.trim().length > 0 ? this.labSubCategory.trim() : undefined;
    this.editingItem = draft;
    this.showItemSheet = true;
  }

  private presentNewGenericItem(): void {
    const draft = new ItemDraft();
    draft.id = ExaminationReportDraftMapping.newItemId();
    this.editingItem = draft;
    this.showItemSheet = true;
  }

  private openItem(item: ItemDraft): void {
    this.editingItem = ExaminationReportDraftMapping.cloneItemDraft(item);
    this.showItemSheet = true;
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

  @Builder
  private categoryChip(category: ExaminationReportCategory) {
    Text(examinationCategoryTitle(category))
      .fontSize(13)
      .fontColor(this.pageType === category ? '#FFFFFF' : '#0A84FF')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(this.pageType === category ? '#0A84FF' : '#EAF3FF')
      .borderRadius(16)
      .onClick(() => {
        this.setPageType(category);
      })
  }

  @Builder
  private itemChip(item: ItemDraft) {
    Column({ space: 4 }) {
      Text((item.itemName ?? '').length > 0 ? (item.itemName ?? '') : '未命名项目')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
        .width('100%')
      Text(this.chipSubtitle(item))
        .fontSize(12)
        .fontColor('#8E8E93')
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#FFFFFF')
    .borderRadius(10)
    .onClick(() => {
      this.openItem(item);
    })
  }

  @Builder
  private laboratoryModule() {
    Column({ space: 12 }) {
      ExamFormTextField({
        label: '默认一级分类',
        placeholder: '新建项目时带入',
        value: $labPrimaryCategory
      })
      ExamFormTextField({
        label: '默认二级分类',
        placeholder: '可选',
        value: $labSubCategory
      })
      Button('添加检验项目')
        .width('100%')
        .backgroundColor('#EAF3FF')
        .fontColor('#0A84FF')
        .onClick(() => {
          this.presentNewLabItem();
        })
      if (this.items.length === 0) {
        Text('暂无检验项目，点击上方按钮添加')
          .fontSize(13)
          .fontColor('#8E8E93')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
      }
      Column({ space: 8 }) {
        ForEach(this.items, (item: ItemDraft) => {
          this.itemChip(item)
        }, (item: ItemDraft): string => `exam-item-${item.id}`)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private imagingPathologyModule(isPathology: boolean) {
    Column({ space: 12 }) {
      Button(isPathology ? '添加病理项目' : '添加影像项目')
        .width('100%')
        .backgroundColor('#EAF3FF')
        .fontColor('#0A84FF')
        .onClick(() => {
          this.presentNewGenericItem();
        })
      if (this.items.length === 0) {
        Text(isPathology ? '暂无病理项目' : '暂无影像项目')
          .fontSize(13)
          .fontColor('#8E8E93')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
      }
      Column({ space: 8 }) {
        ForEach(this.items, (item: ItemDraft) => {
          this.itemChip(item)
        }, (item: ItemDraft): string => `exam-item-${item.id}`)
      }
      .width('100%')
    }
    .width('100%')
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
  private itemSheetContent() {
    if (this.pageType === 'laboratory') {
      AddLabItemSheet({
        initialDraft: this.editingItem,
        onSubmit: (draft: ItemDraft) => {
          this.mergeEditedItem(draft, this.editingItem.id);
        },
        onCancel: () => {
          this.showItemSheet = false;
        }
      })
    } else if (this.pageType === 'pathology') {
      AddPathologyReportItemSheet({
        initialDraft: this.editingItem,
        onSubmit: (draft: ItemDraft) => {
          this.mergeEditedItem(draft, this.editingItem.id);
        },
        onCancel: () => {
          this.showItemSheet = false;
        }
      })
    } else {
      AddImagingReportItemSheet({
        initialDraft: this.editingItem,
        onSubmit: (draft: ItemDraft) => {
          this.mergeEditedItem(draft, this.editingItem.id);
        },
        onCancel: () => {
          this.showItemSheet = false;
        }
      })
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.navTitle())
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(13)
          .fontColor('#FF3B30')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
      }

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 12 }) {
            Text('基本信息')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')

            ExamFormTextField({
              label: '检查日期',
              placeholder: 'yyyy-MM-dd',
              value: $date
            })
            ExamFormTextField({
              label: '报告标题',
              placeholder: '请输入报告标题',
              required: true,
              value: $title
            })

            Column({ space: 8 }) {
              Text('检查类型')
                .fontSize(13)
                .fontColor('#666666')
                .width('100%')
              Row({ space: 8 }) {
                this.categoryChip('laboratory')
                this.categoryChip('imaging')
                this.categoryChip('pathology')
              }
              .width('100%')
            }
            .width('100%')

            this.examTypeModule()

            ExamFormTextField({
              label: '医院',
              placeholder: '检查机构',
              value: $hospital
            })
            ExamFormTextField({
              label: '医生',
              placeholder: '检查医生',
              value: $doctor
            })
            ExamFormTextAreaField({
              label: '报告内容',
              placeholder: '检查内容、所见或备注',
              value: $content
            })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .layoutWeight(1)

      ExamFormBottomBar({
        canSubmit: !this.isSaving,
        saveTitle: this.saveTitle(),
        onCancel: () => {
          if (this.onCancel) {
            this.onCancel();
          }
        },
        onSave: () => {
          this.saveNow();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
    .bindSheet(this.showItemSheet, this.itemSheetContent, {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: true,
      onDisappear: () => {
        this.showItemSheet = false;
      }
    })
  }
}
