import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { OCRDiagnostics } from '../../../Core/OCR/OCRDiagnostics';
import { OCRError, OCRRequestOptions } from '../../../Core/OCR/OCRModels';
import { MedicalTermsCorrector } from '../../../Core/OCR/MedicalTermsCorrector';
import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import {
  MedicalDocumentOCRRequest
} from '../Domain/MedicalDocumentOCRModels';
import {
  MedicalDocumentOCRResult,
  MedicalFileOCRResult
} from '../Domain/MedicalDocumentOCRResult';
import { HarmonyMedicalDocumentOCRAdapter } from '../Infrastructure/HarmonyMedicalDocumentOCRAdapter';
import { MedicalDocumentOCRTextMerger } from '../Infrastructure/MedicalDocumentOCRTextMerger';

/**
 * 医疗文档 OCR 用例：逐文件识别 → 合并 → 术语纠错。
 * 对齐 iOS mergeOCRText / recognizeOCRFiles 边界。
 */
export class MedicalDocumentOCRUseCase {
  private readonly adapter: HarmonyMedicalDocumentOCRAdapter;

  constructor(adapter: HarmonyMedicalDocumentOCRAdapter) {
    this.adapter = adapter;
  }

  async execute(
    request: MedicalDocumentOCRRequest,
    options: OCRRequestOptions = OCRRequestOptions.medicalDefault(),
    onFileProgress?: (done: number, total: number) => void
  ): Promise<MedicalDocumentOCRResult> {
    if (request.files.length === 0) {
      throw new Error('请先上传报告文件');
    }

    const fileResults: MedicalFileOCRResult[] = [];
    let recognized = 0;
    let skipped = 0;
    const total = request.files.length;

    for (let i = 0; i < request.files.length; i++) {
      const file = request.files[i];
      const existing = (file.ocrText ?? '').trim();
      if (!request.reRecognizeAll && existing.length > 0) {
        const skippedResult = new MedicalFileOCRResult();
        skippedResult.localId = file.previewId;
        skippedResult.displayName = file.originalName.length > 0 ? file.originalName : `file_${i + 1}`;
        skippedResult.engine = 'cached';
        skippedResult.text = existing;
        skippedResult.rawText = existing;
        skippedResult.confidence = 1.0;
        fileResults.push(skippedResult);
        skipped += 1;
        onFileProgress?.(i + 1, total);
        continue;
      }

      this.log('medical.upload.ocr.file_start',
        `index=${i + 1}/${total};name=${file.originalName};mime=${file.mimeType}`);
      try {
        const recognition = await this.adapter.recognizeFile(file, options);
        const item = new MedicalFileOCRResult();
        item.localId = file.previewId;
        item.displayName = file.originalName.length > 0 ? file.originalName : `file_${i + 1}`;
        item.engine = recognition.selectedEngine;
        item.rawText = recognition.text;
        item.text = recognition.text;
        item.confidence = recognition.outputs.length > 0 ? recognition.outputs[0].confidence : undefined;
        fileResults.push(item);
        recognized += 1;
        this.log('medical.upload.ocr.file_done',
          `index=${i + 1}/${total};engine=${item.engine};textLen=${item.text.length}`);
      } catch (error) {
        const phase = error instanceof OCRError && error.phase.length > 0 ? error.phase : 'unknown';
        const code = error instanceof OCRError ? error.code : 'unknown';
        this.logWarn('medical.upload.ocr.file_failed',
          `index=${i + 1}/${total};name=${file.originalName};phase=${phase};code=${code};` +
            `error=${OCRDiagnostics.errorMessage(error)}`);
        // arkts-limited-throw：catch 值不能直接 throw，统一包装为 Error。
        if (error instanceof OCRError) {
          throw new OCRError(error.code, error.detail, error.phase);
        }
        if (error instanceof Error) {
          throw new Error(error.message);
        }
        throw new OCRError('response', OCRDiagnostics.errorMessage(error), 'ocr_use_case');
      }
      onFileProgress?.(i + 1, total);
    }

    const rawMerged = MedicalDocumentOCRTextMerger.merge(fileResults);
    const correctedMerged = options.correctMedicalTerms ?
      MedicalTermsCorrector.shared().correct(rawMerged) : rawMerged;

    // 纠错后回写单文件文本（合并头保留），便于下游预览。
    for (let i = 0; i < fileResults.length; i++) {
      if (options.correctMedicalTerms) {
        fileResults[i].text = MedicalTermsCorrector.shared().correct(fileResults[i].rawText);
      }
    }

    const result = new MedicalDocumentOCRResult();
    result.fileResults = fileResults;
    result.rawMergedOCRText = rawMerged;
    result.mergedOCRText = correctedMerged;
    result.correctedText = correctedMerged;
    result.selectedEngine = fileResults.length > 0 ?
      fileResults[fileResults.length - 1].engine : 'none';

    this.log('medical.upload.ocr.complete',
      `total=${fileResults.length};recognized=${recognized};skipped=${skipped};` +
        `mergedLen=${result.mergedOCRText.length};engine=${result.selectedEngine}`);
    return result;
  }

  /** 回填附件 ocrText，供断点与重试跳过。 */
  static applyOCRTextToFiles(
    files: MedicalAttachmentInput[],
    result: MedicalDocumentOCRResult
  ): MedicalAttachmentInput[] {
    const byId = new Map<string, string>();
    for (let i = 0; i < result.fileResults.length; i++) {
      byId.set(result.fileResults[i].localId, result.fileResults[i].text);
    }
    const out: MedicalAttachmentInput[] = [];
    for (let i = 0; i < files.length; i++) {
      const text = byId.get(files[i].previewId);
      if (text !== undefined && text.length > 0) {
        out.push(files[i].withOCRText(text));
      } else {
        out.push(files[i]);
      }
    }
    return out;
  }

  private log(event: string, detail: string): void {
    const fields = new LogFields();
    fields.operation = 'medical_document_ocr';
    fields.detail = detail;
    Logger.info(event, LogModule.HOME, fields);
  }

  private logWarn(event: string, detail: string): void {
    const fields = new LogFields();
    fields.operation = 'medical_document_ocr';
    fields.detail = detail;
    Logger.warn(event, LogModule.HOME, fields);
  }
}
