import { HarmonyBuiltInOCREngine } from '../../../Core/OCR/HarmonyBuiltInOCREngine';
import { OCRRecognitionHints } from '../../../Core/OCR/OCRModels';
import { ChatAttachmentOCRAdapter } from './ChatAttachmentPreprocessor';

/**
 * 聊天附件图片 OCR：复用 Core 内置引擎（fd 读图 + 安全释放 + session）。
 * 修复原 createImageSource(uri) + 无保护 source.release() 真机崩点。
 */
export class HarmonyVisionOCRAdapter implements ChatAttachmentOCRAdapter {
  private readonly engine: HarmonyBuiltInOCREngine = new HarmonyBuiltInOCREngine();

  async recognizeImage(sourceUri: string): Promise<string> {
    const output = await this.engine.recognizeFromUri(sourceUri, new OCRRecognitionHints());
    return output.text.trim();
  }

  async recognizeDocument(sourceUri: string, mimeType: string): Promise<string> {
    if (mimeType.startsWith('image/')) {
      return this.recognizeImage(sourceUri);
    }
    return '';
  }
}
