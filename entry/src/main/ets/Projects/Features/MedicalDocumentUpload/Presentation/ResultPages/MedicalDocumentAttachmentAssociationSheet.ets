import { MedicalDocumentLocalAttachmentItem } from './MedicalDocumentLocalAttachmentItem';

/**
 * 附件关联管理 Sheet。对齐 iOS `MedicalDocumentAttachmentAssociationSheet`：
 * 从全部源文件中勾选当前报告应关联的附件。
 */
@Component
export struct MedicalDocumentAttachmentAssociationSheet {
  @Prop title: string = '管理附件';
  @Prop localAttachments: MedicalDocumentLocalAttachmentItem[] = [];
  @Prop selectedIDs: string[] = [];
  onSubmit?: (ids: string[]) => void;
  onCancel?: () => void;

  @State private workingIDs: string[] = [];

  aboutToAppear(): void {
    this.workingIDs = this.selectedIDs.slice();
  }

  private isSelected(id: string): boolean {
    return this.workingIDs.indexOf(id) >= 0;
  }

  private toggle(id: string): void {
    const index = this.workingIDs.indexOf(id);
    if (index >= 0) {
      this.workingIDs.splice(index, 1);
    } else {
      this.workingIDs.push(id);
    }
    this.workingIDs = this.workingIDs.slice();
  }

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      if (this.localAttachments.length === 0) {
        Text('暂无可关联的源文件')
          .fontSize(14)
          .fontColor('#8E8E93')
          .width('100%')
      } else {
        Column({ space: 8 }) {
          ForEach(this.localAttachments, (item: MedicalDocumentLocalAttachmentItem) => {
            Row({ space: 10 }) {
              Text(this.isSelected(item.id) ? '☑' : '☐')
                .fontSize(18)
                .fontColor(this.isSelected(item.id) ? '#0A84FF' : '#C7C7CC')
              Column({ space: 2 }) {
                Text(item.displayName)
                  .fontSize(14)
                  .fontColor('#1C1C1E')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if ((item.mimeType ?? '').length > 0) {
                  Text(item.mimeType ?? '')
                    .fontSize(12)
                    .fontColor('#8E8E93')
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#F8F8FA')
            .borderRadius(10)
            .onClick(() => {
              this.toggle(item.id);
            })
          }, (item: MedicalDocumentLocalAttachmentItem): string => `assoc-${item.id}`)
        }
        .width('100%')
      }

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor('#F2F2F7')
          .fontColor('#1C1C1E')
          .onClick(() => {
            if (this.onCancel) {
              this.onCancel();
            }
          })
        Button('完成')
          .layoutWeight(1)
          .backgroundColor('#0A84FF')
          .fontColor(Color.White)
          .onClick(() => {
            if (this.onSubmit) {
              this.onSubmit(this.workingIDs.slice());
            }
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
  }
}
