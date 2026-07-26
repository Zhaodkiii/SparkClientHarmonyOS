import { describe, it, expect } from '@ohos/hypium';
import { MedicationExecutionDateStripScrollMath } from '../../../main/ets/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionDateStripScrollMath';

export default function MedicationExecutionDateStripScrollMathTest(): void {
  describe('MedicationExecutionDateStripScrollMath', () => {
    const itemWidth = 48;
    const itemSpacing = 8;
    const pitch = MedicationExecutionDateStripScrollMath.itemPitch(itemWidth, itemSpacing);

    it('center_inset_matches_ios_formula', 0, () => {
      expect(MedicationExecutionDateStripScrollMath.centerInset(390, itemWidth)).assertEqual(171);
    });

    it('offset_and_index_are_inverse_with_row_padding_model', 0, () => {
      const index = 45;
      const offset = MedicationExecutionDateStripScrollMath.centeredOffsetFor(index, pitch);
      const resolved = MedicationExecutionDateStripScrollMath.centeredIndexForOffset(offset, pitch, 91);
      expect(resolved).assertEqual(index);
    });

    it('index_zero_has_zero_offset', 0, () => {
      expect(MedicationExecutionDateStripScrollMath.centeredOffsetFor(0, pitch)).assertEqual(0);
      expect(MedicationExecutionDateStripScrollMath.centeredIndexForOffset(0, pitch, 91)).assertEqual(0);
    });
  });
}
