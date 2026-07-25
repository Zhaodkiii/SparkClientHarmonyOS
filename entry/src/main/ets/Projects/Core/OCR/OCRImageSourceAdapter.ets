import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { OCRDiagnostics } from './OCRDiagnostics';
import { OCRError } from './OCRModels';

/** 安全释放：失败只记 warn，绝不覆盖主识别结果。 */
export class SafeOCRResourceRelease {
  static pixelMap(pixelMap: image.PixelMap | undefined, phase: string): void {
    if (pixelMap === undefined || pixelMap === null) {
      return;
    }
    try {
      pixelMap.release();
    } catch (error) {
      OCRDiagnostics.warn('ocr.resource.release_failed',
        `phase=${phase};error=${OCRDiagnostics.errorMessage(error)}`);
    }
  }

  static imageSource(source: image.ImageSource | undefined, phase: string): void {
    if (source === undefined || source === null) {
      return;
    }
    try {
      source.release();
    } catch (error) {
      OCRDiagnostics.warn('ocr.resource.release_failed',
        `phase=${phase};error=${OCRDiagnostics.errorMessage(error)}`);
    }
  }

  static file(file: fs.File | undefined, phase: string): void {
    if (file === undefined || file === null) {
      return;
    }
    try {
      fs.closeSync(file);
    } catch (error) {
      OCRDiagnostics.warn('ocr.resource.release_failed',
        `phase=${phase};error=${OCRDiagnostics.errorMessage(error)}`);
    }
  }
}

/** 打开后的 PixelMap 句柄；调用方 finally 必须 releaseSafely。 */
export class OCRPixelMapHandle {
  private file?: fs.File;
  private source?: image.ImageSource;
  readonly pixelMap: image.PixelMap;
  private released: boolean = false;

  constructor(file: fs.File | undefined, source: image.ImageSource | undefined, pixelMap: image.PixelMap) {
    this.file = file;
    this.source = source;
    this.pixelMap = pixelMap;
  }

  releaseSafely(): void {
    if (this.released) {
      return;
    }
    this.released = true;
    SafeOCRResourceRelease.pixelMap(this.pixelMap, 'ocr_pixel_map');
    SafeOCRResourceRelease.imageSource(this.source, 'ocr_image_source');
    SafeOCRResourceRelease.file(this.file, 'ocr_file');
    this.source = undefined;
    this.file = undefined;
  }
}

/**
 * 按官方示例：fileIo.open(uri) → createImageSource(fd) → createPixelMap。
 * VisionInfo 仅支持 RGBA_8888 PixelMap。
 */
export class OCRImageSourceAdapter {
  async openPixelMap(uri: string): Promise<OCRPixelMapHandle> {
    if (uri.length === 0) {
      throw new OCRError('invalidImage', 'empty_uri', 'image_uri');
    }

    try {
      return await OCRImageSourceAdapter.openViaFd(uri);
    } catch (fdError) {
      OCRDiagnostics.warn('ocr.image.fd_open_failed',
        `${OCRDiagnostics.uriFingerprint(uri)};error=${OCRDiagnostics.errorMessage(fdError)}`);
    }

    return await OCRImageSourceAdapter.openViaUri(uri);
  }

  /**
   * 官方约束：VisionInfo.pixelMap 仅支持 RGBA_8888。
   * 解码阶段已尽量指定 desiredPixelFormat；此处再兜底重建。
   */
  async ensureRgba8888(pixelMap: image.PixelMap): Promise<image.PixelMap> {
    try {
      const info = await pixelMap.getImageInfo();
      const width = info.size.width;
      const height = info.size.height;
      const format = info.pixelFormat;
      if (format === image.PixelMapFormat.RGBA_8888) {
        OCRDiagnostics.info('ocr.image.rgba_ready', `w=${width};h=${height};fromFormat=${format};action=reuse`);
        return pixelMap;
      }

      const buf = new ArrayBuffer(pixelMap.getPixelBytesNumber());
      await pixelMap.readPixelsToBuffer(buf);
      const init: image.InitializationOptions = {
        editable: false,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: { width: width, height: height }
      };
      const rgba = await image.createPixelMap(buf, init);
      if (rgba === undefined) {
        OCRDiagnostics.warn('ocr.image.rgba_rebuild_failed', 'fallback=original');
        return pixelMap;
      }
      OCRDiagnostics.info('ocr.image.rgba_ready',
        `w=${width};h=${height};fromFormat=${format};action=rebuild`);
      return rgba;
    } catch (error) {
      OCRDiagnostics.warn('ocr.image.rgba_ensure_failed',
        `error=${OCRDiagnostics.errorMessage(error)};fallback=original`);
      return pixelMap;
    }
  }

