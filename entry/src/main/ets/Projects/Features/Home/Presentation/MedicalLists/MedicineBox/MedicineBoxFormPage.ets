import { Member } from '../../../../../Core/Domain/Entities/Member';
import { RemoteMedicineBox, RemoteManagedFile } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { SparkMedicalWorkflowAPI } from '../../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { MedicineBoxFormModel } from './MedicineBoxFormModel';
import { MedicineBoxMode } from './MedicineBoxMode';
import { MedicalAttachmentInput, MedicalDocumentAttachmentUploader } from '../MedicalDocumentAttachmentUploader';
import { MedicalDocumentFilePickerMenu } from '../MedicalDocumentFilePicker';

/** 药品创建/编辑表单 Sheet，对齐 iOS `MedicineBoxFormView` 核心字段 */
@Component
export struct MedicineBoxFormPage {
  existing?: RemoteMedicineBox;
  @Prop entryMemberID: number = 0;
  @Prop mode: MedicineBoxMode = MedicineBoxMode.FAMILY;
  @Prop members: Member[] = [];
  workflow?: SparkMedicalWorkflowAPI;
  /** 已用当前账号/generation 装配好的上传器；未注入时不展示附件区（对齐 iOS `fileTransferService != nil` 判断） */
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
  @State private notes: string = '';
  @State private bindingMemberID?: number = undefined;
  @State private submitting: boolean = false;
  @State private errorText: string = '';
  @State private savedAttachments: RemoteManagedFile[] = [];
  @State private pendingAttachments: MedicalAttachmentInput[] = [];
  @State private attachmentStatus: string = '';

  aboutToAppear(): void {
    if (this.existing) {
      const model = MedicineBoxFormModel.fromBox(this.existing);
      this.name = model.medicineName;
      this.type = model.medicineType;
      this.brand = model.brandName;
      this.dosageForm = model.dosageForm;
      this.strength = model.strength;
      this.doseUnit = model.doseUnit;
      this.quantity = model.totalQuantity;
      this.hasExpireDate = model.hasExpireDate;
      this.expireDate = model.expireDate;
      this.notes = model.notes;
      this.bindingMemberID = model.bindingMemberID;
      this.savedAttachments = model.attachments;
    } else if (this.mode === MedicineBoxMode.PERSONAL) {
      this.bindingMemberID = this.entryMemberID;
    }
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
    model.bindingMemberID = this.bindingMemberID;
    model.attachments = this.savedAttachments;
    model.fileIds = this.savedAttachments.map((file: RemoteManagedFile): number => file.id);
    return model;
  }

  private uploaderMemberID(): number {
    if (this.mode === MedicineBoxMode.PERSONAL) {
      return this.entryMemberID;
    }
    return this.bindingMemberID ?? this.entryMemberID;
  }

  private removePendingAttachment(previewId: string): void {
    this.pendingAttachments = this.pendingAttachments.filter(
      (item: MedicalAttachmentInput): boolean => item.previewId !== previewId
    );
  }

  /** 保存前统一上传待处理附件，返回“已保存 + 新上传”的完整 fileIds；不做 OCR/识别 */
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
  fieldLabel(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor('#666666')
      .width('100%')
      .margin({ top: 8, bottom: 4 })
  }

  @Builder
  ownership() {
    if (this.mode === MedicineBoxMode.FAMILY) {
      Column({ space: 8 }) {
        Text('药品归属')
          .fontSize(13)
          .fontColor('#666666')
          .width('100%')
        Row({ space: 8 }) {
          Button('家庭公共')
            .fontSize(12)
            .backgroundColor(this.bindingMemberID === undefined ? '#DCEEFF' : '#F2F2F7')
            .fontColor('#1C1C1E')
            .onClick(() => this.bindingMemberID = undefined)
          Button('当前成员')
            .fontSize(12)
            .backgroundColor(this.bindingMemberID === this.entryMemberID ? '#DCEEFF' : '#F2F2F7')
            .fontColor('#1C1C1E')
            .onClick(() => this.bindingMemberID = this.entryMemberID)
        }
        Text(this.bindingMemberID === undefined ? '家庭公共药品' : `绑定成员 ID：${this.bindingMemberID}`)
          .fontSize(12)
          .fontColor('#888888')
      }
      .padding(14)
      .backgroundColor(Color.White)
      .borderRadius(14)
      .width('100%')
    }
  }

