import { RemoteMedicineBox } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { FileTransferService } from '../../../../../../Core/FileStorage/FileTransferService';
import { MedicineBoxCardView } from './MedicineBoxCardView';

/** 对齐 iOS `MedicineBoxGridView`：双列药品网格 */
@Component
export struct MedicineBoxGridView {
  @Prop boxes: RemoteMedicineBox[] = [];
  @Prop isLoading: boolean = false;
  fileTransferService?: FileTransferService;
  onSelect?: (box: RemoteMedicineBox) => void;

  build() {
    if (this.boxes.length === 0) {
      Text(this.isLoading ? '加载中…' : '暂无药品')
        .fontSize(14)
        .fontColor('#8E8E93')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 48, bottom: 48 })
    } else {
      Grid() {
        ForEach(this.boxes, (box: RemoteMedicineBox) => {
          GridItem() {
            MedicineBoxCardView({
              box: box,
              fileTransferService: this.fileTransferService,
              onTap: () => this.onSelect?.(box)
            })
          }
        }, (box: RemoteMedicineBox): string => `medicine-grid-${box.id}`)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(12)
      .rowsGap(12)
      .width('100%')
    }
  }
}
