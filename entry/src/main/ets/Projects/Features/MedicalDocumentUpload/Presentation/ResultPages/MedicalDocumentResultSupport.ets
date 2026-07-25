import { MedicalAttachmentInput } from '../../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalUploadL10n } from '../../Domain/SupportingModels';
import { MedicalValidationIssueInlineView } from './PreSubmitValidation/MedicalValidationIssueInlineView';

/** 结果页分区卡片。对齐 iOS MedicalDocumentResultSectionCard（折叠子集）。 */
@Component
export struct MedicalDocumentResultSectionCard {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop badgeText: string = '';
  @Prop enableCollapse: boolean = false;
  @Prop forceExpanded: boolean = false;
  @Prop defaultCollapsed: boolean = false;
  @State private collapsed: boolean = false;
  @BuilderParam content: () => void = this.emptyContent;

  aboutToAppear(): void {
    this.collapsed = this.defaultCollapsed;
  }

  private showsContent(): boolean {
    return !this.enableCollapse || !this.collapsed || this.forceExpanded;
  }

  @Builder
  emptyContent() {
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text(this.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1C1E')
            .width('100%')
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(12)
              .fontColor('#8E8E93')
              .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.badgeText.length > 0) {
          Text(this.badgeText)
            .fontSize(11)
            .fontColor('#0A84FF')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#E8F2FF')
            .borderRadius(8)
            .margin({ right: 8 })
        }
        if (this.enableCollapse) {
          Text(this.showsContent() ? '收起' : '展开')
            .fontSize(12)
            .fontColor('#0A84FF')
        }
      }
      .width('100%')
      .onClick(() => {
        if (this.enableCollapse && !this.forceExpanded) {
          this.collapsed = !this.collapsed;
        }
      })

      if (this.showsContent()) {
        this.content()
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(14)
  }
}

/** 可编辑校验字段行。对齐 iOS MedicalValidatedResultInfoLine。 */
@Component
export struct MedicalValidatedEditableField {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop placeholder: string = '待补充';
  @Prop fieldKey: string = '';
  @Prop scrollTargetID: string = '';
  @Prop errorMessage: string = '';
  @Prop editable: boolean = true;
  onValueChange: (value: string) => void = (_value: string) => {};

  private anchorId(): string {
    if (this.scrollTargetID.length > 0) {
      return this.scrollTargetID;
    }
    if (this.fieldKey.length > 0) {
      return `preSubmitValidation.field.${this.fieldKey}`;
    }
    return this.label;
  }

  build() {
    Column({ space: 6 }) {
      Text(this.label)
        .fontSize(12)
        .fontColor('#8E8E93')
        .width('100%')
      if (this.editable) {
        TextInput({ text: this.value, placeholder: this.placeholder })
          .height(40)
          .fontSize(15)
          .fontColor('#1C1C1E')
          .backgroundColor(this.errorMessage.length > 0 ? '#FFF5F2' : '#F2F2F7')
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .onChange((v: string) => this.onValueChange(v))
      } else {
        Text(this.value.length > 0 ? this.value : this.placeholder)
          .fontSize(15)
          .fontColor(this.value.length > 0 ? '#1C1C1E' : '#AEAEB2')
          .width('100%')
      }
      if (this.errorMessage.length > 0) {
        MedicalValidationIssueInlineView({ message: this.errorMessage })
      }
    }
    .width('100%')
    .id(this.anchorId())
    .padding({ top: 4, bottom: 4 })
  }
}

/** 只读信息行。 */
@Component
export struct MedicalDocumentResultInfoLine {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop scrollTargetID: string = '';
  @Prop errorMessage: string = '';