  private static async openViaFd(uri: string): Promise<OCRPixelMapHandle> {
    let file: fs.File | undefined = undefined;
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      file = await fs.open(uri, fs.OpenMode.READ_ONLY);
      if (file === undefined) {
        throw new OCRError('invalidImage', 'open_file_undefined', 'image_uri_to_pixel_map');
      }
      source = image.createImageSource(file.fd);
      if (source === undefined) {
        throw new OCRError('invalidImage', 'image_source_undefined', 'image_source_create');
      }
      pixelMap = await OCRImageSourceAdapter.createPreferredPixelMap(source);
      if (pixelMap === undefined) {
        throw new OCRError('invalidImage', 'pixel_map_undefined', 'create_pixel_map');
      }
      const handle = new OCRPixelMapHandle(file, source, pixelMap);
      file = undefined;
      source = undefined;
      pixelMap = undefined;
      return handle;
    } catch (error) {
      SafeOCRResourceRelease.pixelMap(pixelMap, 'open_pixel_map_failed');
      SafeOCRResourceRelease.imageSource(source, 'open_source_failed');
      SafeOCRResourceRelease.file(file, 'open_file_failed');
      if (error instanceof OCRError) {
        throw new OCRError(error.code, error.detail, error.phase);
      }
      throw new OCRError(
        'invalidImage',
        `image_uri_to_pixel_map:${OCRDiagnostics.errorMessage(error)}`,
        'image_uri_to_pixel_map'
      );
    }
  }

  private static async openViaUri(uri: string): Promise<OCRPixelMapHandle> {
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      source = image.createImageSource(uri);
      if (source === undefined) {
        throw new OCRError('invalidImage', 'image_source_undefined', 'image_source_create');
      }
      pixelMap = await OCRImageSourceAdapter.createPreferredPixelMap(source);
      if (pixelMap === undefined) {
        throw new OCRError('invalidImage', 'pixel_map_undefined', 'create_pixel_map');
      }
      const handle = new OCRPixelMapHandle(undefined, source, pixelMap);
      source = undefined;
      pixelMap = undefined;
      return handle;
    } catch (error) {
      SafeOCRResourceRelease.pixelMap(pixelMap, 'open_uri_pixel_map_failed');
      SafeOCRResourceRelease.imageSource(source, 'open_uri_source_failed');
      if (error instanceof OCRError) {
        throw new OCRError(error.code, error.detail, error.phase);
      }
      throw new OCRError(
        'invalidImage',
        `image_source_create_failed:${OCRDiagnostics.errorMessage(error)}`,
        'image_source_create'
      );
    }
  }

  private static async createPreferredPixelMap(source: image.ImageSource): Promise<image.PixelMap> {
    try {
      const opts: image.DecodingOptions = {
        editable: false,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      const pixelMap = await source.createPixelMap(opts);
      if (pixelMap !== undefined) {
        return pixelMap;
      }
    } catch (error) {
      OCRDiagnostics.warn('ocr.image.decode_rgba_opt_failed',
        `error=${OCRDiagnostics.errorMessage(error)}`);
    }
    const fallback = await source.createPixelMap();
    if (fallback === undefined) {
      throw new OCRError('invalidImage', 'pixel_map_undefined', 'create_pixel_map');
    }
    return fallback;
  }
}
