import { FilePreviewInput } from '../../../../../Core/UI/FilePreview/FilePreviewInput';
import { UnifiedFilePreview } from '../../../../../Core/UI/FilePreview/UnifiedFilePreview';
import { MedicalDocumentResultSectionCard } from '../MedicalDocumentResultSupport';
import { MedicalDocumentLocalAttachmentItem } from '../MedicalDocumentLocalAttachmentItem';

/**
 * 未关联到具体报告卡片的源文件附件。对齐 iOS `MedicalDocumentUnlinkedAttachmentsSectionView`。
 */
@Component
export struct MedicalDocumentUnlinkedAttachmentsSectionView {
  @Prop attachments: MedicalDocumentLocalAttachmentItem[] = [];

  @State private showPreviewSheet: boolean = false;
  @State private previewInputs: FilePreviewInput[] = [];
  @State private previewStartIndex: number = 0;

  private openPreview(index: number): void {
    const inputs: FilePreviewInput[] = [];
    for (let i = 0; i < this.attachments.length; i++) {
      inputs.push(this.attachments[i].previewInput());
    }
    this.previewInputs = inputs;
    this.previewStartIndex = index;
    this.showPreviewSheet = true;
  }

  private attachmentIndex(item: MedicalDocumentLocalAttachmentItem): number {
    for (let i = 0; i < this.attachments.length; i++) {
      if (this.attachments[i].id === item.id) {
        return i;
      }
    }
    return 0;
  }

  @Builder
  private previewSheet() {
    UnifiedFilePreview({
      inputs: this.previewInputs,
      startIndex: this.previewStartIndex,
      onClose: () => {
        this.showPreviewSheet = false;
      }
    })
  }

  @Builder
  private Content() {
    Column({ space: 8 }) {
      ForEach(this.attachments, (item: MedicalDocumentLocalAttachmentItem) => {
        Row({ space: 12 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.doc_text'))
              .fontSize(18)
              .fontColor([item.tintColor()])
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#F2F2F7')
          .borderRadius(10)

          Column({ space: 4 }) {
            Text(item.displayName)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1C1C1E')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if ((item.mimeType ?? '').length > 0) {
              Text(item.mimeType ?? '')
                .fontSize(12)
                .fontColor('#8E8E93')
                .maxLines(1)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text('›')
            .fontSize(18)
            .fontColor('#C7C7CC')
        }
        .width('100%')
        .padding(10)
        .backgroundColor('#F8F8FA')
        .borderRadius(10)
        .onClick(() => {
          this.openPreview(this.attachmentIndex(item));
        })
      }, (item: MedicalDocumentLocalAttachmentItem): string => `unlinked-att-${item.id}`)
    }
    .width('100%')
  }

  build() {
    if (this.attachments.length === 0) {
      Column() {}
    } else {
      Column() {
        MedicalDocumentResultSectionCard({
          title: '未关联附件',
          subtitle: '以下源文件尚未关联到具体报告',
          badgeText: `${this.attachments.length}`,
          content: () => {
            this.Content()
          }
        })
      }
      .width('100%')
      .bindSheet(this.showPreviewSheet, this.previewSheet, {
        height: SheetSize.LARGE,
        dragBar: true,
        showClose: true,
        onDisappear: () => {
          this.showPreviewSheet = false;
        }
      })
    }
  }
}