  build() {
    Column({ space: 4 }) {
      Text(this.label)
        .fontSize(12)
        .fontColor('#8E8E93')
        .width('100%')
      Text(this.value.length > 0 ? this.value : '—')
        .fontSize(15)
        .fontColor(this.errorMessage.length > 0 ? '#C93400' : '#1C1C1E')
        .width('100%')
      if (this.errorMessage.length > 0) {
        MedicalValidationIssueInlineView({ message: this.errorMessage })
      }
    }
    .width('100%')
    .id(this.scrollTargetID.length > 0 ? this.scrollTargetID : this.label)
    .padding({ top: 4, bottom: 4 })
  }
}

/** 成员归属条。 */
@Component
export struct MedicalDocumentResultMemberBar {
  @Prop memberName: string = '';
  @Prop memberId: number = 0;
  @Prop kindLabel: string = '';

  build() {
    Row() {
      Column({ space: 2 }) {
        Text(this.memberName.length > 0 ? this.memberName : '未选择成员')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
        Text(this.memberId > 0 ? `成员 ID ${this.memberId}` : '请确认归属成员')
          .fontSize(12)
          .fontColor('#8E8E93')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.kindLabel.length > 0) {
        Text(this.kindLabel)
          .fontSize(12)
          .fontColor('#0A84FF')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('#E8F2FF')
          .borderRadius(10)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(14)
  }
}

/** 源文件附件条。 */
@Component
export struct MedicalDocumentResultAttachmentsSection {
  @Prop fileNames: string[] = [];

  build() {
    Column({ space: 8 }) {
      Text('源文件附件')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
        .width('100%')
      if (this.fileNames.length === 0) {
        Text('暂无源文件')
          .fontSize(13)
          .fontColor('#8E8E93')
          .width('100%')
      } else {
        ForEach(this.fileNames, (name: string, index: number) => {
          Text(`${index + 1}. ${name}`)
            .fontSize(13)
            .fontColor('#3C3C43')
            .width('100%')
        }, (name: string, index: number): string => `att-${index}-${name}`)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(14)
  }
}

/** 底部返回 / 保存操作。 */
@Component
export struct MedicalDocumentResultActionBar {
  @Prop canSave: boolean = false;
  @Prop isSaving: boolean = false;
  @Prop saveLabel: string = '确认保存';
  onReturnPicking: () => void = () => {};
  onSave: () => void = () => {};

  private effectiveLabel(): string {
    return this.isSaving ? '保存中…' : this.saveLabel;
  }

  build() {
    Row({ space: 12 }) {
      Button(MedicalUploadL10n.text('medical.upload.action.return_picking'))
        .layoutWeight(1)
        .height(44)
        .fontColor('#333333')
        .backgroundColor('#E9E9ED')
        .enabled(!this.isSaving)
        .onClick(() => this.onReturnPicking())
      Button(this.effectiveLabel())
        .layoutWeight(1)
        .height(44)
        .fontColor(Color.White)
        .backgroundColor(this.canSave && !this.isSaving ? '#0A84FF' : '#AEAEB2')
        .enabled(this.canSave && !this.isSaving)
        .onClick(() => this.onSave())
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}

export class MedicalDocumentResultChromeHelper {
  static fileNames(files: MedicalAttachmentInput[]): string[] {
    const names: string[] = [];
    for (let i = 0; i < files.length; i++) {
      const name = files[i].originalName.length > 0 ?
        files[i].originalName : files[i].previewId;
      names.push(name);
    }
    return names;
  }
}

/** 结果页共享路径与装配辅助。供测试与路由层复用。 */
export { MedicalValidationIssueInlineView } from './PreSubmitValidation/MedicalValidationIssueInlineView';

export class MedicalDocumentResultSupport {
  static readonly TYPED_SCAFFOLD_MODULE: string = 'MedicalDocumentTypedResultScaffoldView';
  static readonly ROUTER_VIEW_MODULE: string = 'MedicalDocumentResultRouterView';

  static fileNames(files: MedicalAttachmentInput[]): string[] {
    return MedicalDocumentResultChromeHelper.fileNames(files);
  }
}
