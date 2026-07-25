export class PrescriptionRecognitionResultPreviewFixtures {
  static readonly PRESCRIPTION_DRAFTS_JSON: string = `[
    {
      "institutionName": "苏州大学附属第四医院",
      "prescribedAt": "2026-04-20",
      "diagnosis": "结膜炎",
      "medicationPlans": [
        {
          "medicineName": "普拉洛芬滴眼液",
          "brandName": "普南扑灵",
          "dosageForm": "滴眼液",
          "strength": "5ml:5mg",
          "doseValue": "1",
          "frequencyType": "daily",
          "frequencyText": "每日四次"
        }
      ]
    }
  ]`;

  static readonly FAMILY_MEDICINE_BOXES_JSON: string = `[
    {
      "id": 172,
      "medicine_name": "普拉洛芬滴眼液",
      "brand_name": "普南扑灵",
      "dosage_form": "滴眼液",
      "strength": "5ml:5mg"
    }
  ]`;
}
