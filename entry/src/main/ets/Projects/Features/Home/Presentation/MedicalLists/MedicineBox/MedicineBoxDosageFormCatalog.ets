import { nilIfBlank } from './MedicalFileUtils';

/** 对齐 iOS `MedicineBoxDosageFormCatalog`。 */
export class MedicineBoxDosageFormCatalog {
  static readonly commonForms: string[] = ['胶囊', '药片', '液体', '外用'];
  static readonly moreForms: string[] = [
    '乳液', '乳霜', '凝胶', '吸入剂', '喷剂', '栓剂', '泡沫', '注射', '滴剂', '粉末', '设备', '贴剂', '软膏'
  ];

  static allForms(): string[] {
    return MedicineBoxDosageFormCatalog.commonForms.concat(MedicineBoxDosageFormCatalog.moreForms);
  }

  static displayString(stored: string): string {
    const trimmed = stored.trim();
    if (trimmed.length === 0) {
      return '';
    }
    const all = MedicineBoxDosageFormCatalog.allForms();
    for (let i = 0; i < all.length; i++) {
      if (all[i] === trimmed) {
        return all[i];
      }
    }
    return trimmed;
  }

  static storedValue(fromAny: string | undefined | null): string {
    const trimmed = nilIfBlank(fromAny) ?? '';
    if (trimmed.length === 0) {
      return '';
    }
    const all = MedicineBoxDosageFormCatalog.allForms();
    for (let i = 0; i < all.length; i++) {
      if (all[i] === trimmed) {
        return all[i];
      }
    }
    return trimmed;
  }
}
