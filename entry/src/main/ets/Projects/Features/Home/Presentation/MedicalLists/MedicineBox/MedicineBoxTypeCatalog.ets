import { RemoteMedicineBox } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { nilIfBlank } from './MedicalFileUtils';

/**
 * 对齐 iOS `MedicineBoxTypeCatalog`：预设分类 + 当前数据中的自定义类型。
 * 展示值与存储值本期统一用中文文案（与现有后端返回一致）。
 */
export class MedicineBoxTypeCatalog {
  static readonly defaults: string[] = [
    '抗菌消炎',
    '感冒发烧',
    '慢病用药',
    '口腔用药',
    '胃肠消化',
    '咳嗽咽痛',
    '皮肤骨痛',
    '儿童用药'
  ];

  static storedValue(fromAny: string | undefined | null): string {
    const text = nilIfBlank(fromAny) ?? '';
    return text;
  }

  static options(inBoxes: RemoteMedicineBox[]): string[] {
    const values: string[] = [];
    for (let i = 0; i < MedicineBoxTypeCatalog.defaults.length; i++) {
      values.push(MedicineBoxTypeCatalog.defaults[i]);
    }
    for (let i = 0; i < inBoxes.length; i++) {
      const type = MedicineBoxTypeCatalog.storedValue(inBoxes[i].medicineType);
      if (type.length > 0 && values.indexOf(type) < 0) {
        values.push(type);
      }
    }
    return values;
  }
}
