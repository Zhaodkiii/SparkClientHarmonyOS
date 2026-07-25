import { RemoteMedicineBox } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';

export enum MedicineBoxBadgeKind {
  EXPIRED = 'expired',
  EXPIRING_SOON = 'expiring_soon',
  LOW_STOCK = 'low_stock'
}

export class MedicineBoxBadgeResolved {
  kind: MedicineBoxBadgeKind = MedicineBoxBadgeKind.EXPIRED;
  text: string = '';
  color: string = '#8E8E93';
}

/** 对齐 iOS `MedicineBoxStatusBadge`：过期 / 临期 / 库存不足 */
export class MedicineBoxStatusBadge {
  static resolve(box: RemoteMedicineBox): MedicineBoxBadgeResolved | undefined {
    if (box.expireDate && box.expireDate.length >= 10) {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const expireDay = new Date(box.expireDate.substring(0, 10));
      expireDay.setHours(0, 0, 0, 0);
      if (expireDay.getTime() < today.getTime()) {
        const expired = new MedicineBoxBadgeResolved();
        expired.kind = MedicineBoxBadgeKind.EXPIRED;
        expired.text = '已过期';
        expired.color = '#8E8E93';
        return expired;
      }
      const soon = new Date(today);
      soon.setDate(soon.getDate() + 30);
      if (expireDay.getTime() <= soon.getTime()) {
        const expiring = new MedicineBoxBadgeResolved();
        expiring.kind = MedicineBoxBadgeKind.EXPIRING_SOON;
        expiring.text = '即将过期';
        expiring.color = '#FF9500';
        return expiring;
      }
    }
    if (box.totalQuantity !== undefined && box.totalQuantity !== null && box.totalQuantity <= 0) {
      const low = new MedicineBoxBadgeResolved();
      low.kind = MedicineBoxBadgeKind.LOW_STOCK;
      low.text = '库存不足';
      low.color = '#FF9500';
      return low;
    }
    return undefined;
  }
}
