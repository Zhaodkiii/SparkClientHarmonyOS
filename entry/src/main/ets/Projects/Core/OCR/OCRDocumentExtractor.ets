import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { pdfService } from '@kit.PDFKit';
import { util } from '@kit.ArkTS';
import { Logger } from '../../../Foundation/Logging/Logger';
import { LogFields } from '../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../Foundation/Logging/LogModule';
import { MedicalTermsCorrector } from './MedicalTermsCorrector';
import { SafeOCRResourceRelease } from './OCRImageSourceAdapter';
import {
  OCRConfiguration,
  OCRError,
  OCRImageRecognizing,
  OCRRecognition,
  OCRRequestOptions,
  OCRTextOutput
} from './OCRModels';

/**
 * 文档提取：PDF 文本层优先，空文本再逐页渲染 OCR；txt 直接读；图片走编排器。
 * 对齐 iOS OCRDocumentExtractor。
 */
export class OCRDocumentExtractor {
  private readonly config: OCRConfiguration;

  constructor(config: OCRConfiguration) {
    this.config = config;
  }

  async extractText(
    pathOrUri: string,
    recognizer: OCRImageRecognizing,
    options: OCRRequestOptions,
    mimeType: string = ''
  ): Promise<OCRRecognition> {
    if (pathOrUri.length === 0) {
      throw new OCRError('invalidDocumentURL', 'empty_path');
    }

    const lowerPath = pathOrUri.toLowerCase();
    const lowerMime = mimeType.toLowerCase();
    const isPdf = lowerMime.indexOf('pdf') >= 0 || lowerPath.endsWith('.pdf');
    const isTxt = lowerMime.indexOf('text/plain') >= 0 || lowerPath.endsWith('.txt');
    const isImage = lowerMime.indexOf('image/') === 0 ||
      lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg') ||
      lowerPath.endsWith('.png') || lowerPath.endsWith('.webp') ||
      lowerPath.endsWith('.heic') || lowerPath.endsWith('.bmp');

    if (isPdf) {
      return await this.extractPdf(pathOrUri, recognizer, options);
    }
    if (isTxt) {
      return this.extractPlainText(pathOrUri, options);
    }
    if (isImage) {
      return await recognizer.recognizeFromUri(pathOrUri, options);
    }
    // 未知文档 / 空 MIME：先缩略图（对齐 iOS QuickLook），再尝试 URI OCR。
    return await this.recognizeUnknownWithThumbnail(pathOrUri, recognizer, options);
  }

  private extractPlainText(pathOrUri: string, options: OCRRequestOptions): OCRRecognition {
    let text = '';
    try {
      const file = fs.openSync(pathOrUri, fs.OpenMode.READ_ONLY);
      try {
        const stat = fs.statSync(pathOrUri);
        const size = Number(stat.size);
        const buffer = new ArrayBuffer(Math.max(1, size));
        fs.readSync(file.fd, buffer);
        const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
        text = decoder.decodeWithStream(new Uint8Array(buffer), { stream: false });
      } finally {
        fs.closeSync(file);
      }
    } catch (error) {
      const detail = error instanceof Error ? error.message : `${error}`;
      throw new OCRError('invalidDocumentURL', detail);
    }

    const corrected = options.correctMedicalTerms ?
      MedicalTermsCorrector.shared().correct(text) : text;
    const output = new OCRTextOutput();
    output.engine = 'plain_text';
    output.text = corrected;
    output.confidence = 1.0;
    const recognition = new OCRRecognition();
    recognition.text = corrected;
    recognition.selectedEngine = 'plain_text';
    recognition.outputs = [output];
    return recognition;
  }

