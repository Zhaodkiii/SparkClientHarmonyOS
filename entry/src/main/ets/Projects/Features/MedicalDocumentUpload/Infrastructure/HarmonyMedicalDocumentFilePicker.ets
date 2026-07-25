import { common } from '@kit.AbilityKit';
import { MedicalDocumentFilePicker } from '../../Home/Presentation/MedicalLists/MedicalDocumentFilePicker';
import { MedicalUploadLocalFile } from '../Domain/MedicalDocumentUploadModels';

/**
 * HarmonyOS 文件选择适配器（工单 T5 / 4.2）。
 * UI 只消费 MedicalUploadLocalFile；不直接依赖 Photo/Document picker 细节。
 */
export class HarmonyMedicalDocumentFilePicker {
  static readonly DEFAULT_MAX_SELECTION_COUNT: number = 9;

  static async pickImages(
    context: common.UIAbilityContext,
    maxSelectionCount: number = HarmonyMedicalDocumentFilePicker.DEFAULT_MAX_SELECTION_COUNT
  ): Promise<MedicalUploadLocalFile[]> {
    const files = await MedicalDocumentFilePicker.pickImages(context, maxSelectionCount);
    return files.map(MedicalUploadLocalFile.fromAttachment);
  }

  static async pickImagesAndPDFs(
    context: common.UIAbilityContext,
    maxSelectionCount: number = HarmonyMedicalDocumentFilePicker.DEFAULT_MAX_SELECTION_COUNT
  ): Promise<MedicalUploadLocalFile[]> {
    const files = await MedicalDocumentFilePicker.pickImagesAndPDFs(context, maxSelectionCount);
    return files.map(MedicalUploadLocalFile.fromAttachment);
  }

  static async pickPDFs(
    context: common.UIAbilityContext,
    maxSelectionCount: number = HarmonyMedicalDocumentFilePicker.DEFAULT_MAX_SELECTION_COUNT
  ): Promise<MedicalUploadLocalFile[]> {
    const files = await MedicalDocumentFilePicker.pickPDFs(context, maxSelectionCount);
    return files.map(MedicalUploadLocalFile.fromAttachment);
  }
}
