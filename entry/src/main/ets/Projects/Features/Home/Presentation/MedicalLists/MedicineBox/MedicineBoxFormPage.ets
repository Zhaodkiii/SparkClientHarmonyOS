import { Member } from '../../../../../Core/Domain/Entities/Member';
import { RemoteMedicineBox, RemoteManagedFile } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { SparkMedicalWorkflowAPI } from '../../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { ExaminationReportDraftMapping } from '../ExaminationReports/ExaminationReportDraftMapping';
import {
  EXAM_FORM_PAGE_BACKGROUND,
  ExamFormBindMenuItem,
  ExamFormBottomBar,
  ExamFormCard,
  ExamFormCompactMenuRow,
  ExamFormDateField,
  ExamFormMenuCustomRow,
  ExamFormMenuSection,
  ExamFormSheetHeader,
  ExamFormSheetPickerRow,
  ExamFormTextAreaField,
  ExamFormTextField,
  ExamFormToggleRow
} from '../../../../MedicalRecord/Presentation/NewRecord/Forms/ExamFormFieldSupport';
import { MedicalAttachmentInput, MedicalDocumentAttachmentUploader } from '../MedicalDocumentAttachmentUploader';
import { MedicalDocumentFilePickerMenu } from '../MedicalDocumentFilePicker';
import { MedicineBoxDosageFormCatalog } from './MedicineBoxDosageFormCatalog';
import { MedicineBoxDosageFormPickerSheet } from './MedicineBoxDosageFormPickerSheet';
import { MedicineBoxFormModel } from './MedicineBoxFormModel';
import { MedicineBoxMode } from './MedicineBoxMode';
import { MedicineBoxTypeCatalog } from './MedicineBoxTypeCatalog';

/** 药品创建/编辑表单 Sheet，对齐 iOS `MedicineBoxFormView`。 */
@Component
export struct MedicineBoxFormPage {
  existing?: RemoteMedicineBox;
  @Prop entryMemberID: number = 0;
  @Prop mode: MedicineBoxMode = MedicineBoxMode.FAMILY;
  @Prop allowsHouseholdPublic: boolean = false;
  @Prop members: Member[] = [];
  @Prop typeOptions: string[] = MedicineBoxTypeCatalog.defaults;
  workflow?: SparkMedicalWorkflowAPI;
  attachmentUploader?: MedicalDocumentAttachmentUploader;
  onClose?: () => void;
  onSave?: (model: MedicineBoxFormModel, id?: number) => Promise<void>;

  @State private name: string = '';
  @State private type: string = '';
  @State private brand: string = '';
  @State private dosageForm: string = '';
  @State private strength: string = '';
  @State private doseUnit: string = '';
  @State private quantity: string = '';
  @State private hasExpireDate: boolean = false;
  @State private expireDate: string = '';
  @State private expireDay: Date = new Date();
  @State private notes: string = '';
  @State private bindingMemberID?: number = undefined;
  @State private submitting: boolean = false;
  @State private errorText: string = '';
  @State private savedAttachments: RemoteManagedFile[] = [];
  @State private pendingAttachments: MedicalAttachmentInput[] = [];
  @State private attachmentStatus: string = '';
  @State private sheetKeyboardVisible: boolean = false;
  @State private showDosageFormSheet: boolean = false;

  aboutToAppear(): void {
    if (this.existing) {
      const model = MedicineBoxFormModel.fromBox(this.existing);
      this.name = model.medicineName;
      this.type = model.medicineType;
      this.brand = model.brandName;
      this.dosageForm = MedicineBoxDosageFormCatalog.storedValue(model.dosageForm);
      this.strength = model.strength;
      this.doseUnit = model.doseUnit;
      this.quantity = model.totalQuantity;
      this.hasExpireDate = model.hasExpireDate;
      this.expireDate = model.expireDate;
      this.expireDay = ExaminationReportDraftMapping.parseDate(model.expireDate);
      this.notes = model.notes;
      this.bindingMemberID = model.bindingMemberID;
      this.savedAttachments = model.attachments;
    } else if (!this.allowsHouseholdPublic || this.mode === MedicineBoxMode.PERSONAL) {
      this.bindingMemberID = this.entryMemberID;
    }
  }

  private navigationTitle(): string {
    return this.existing ? '编辑药品' : '添加药品';
  }

  private canSubmit(): boolean {
    return !this.submitting && this.name.trim().length > 0;
  }

  private model(): MedicineBoxFormModel {
    const model = new MedicineBoxFormModel();
    model.medicineName = this.name;
    model.medicineType = this.type;
    model.brandName = this.brand;
    model.dosageForm = this.dosageForm;
    model.strength = this.strength;
    model.doseUnit = this.doseUnit;
    model.totalQuantity = this.quantity;
    model.hasExpireDate = this.hasExpireDate;
    model.expireDate = this.expireDate;
    model.notes = this.notes;
    model.bindingMemberID = this.allowsHouseholdPublic ? this.bindingMemberID : this.entryMemberID;
    model.attachments = this.savedAttachments;
    model.fileIds = this.savedAttachments.map((file: RemoteManagedFile): number => file.id);
    return model;
  }