  private async extractPdf(
    pathOrUri: string,
    recognizer: OCRImageRecognizing,
    options: OCRRequestOptions
  ): Promise<OCRRecognition> {
    const sandboxPath = await this.ensureSandboxPdfPath(pathOrUri);
    const document = new pdfService.PdfDocument();
    let loadResult: pdfService.ParseResult;
    try {
      loadResult = await document.loadDocument(sandboxPath);
    } catch (error) {
      const detail = error instanceof Error ? error.message : `${error}`;
      throw new OCRError('invalidDocumentURL', `pdf_load_failed:${detail}`);
    }
    if (loadResult !== pdfService.ParseResult.PARSE_SUCCESS) {
      throw new OCRError('invalidDocumentURL', `pdf_parse_${loadResult}`);
    }

    try {
      const textLayer = this.extractPdfTextLayer(document);
      if (textLayer !== undefined && textLayer.trim().length > 0) {
        const corrected = options.correctMedicalTerms ?
          MedicalTermsCorrector.shared().correct(textLayer) : textLayer;
        const output = new OCRTextOutput();
        output.engine = 'pdf_text_layer';
        output.text = corrected;
        output.confidence = 1.0;
        const recognition = new OCRRecognition();
        recognition.text = corrected;
        recognition.selectedEngine = 'pdf_text_layer';
        recognition.outputs = [output];
        this.logPdf('text_layer', corrected.length);
        return recognition;
      }
      return await this.ocrScannedPdf(document, recognizer, options);
    } finally {
      try {
        document.releaseDocument();
      } catch (_e) {
        // ignore
      }
    }
  }

  /**
   * 提取 PDF 文本层。必须调用 `getTextContent()`；
   * 禁止 `${page.getTextContent}`，否则会把函数引用字符串化成非空“伪文本”。
   */
  private extractPdfTextLayer(document: pdfService.PdfDocument): string | undefined {
    const pageCount = document.getPageCount();
    if (pageCount <= 0) {
      return undefined;
    }
    const pages: string[] = [];
    for (let i = 0; i < pageCount; i++) {
      try {
        const page = document.getPage(i);
        let text = '';
        try {
          // API 23+：扫描件返回空串；文本型 PDF 返回含转义符的原始文本。
          const raw = page.getTextContent();
          text = typeof raw === 'string' ? raw : '';
        } catch (_e) {
          text = '';
        }
        if (text.trim().length > 0) {
          pages.push(text);
        }
      } catch (_e) {
        // 单页失败继续。
      }
    }
    return pages.length > 0 ? pages.join('\n') : undefined;
  }

  private async ocrScannedPdf(
    document: pdfService.PdfDocument,
    recognizer: OCRImageRecognizing,
    options: OCRRequestOptions
  ): Promise<OCRRecognition> {
    const pageCount = document.getPageCount();
    const pageRecognitions: OCRRecognition[] = [];
    const scale = this.config.pdfRenderScale > 0 ? this.config.pdfRenderScale : 2.0;
    for (let i = 0; i < pageCount; i++) {
      let pixelMap: image.PixelMap | undefined = undefined;
      try {
        const page = document.getPage(i);
        pixelMap = this.renderPdfPage(page, scale);
        if (pixelMap === undefined) {
          continue;
        }
        const recognition = await recognizer.recognizePixelMap(pixelMap, options);
        pageRecognitions.push(recognition);
      } catch (error) {
        const fields = new LogFields();
        fields.operation = 'ocr_document_extractor';
        fields.detail = `page=${i};error=${error instanceof Error ? error.message : `${error}`}`;
        Logger.warn('ocr.pdf.page_failed', LogModule.OCR, fields);
      } finally {
        SafeOCRResourceRelease.pixelMap(pixelMap, 'pdf_page_pixel_map');
      }
    }

    if (pageRecognitions.length === 0) {
      throw new OCRError('response', 'scanned_pdf_no_page_output');
    }

    const texts: string[] = [];
    const outputs: OCRTextOutput[] = [];
    for (let i = 0; i < pageRecognitions.length; i++) {
      texts.push(pageRecognitions[i].text);
      for (let j = 0; j < pageRecognitions[i].outputs.length; j++) {
        outputs.push(pageRecognitions[i].outputs[j]);
      }
    }
    const recognition = new OCRRecognition();
    recognition.text = texts.join('\n');
    recognition.selectedEngine =
      pageRecognitions[pageRecognitions.length - 1].selectedEngine;
    recognition.outputs = outputs;
    this.logPdf('scanned_ocr', recognition.text.length);
    return recognition;
  }

  /**
   * 按 pdfRenderScale 渲染扫描页；失败回退 getPagePixelMap。
   */
  private renderPdfPage(page: pdfService.PdfPage, scale: number): image.PixelMap | undefined {
    try {
      const width = Math.ceil(page.getWidth() * scale);
      const height = Math.ceil(page.getHeight() * scale);
      if (width > 0 && height > 0) {
        const matrix = new pdfService.PdfMatrix();
        matrix.width = width;
        matrix.height = height;
        matrix.rotate = 0;
        const scaled = page.getCustomPagePixelMap(matrix, false, true);
        if (scaled !== undefined) {
          return scaled;
        }
      }
    } catch (_e) {
      // 回退默认渲染。
    }
    try {
      return page.getPagePixelMap();
    } catch (_e) {
      return undefined;
    }
  }

