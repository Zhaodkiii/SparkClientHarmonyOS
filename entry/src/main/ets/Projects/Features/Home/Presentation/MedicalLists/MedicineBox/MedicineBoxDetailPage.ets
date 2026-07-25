import { promptAction } from '@kit.ArkUI';
import { RemoteMedicineBox } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { SparkMedicalWorkflowAPI } from '../../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { FileTransferService } from '../../../../../../Core/FileStorage/FileTransferService';
import { MedicalAttachmentGridPreview } from '../Shared/MedicalAttachmentComponents';

/** 药品详情页，对齐 iOS `MedicineBoxDetailPage` 核心信息与操作 */
@Component
export struct MedicineBoxDetailPage {
  @Prop box: RemoteMedicineBox = new RemoteMedicineBox();
  workflow?: SparkMedicalWorkflowAPI;
  fileTransferService?: FileTransferService;
  onBack?: () => void;
  onEdit?: (box: RemoteMedicineBox) => void;
  onDelete?: (box: RemoteMedicineBox) => Promise<void>;
  onArchive?: (box: RemoteMedicineBox) => Promise<void>;

  private async confirmDelete(): Promise<void> {
    const result = await promptAction.showDialog({
      title: '删除药品',
      message: '删除后无法从当前药箱恢复，是否继续？',
      buttons: [{ text: '取消', color: '#0A84FF' }, { text: '删除', color: '#D93025' }]
    });
    if (result.index === 1) {
      await this.onDelete?.(this.box);
    }
  }

  private async confirmArchive(): Promise<void> {
    const action = this.box.isArchived ? '取消归档' : '归档';
    const result = await promptAction.showDialog({
      title: `${action}药品`,
      message: `确定${action}该药品吗？`,
      buttons: [{ text: '取消', color: '#0A84FF' }, { text: action, color: '#0A84FF' }]
    });
    if (result.index === 1) {
      await this.onArchive?.(this.box);
    }
  }

  @Builder
  row(title: string, value: string) {
    Row() {
      Text(title).fontSize(14).fontColor('#666666').layoutWeight(1)
      Text(value.length > 0 ? value : '未填写').fontSize(14).fontColor('#1C1C1E').maxLines(2)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).fontColor('#0A84FF').onClick(() => this.onBack?.())
        Blank()
        Text(this.box.medicineName.length > 0 ? this.box.medicineName : '药品详情')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('⋯')
          .fontSize(24)
          .fontColor('#0A84FF')
          .onClick(() => {
            promptAction.showActionMenu({
              title: '药品操作',
              buttons: [
                { text: '编辑', color: '#0A84FF' },
                { text: this.box.isArchived ? '取消归档' : '归档', color: '#0A84FF' },
                { text: '删除', color: '#FF3B30' }
              ]
            }).then((result) => {
              if (result.index === 0) {
                this.onEdit?.(this.box);
              }
              if (result.index === 1) {
                this.confirmArchive();
              }
              if (result.index === 2) {
                this.confirmDelete();
              }
            });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      Scroll() {
        Column({ space: 12 }) {
          Column() {
            Text('药品信息').fontSize(16).fontWeight(FontWeight.Medium).width('100%')
            this.row('药品名称', this.box.medicineName)
            this.row('药品类型', this.box.medicineType ?? '')
            this.row('品牌', this.box.brandName)
            this.row('剂型', this.box.dosageForm)
            this.row('规格', this.box.strength)
            this.row('剂量单位', this.box.doseUnit)
          }
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(14)

          Column() {
            Text('库存与有效期').fontSize(16).fontWeight(FontWeight.Medium).width('100%')
            this.row('总数量', this.box.totalQuantity === undefined ? '' : `${this.box.totalQuantity}`)
            this.row('有效期', this.box.expireDate ?? '')
          }
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(14)

          if (this.box.notes.length > 0) {
            Column() {
              Text('备注').fontSize(16).fontWeight(FontWeight.Medium).width('100%')
              Text(this.box.notes).fontSize(14).fontColor('#333333').width('100%').margin({ top: 10 })
            }
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(14)
          }

          Column() {
            Text(`附件（${this.box.attachments.length}）`).fontSize(16).fontWeight(FontWeight.Medium).width('100%')
            if (this.box.attachments.length === 0) {
              Text('暂无附件').fontSize(13).fontColor('#888888').margin({ top: 10 })
            } else {
              MedicalAttachmentGridPreview({
                attachments: this.box.attachments,
                fileTransferService: this.fileTransferService
              })
                .margin({ top: 10 })
            }
          }
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(14)
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