  private uploaderMemberID(): number {
    if (!this.allowsHouseholdPublic || this.mode === MedicineBoxMode.PERSONAL) {
      return this.entryMemberID;
    }
    return this.bindingMemberID ?? this.entryMemberID;
  }

  private ownershipDisplayValue(): string {
    if (this.bindingMemberID === undefined) {
      return '家庭公共';
    }
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].id === this.bindingMemberID) {
        return this.members[i].name;
      }
    }
    return '当前成员';
  }

  private ownershipMenuItems(): ExamFormBindMenuItem[] {
    const items: ExamFormBindMenuItem[] = [];
    items.push(new ExamFormBindMenuItem('家庭公共', (): void => {
      this.bindingMemberID = undefined;
    }));
    if (this.members.length === 0) {
      items.push(new ExamFormBindMenuItem('当前成员', (): void => {
        this.bindingMemberID = this.entryMemberID;
      }));
      return items;
    }
    for (let i = 0; i < this.members.length; i++) {
      const member = this.members[i];
      items.push(new ExamFormBindMenuItem(member.name, (): void => {
        this.bindingMemberID = member.id;
      }));
    }
    return items;
  }

  private typeSections(): ExamFormMenuSection[] {
    const options = this.typeOptions.length > 0 ? this.typeOptions : MedicineBoxTypeCatalog.defaults;
    return [
      new ExamFormMenuSection('', options)
    ];
  }

  private keyboardFocusChanged(visible: boolean): void {
    this.sheetKeyboardVisible = visible;
  }

  private dismissKeyboard(): void {
    this.sheetKeyboardVisible = false;
  }

  private removePendingAttachment(previewId: string): void {
    this.pendingAttachments = this.pendingAttachments.filter(
      (item: MedicalAttachmentInput): boolean => item.previewId !== previewId
    );
  }

  private async uploadPendingAttachmentsIfNeeded(): Promise<number[]> {
    const existingIds = this.savedAttachments.map((file: RemoteManagedFile): number => file.id);
    const uploader = this.attachmentUploader;
    if (this.pendingAttachments.length === 0 || !uploader) {
      return existingIds;
    }
    const memberID = this.uploaderMemberID();
    const uploadedIds: number[] = [];
    for (let i = 0; i < this.pendingAttachments.length; i++) {
      const item = this.pendingAttachments[i];
      this.attachmentStatus = `正在上传 ${item.originalName}`;
      const record = await uploader.upload(item, memberID, (progress: number) => {
        this.attachmentStatus = `${item.originalName} ${Math.round(progress * 100)}%`;
      });
      uploadedIds.push(record.id);
    }
    this.attachmentStatus = '';
    this.pendingAttachments = [];
    return existingIds.concat(uploadedIds);
  }

  private async save(): Promise<void> {
    if (this.submitting) {
      return;
    }
    const model = this.model();
    const validation = model.validate();
    if (validation.length > 0) {
      this.errorText = validation;
      return;
    }
    this.submitting = true;
    this.errorText = '';
    try {
      model.fileIds = await this.uploadPendingAttachmentsIfNeeded();
      await this.onSave?.(model, this.existing?.id);
    } catch (e) {
      this.errorText = `${e}`;
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  private ownershipSection() {
    if (this.allowsHouseholdPublic) {
      ExamFormCard({
        title: '归属',
        titleIcon: $r('sys.symbol.person_2_fill')
      }) {
        ExamFormCompactMenuRow({
          leftTitle: '归属',
          displayValue: this.ownershipDisplayValue(),
          placeholder: '家庭公共',
          menuOptions: this.ownershipMenuItems()
        })
      }
    }
  }

  @Builder
  private medicineInfoSection() {
    ExamFormCard({
      title: '药品信息',
      titleIcon: $r('sys.symbol.heart_fill')
    }) {
      Column({ space: 12 }) {
        ExamFormTextField({
          label: '药品名称',
          placeholder: '如 对乙酰氨基酚或泰诺林',
          required: true,
          value: $name,
          onKeyboardFocus: (visible: boolean): void => {
            this.keyboardFocusChanged(visible);
          }
        })

        ExamFormToggleRow({
          label: '设置有效期',
          isOn: $hasExpireDate
        })

        if (this.hasExpireDate) {
          ExamFormDateField({
            label: '有效期',
            examDay: $expireDay,
            dateText: $expireDate
          })
        }

        ExamFormMenuCustomRow({
          label: '药品类型',
          sections: this.typeSections(),
          customMenuTitle: '自定义类型',
          customPlaceholder: '输入药品类型',
          placeholder: '输入药品类型',
          customAutofocus: false,
          value: $type,
          onKeyboardFocus: (visible: boolean): void => {
            this.keyboardFocusChanged(visible);
          }
        })

        ExamFormSheetPickerRow({
          label: '剂型',
          displayValue: MedicineBoxDosageFormCatalog.displayString(this.dosageForm),
          placeholder: '请选择剂型',
          onTap: (): void => {
            this.showDosageFormSheet = true;
          }
        })

        ExamFormTextField({
          label: '规格',
          placeholder: '如 0.5g×24片',
          value: $strength,
          onKeyboardFocus: (visible: boolean): void => {
            this.keyboardFocusChanged(visible);
          }
        })

        ExamFormTextField({
          label: '总数量',
          placeholder: '如 24',
          value: $quantity,
          onKeyboardFocus: (visible: boolean): void => {
            this.keyboardFocusChanged(visible);
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private moreInfoSection() {
    ExamFormCard({
      title: '更多信息',
      titleIcon: $r('sys.symbol.square_stack_3d')
    }) {
      Column({ space: 12 }) {
        ExamFormTextField({
          label: '品牌',
          placeholder: '可选',
          value: $brand,
          onKeyboardFocus: (visible: boolean): void => {
            this.keyboardFocusChanged(visible);
          }
        })

        ExamFormTextAreaField({
          label: '备注',
          placeholder: '用法、存放位置或注意事项',
          value: $notes,
          onKeyboardFocus: (visible: boolean): void => {
            this.keyboardFocusChanged(visible);
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private attachmentSection() {
    ExamFormCard({
      title: '附件',
      titleIcon: $r('sys.symbol.paperclip')
    }) {
      Column({ space: 12 }) {
        if (this.savedAttachments.length > 0) {
          Column({ space: 6 }) {
            Text('已保存')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#8E8E93')
              .width('100%')
            ForEach(this.savedAttachments, (file: RemoteManagedFile) => {
              Row() {
                SymbolGlyph($r('sys.symbol.paperclip'))
                  .fontSize(14)
                  .fontColor(['#8E8E93'])
                  .margin({ right: 6 })
                Text(file.originalName ?? '')
                  .fontSize(15)
                  .fontColor('#1C1C1E')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
            }, (file: RemoteManagedFile): string => `saved-${file.id}`)
          }
          .width('100%')
        }

        if (this.pendingAttachments.length > 0) {
          Column({ space: 6 }) {
            Text('待上传')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#8E8E93')
              .width('100%')
            ForEach(this.pendingAttachments, (item: MedicalAttachmentInput) => {
              Row() {
                SymbolGlyph($r('sys.symbol.doc_text'))
                  .fontSize(14)
                  .fontColor(['#0A84FF'])
                  .margin({ right: 6 })
                Text(item.originalName)
                  .fontSize(15)
                  .fontColor('#1C1C1E')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text('移除')
                  .fontSize(13)
                  .fontColor('#FF3B30')
                  .onClick(() => this.removePendingAttachment(item.previewId))
              }
              .width('100%')
            }, (item: MedicalAttachmentInput): string => `pending-${item.previewId}`)
          }
          .width('100%')
        }

        if (this.attachmentStatus.length > 0) {
          Text(this.attachmentStatus)
            .fontSize(13)
            .fontColor('#8E8E93')
            .width('100%')
        }

        MedicalDocumentFilePickerMenu({
          maxSelectionCount: 10,
          disabled: this.submitting,
          onFilesSelected: (files: MedicalAttachmentInput[]) => {
            this.pendingAttachments = this.pendingAttachments.concat(files);
          }
        }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.plus_circle_fill'))
              .fontSize(16)
              .fontColor(['#0A84FF'])
            Text('添加附件')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0A84FF')
          }
          .width('100%')
          .height(40)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .border({ width: 1, color: '#D6E8FF' })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private formBody() {
    Column({ space: 14 }) {
      this.ownershipSection()
      this.medicineInfoSection()
      this.moreInfoSection()
      if (this.attachmentUploader) {
        this.attachmentSection()
      }
      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(13)
          .fontColor('#FF3B30')
          .width('100%')
          .padding({ left: 4, right: 4 })
      }
      Blank().height(8)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private dosageFormSheetBuilder() {
    MedicineBoxDosageFormPickerSheet({
      selectedValue: this.dosageForm,
      onSelect: (value: string): void => {
        this.dosageForm = value;
        this.showDosageFormSheet = false;
      },
      onClose: (): void => {
        this.showDosageFormSheet = false;
      }
    })
  }

  build() {
    Column() {
      ExamFormSheetHeader({ title: this.navigationTitle() })

      Scroll() {
        this.formBody()
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 16, right: 16, top: 4, bottom: 24 })

      ExamFormBottomBar({
        canSubmit: this.canSubmit(),
        saveTitle: this.submitting ? '保存中' : '完成',
        keyboardVisible: this.sheetKeyboardVisible,
        onKeyboardDone: (): void => {
          this.dismissKeyboard();
        },
        onCancel: (): void => {
          if (!this.submitting) {
            this.onClose?.();
          }
        },
        onSave: (): void => {
          void this.save();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(EXAM_FORM_PAGE_BACKGROUND)
    .bindSheet($$this.showDosageFormSheet, this.dosageFormSheetBuilder(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: false,
      backgroundColor: EXAM_FORM_PAGE_BACKGROUND,
      onDisappear: (): void => {
        this.showDosageFormSheet = false;
      }
    })
  }
}
