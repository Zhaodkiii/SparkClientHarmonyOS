import { FilePreviewInput } from '../../../../Core/UI/FilePreview/FilePreviewInput';
import { UnifiedFilePreview } from '../../../../Core/UI/FilePreview/UnifiedFilePreview';
import {
  MedicalDocumentFilePreviewSquareCard
} from '../../../Home/Presentation/MedicalLists/MedicineBox/MedicalDocumentFilePreviewSquareCard';
import { MedicalDocumentLocalAttachmentItem } from './MedicalDocumentLocalAttachmentItem';

/**
 * 结果页匹配附件网格。对齐 iOS `CaseMatchedAttachmentsGridView`：
 * 三列缩略图 + 统一预览 + 可选「管理」入口。
 */
@Component
export struct CaseMatchedAttachmentsGridView {
  @Prop title: string = '';
  @Prop attachments: MedicalDocumentLocalAttachmentItem[] = [];
  onManage?: () => void;

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

  private attachmentIndex(item: MedicalDocumentLocalAttachmentItem): number {
    for (let i = 0; i < this.attachments.length; i++) {
      if (this.attachments[i].id === item.id) {
        return i;
      }
    }
    return 0;
  }

  @Builder
  private gridCard(item: MedicalDocumentLocalAttachmentItem) {
    Stack({ alignContent: Alignment.BottomStart }) {
      MedicalDocumentFilePreviewSquareCard({
        item: item.previewInput(),
        showDelete: false,
        onPreview: () => {
          this.openPreview(this.attachmentIndex(item));
        }
      })
      Text(item.displayName)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 6, right: 6, top: 4, bottom: 4 })
        .backgroundColor('#0000006B')
    }
    .aspectRatio(1)
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        if (this.title.length > 0) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.paperclip'))
              .fontSize(12)
              .fontColor(['#8E8E93'])
            Text(this.title)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#8E8E93')
          }
        }
        Blank().layoutWeight(1)
        if (this.onManage) {
          Text('管理')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0A84FF')
            .onClick(() => this.onManage?.())
        }
      }
      .width('100%')

      if (this.attachments.length > 0) {
        Grid() {
          ForEach(this.attachments, (item: MedicalDocumentLocalAttachmentItem) => {
            GridItem() {
              this.gridCard(item)
            }
          }, (item: MedicalDocumentLocalAttachmentItem): string => `matched-att-${item.id}`)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(10)
        .rowsGap(10)
        .width('100%')
      }
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
