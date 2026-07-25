import { RemoteMedicineBox } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { FileTransferService } from '../../../../../../Core/FileStorage/FileTransferService';
import { formatQuantity, isMedicationImageLike, nilIfBlank } from './MedicalFileUtils';
import {
  MedicineBoxBadgeKind,
  MedicineBoxBadgeResolved,
  MedicineBoxStatusBadge
} from './MedicineBoxStatusBadge';
import { MedicationImageGlyph } from './MedicationImageGlyph';

/** 对齐 iOS `MedicineBoxCardView`：双列网格药品卡片 */
@Component
export struct MedicineBoxCardView {
  @Prop box: RemoteMedicineBox = new RemoteMedicineBox();
  fileTransferService?: FileTransferService;
  onTap?: () => void;

  private imageAttachmentId(): number {
    const attachments = this.box.attachments;
    for (let i = 0; i < attachments.length; i++) {
      if (isMedicationImageLike(attachments[i])) {
        return attachments[i].id;
      }
    }
    return 0;
  }

  private imageAttachment() {
    const attachments = this.box.attachments;
    for (let i = 0; i < attachments.length; i++) {
      if (isMedicationImageLike(attachments[i])) {
        return attachments[i];
      }
    }
    return undefined;
  }

  private statusBadge(): MedicineBoxBadgeResolved | undefined {
    return MedicineBoxStatusBadge.resolve(this.box);
  }

  private specLine(): string {
    const strength = nilIfBlank(this.box.strength) ?? '';
    let qty = '';
    const quantityText = formatQuantity(this.box.totalQuantity);
    if (quantityText.length > 0) {
      qty = ` ×${quantityText}`;
    }
    return strength.length === 0 ? qty.trim() : `${strength}${qty}`;
  }

  private badgeBackground(badge: MedicineBoxBadgeResolved): string {
    if (badge.kind === MedicineBoxBadgeKind.EXPIRED) {
      return '#8E8E938C';
    }
    return badge.color;
  }

  build() {
    Column({ space: 10 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          MedicationImageGlyph({
            seed: this.box.id,
            attachmentId: this.imageAttachmentId(),
            attachment: this.imageAttachment(),
            fileTransferService: this.fileTransferService
          })
            .width(120)
            .height(120)
        }
        .width('100%')
        .height(120)
        .backgroundColor('#F2F2F7')
        .borderRadius(12)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        if (this.statusBadge()) {
          Text(this.statusBadge()?.text ?? '')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.badgeBackground(this.statusBadge() as MedicineBoxBadgeResolved))
            .borderRadius(20)
            .margin(8)
        }
      }

      Text(nilIfBlank(this.box.medicineName) ?? '未命名药品')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(this.specLine())
        .fontSize(12)
        .fontColor('#8E8E93')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row() {
        Blank()
        Text('查看更多')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#AF52DE')
        Text('›')
          .fontSize(12)
          .fontColor('#AF52DE')
          .margin({ left: 2 })
      }
      .width('100%')
    }
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .onClick(() => this.onTap?.())
  }
}