  @Builder
  attachmentCard() {
    Column({ space: 10 }) {
      Text('附件').fontSize(16).fontWeight(FontWeight.Medium).width('100%')

      if (this.savedAttachments.length > 0) {
        Column({ space: 6 }) {
          ForEach(this.savedAttachments, (file: RemoteManagedFile) => {
            Row() {
              SymbolGlyph($r('sys.symbol.paperclip'))
                .fontSize(14)
                .fontColor(['#888888'])
                .margin({ right: 6 })
              Text(file.originalName ?? '')
                .fontSize(13)
                .fontColor('#333333')
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
          ForEach(this.pendingAttachments, (item: MedicalAttachmentInput) => {
            Row() {
              SymbolGlyph($r('sys.symbol.doc_text'))
                .fontSize(14)
                .fontColor(['#0A84FF'])
                .margin({ right: 6 })
              Text(item.originalName)
                .fontSize(13)
                .fontColor('#333333')
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('移除')
                .fontSize(12)
                .fontColor('#D93025')
                .onClick(() => this.removePendingAttachment(item.previewId))
            }
            .width('100%')
          }, (item: MedicalAttachmentInput): string => `pending-${item.previewId}`)
        }
        .width('100%')
      }

      if (this.attachmentStatus.length > 0) {
        Text(this.attachmentStatus).fontSize(12).fontColor('#888888').width('100%')
      }

      MedicalDocumentFilePickerMenu({
        maxSelectionCount: 10,
        disabled: this.submitting,
        onFilesSelected: (files: MedicalAttachmentInput[]) => {
          this.pendingAttachments = this.pendingAttachments.concat(files);
        }
      }) {
        Text('＋ 添加报告')
          .fontSize(13)
          .fontColor('#0A84FF')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#F0F7FF')
          .borderRadius(8)
      }
    }
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(14)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row() {
        Text('取消').fontSize(15).fontColor('#0A84FF').onClick(() => this.onClose?.())
        Blank()
        Text(this.existing ? '编辑药品' : '新增药品').fontSize(18).fontWeight(FontWeight.Medium)
        Blank()
        Text(this.submitting ? '保存中' : '完成')
          .fontSize(15)
          .fontColor(this.submitting ? '#999999' : '#0A84FF')
          .onClick(() => this.save())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      Scroll() {
        Column({ space: 12 }) {
          this.ownership()
          Column() {
            Text('药品信息').fontSize(16).fontWeight(FontWeight.Medium).width('100%')
            this.fieldLabel('药品名称 *')
            TextInput({ text: this.name, placeholder: '请输入药品名称' }).onChange((v: string) => this.name = v)
            this.fieldLabel('药品类型')
            TextInput({ text: this.type, placeholder: '例如：抗菌消炎、感冒发烧' }).onChange((v: string) => this.type = v)
            this.fieldLabel('剂型')
            TextInput({ text: this.dosageForm, placeholder: '例如：片剂、胶囊' }).onChange((v: string) => this.dosageForm = v)
            this.fieldLabel('规格')
            TextInput({ text: this.strength, placeholder: '例如：0.25g' }).onChange((v: string) => this.strength = v)
            this.fieldLabel('剂量单位')
            TextInput({ text: this.doseUnit, placeholder: '例如：片、mg' }).onChange((v: string) => this.doseUnit = v)
            this.fieldLabel('总数量')
            TextInput({ text: this.quantity, placeholder: '请输入数量' }).onChange((v: string) => this.quantity = v)
            Row() {
              Text('设置有效期').fontSize(14).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.hasExpireDate }).onChange((v: boolean) => this.hasExpireDate = v)
            }
            if (this.hasExpireDate) {
              this.fieldLabel('有效期（YYYY-MM-DD）')
              TextInput({ text: this.expireDate, placeholder: '例如：2026-12-31' }).onChange((v: string) => this.expireDate = v)
            }
          }
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(14)

          Column() {
            Text('更多信息').fontSize(16).fontWeight(FontWeight.Medium).width('100%')
            this.fieldLabel('品牌')
            TextInput({ text: this.brand, placeholder: '请输入品牌' }).onChange((v: string) => this.brand = v)
            this.fieldLabel('备注')
            TextInput({ text: this.notes, placeholder: '请输入备注' }).onChange((v: string) => this.notes = v)
          }
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(14)

          if (this.attachmentUploader) {
            this.attachmentCard()
          }

          if (this.errorText.length > 0) {
            Text(this.errorText).fontSize(13).fontColor('#D93025').width('100%')
          }
          Blank().height(32)
        }
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
  }
}
