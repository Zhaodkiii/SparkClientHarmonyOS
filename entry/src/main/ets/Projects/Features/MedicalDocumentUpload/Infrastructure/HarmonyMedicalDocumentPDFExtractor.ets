import { fileIo as fs } from '@kit.CoreFileKit';
import { pdfService } from '@kit.PDFKit';
import { util } from '@kit.ArkTS';
import { OCRConfiguration } from '../../../Core/OCR/OCRModels';

/**
 * PDF 文本层专用提取器（Feature 侧薄封装）。
 * 核心逻辑在 Core/OCR/OCRDocumentExtractor；此处供 UseCase / 测试直接探测文本层。
 */
export class HarmonyMedicalDocumentPDFExtractor {
  private readonly config: OCRConfiguration;

  constructor(config: OCRConfiguration = new OCRConfiguration()) {
    this.config = config;
  }

  async extractTextLayer(pathOrUri: string): Promise<string> {
    const sandboxPath = await this.copyToSandboxIfNeeded(pathOrUri);
    const document = new pdfService.PdfDocument();
    const loadResult = await document.loadDocument(sandboxPath);
    if (loadResult !== pdfService.ParseResult.PARSE_SUCCESS) {
      return '';
    }
    try {
      const pageCount = document.getPageCount();
      const pages: string[] = [];
      for (let i = 0; i < pageCount; i++) {
        try {
          const page = document.getPage(i);
          let text = '';
          try {
            // 必须调用 getTextContent()；禁止把函数引用字符串化。
            const raw = page.getTextContent();
            text = typeof raw === 'string' ? raw : '';
          } catch (_e) {
            text = '';
          }
          if (text.trim().length > 0) {
            pages.push(text);
          }
        } catch (_e) {
          // continue
        }
      }
      return pages.join('\n');
    } finally {
      try {
        document.releaseDocument();
      } catch (_e) {
        // ignore
      }
    }
  }

  private async copyToSandboxIfNeeded(pathOrUri: string): Promise<string> {
    if (pathOrUri.indexOf('/') === 0 && pathOrUri.indexOf('://') < 0) {
      return pathOrUri;
    }
    const cacheRoot = this.config.cacheDir.length > 0 ?
      `${this.config.cacheDir}/medical_ocr_pdf` : '';
    if (cacheRoot.length === 0) {
      return pathOrUri;
    }
    try {
      fs.mkdirSync(cacheRoot, true);
    } catch (_e) {
      // exists
    }
    const dest = `${cacheRoot}/probe_${Date.now()}.pdf`;
    let src: fs.File | undefined = undefined;
    let dst: fs.File | undefined = undefined;
    try {
      src = fs.openSync(pathOrUri, fs.OpenMode.READ_ONLY);
      dst = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const buffer = new ArrayBuffer(256 * 1024);
      let read = 0;
      do {
        read = fs.readSync(src.fd, buffer);
        if (read > 0) {
          fs.writeSync(dst.fd, buffer, { length: read });
        }
      } while (read > 0);
      return dest;
    } finally {
      if (src !== undefined) {
        fs.closeSync(src);
      }
      if (dst !== undefined) {
        fs.closeSync(dst);
      }
    }
  }

  /** 测试辅助：UTF-8 文本探测。 */
  static decodeUtf8(buffer: ArrayBuffer): string {
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    return decoder.decodeWithStream(new Uint8Array(buffer), { stream: false });
  }
}