  /**
   * 未知格式：先解码为缩略图再 OCR（对齐 iOS QuickLook thumbnailMaxSide），
   * 失败再尝试 URI 直识，仍失败则抛 unsupported_document_or_thumbnail_failed。
   */
  private async recognizeUnknownWithThumbnail(
    pathOrUri: string,
    recognizer: OCRImageRecognizing,
    options: OCRRequestOptions
  ): Promise<OCRRecognition> {
    const maxSide = this.config.thumbnailMaxSide > 0 ? this.config.thumbnailMaxSide : 1600;
    let pixelMap: image.PixelMap | undefined = undefined;
    let source: image.ImageSource | undefined = undefined;
    try {
      source = image.createImageSource(pathOrUri);
      if (source === undefined) {
        throw new OCRError('invalidImage', 'image_source_undefined', 'unknown_thumbnail');
      }
      const opts: image.DecodingOptions = {
        editable: false,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        desiredSize: { width: maxSide, height: maxSide }
      };
      pixelMap = await source.createPixelMap(opts);
      if (pixelMap === undefined) {
        pixelMap = await source.createPixelMap();
      }
      if (pixelMap === undefined) {
        throw new OCRError('invalidImage', 'pixel_map_undefined', 'unknown_thumbnail');
      }
      const recognition = await recognizer.recognizePixelMap(pixelMap, options);
      const fields = new LogFields();
      fields.operation = 'ocr_document_extractor';
      fields.detail = `mode=unknown_thumbnail;textLen=${recognition.text.length};maxSide=${maxSide}`;
      Logger.info('ocr.unknown.thumbnail_ok', LogModule.OCR, fields);
      return recognition;
    } catch (thumbError) {
      try {
        return await recognizer.recognizeFromUri(pathOrUri, options);
      } catch (uriError) {
        const thumbDetail = thumbError instanceof Error ? thumbError.message : `${thumbError}`;
        const uriDetail = uriError instanceof Error ? uriError.message : `${uriError}`;
        throw new OCRError(
          'response',
          `unsupported_document_or_thumbnail_failed:thumb=${thumbDetail};uri=${uriDetail}`
        );
      }
    } finally {
      SafeOCRResourceRelease.pixelMap(pixelMap, 'unknown_doc_thumb');
      SafeOCRResourceRelease.imageSource(source, 'unknown_doc_source');
    }
  }

  /**
   * PDF Kit 要求沙箱路径。picker URI 先复制到缓存目录。
   */
  private async ensureSandboxPdfPath(pathOrUri: string): Promise<string> {
    if (pathOrUri.indexOf('/') === 0 && pathOrUri.indexOf('://') < 0) {
      return pathOrUri;
    }
    if (pathOrUri.indexOf('file://') === 0) {
      const stripped = pathOrUri.replace('file://', '');
      if (stripped.indexOf('/data/') === 0 || stripped.indexOf('/storage/') === 0) {
        return stripped;
      }
    }

    const cacheRoot = this.config.cacheDir.length > 0 ?
      `${this.config.cacheDir}/medical_ocr_pdf` :
      '';
    if (cacheRoot.length === 0) {
      // 无缓存目录时直接尝试原 URI（部分设备 PDF Kit 可接受）。
      return pathOrUri;
    }
    try {
      fs.mkdirSync(cacheRoot, true);
    } catch (_e) {
      // 目录可能已存在。
    }

    const dest = `${cacheRoot}/doc_${Date.now()}_${Math.floor(Math.random() * 100000)}.pdf`;
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
    } catch (error) {
      const detail = error instanceof Error ? error.message : `${error}`;
      throw new OCRError('invalidDocumentURL', `pdf_copy_failed:${detail}`);
    } finally {
      if (src !== undefined) {
        fs.closeSync(src);
      }
      if (dst !== undefined) {
        fs.closeSync(dst);
      }
    }
  }

  private logPdf(mode: string, textLen: number): void {
    const fields = new LogFields();
    fields.operation = 'ocr_document_extractor';
    fields.detail = `mode=${mode};textLen=${textLen}`;
    Logger.info('ocr.pdf.extracted', LogModule.OCR, fields);
  }
}
