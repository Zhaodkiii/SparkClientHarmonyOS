import { Member } from '../../../../../Core/Domain/Entities/Member';
import { RemoteMedicineBox } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { MedicineBoxTypeCatalog } from './MedicineBoxTypeCatalog';
import { formatQuantity, nilIfBlank } from './MedicalFileUtils';

/** 对齐 iOS `medicineBoxStockText`：空值显示「未填写」，不将 undefined 误显示为 0。 */
export function medicineBoxStockText(box: RemoteMedicineBox): string {
  if (box.totalQuantity === undefined || box.totalQuantity === null) {
    return '未填写';
  }
  return formatQuantity(box.totalQuantity);
}

/** 对齐 iOS `medicineTypeText`：空类型不展示标签文案。 */
export function medicineTypeText(type: string | undefined): string {
  const stored = MedicineBoxTypeCatalog.storedValue(type);
  return stored;
}

/** 对齐 iOS `medicineStrengthDetailValue`：本期直接展示原始规格文本。 */
export function medicineStrengthDetailValue(strength: string): string {
  return nilIfBlank(strength) ?? '';
}

/** 归属成员展示文案。 */
export function medicineBoxOwnershipDisplay(
  box: RemoteMedicineBox,
  memberOptions: Member[]
): string {
  if (box.member === undefined || box.member === null) {
    return '家庭公共药品';
  }
  for (let i = 0; i < memberOptions.length; i++) {
    if (memberOptions[i].id === box.member) {
      return memberOptions[i].name;
    }
  }
  return '成员药品';
}

/** 详情行空值：可隐藏或显示空白，不强制「未填写」（除库存外）。 */
export function medicineBoxDetailValue(value: string | undefined, fallback: string = ''): string {
  return nilIfBlank(value) ?? fallback;
}
