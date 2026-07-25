import { image } from '@kit.ImageKit';

/**
 * 医疗图片预处理入口（HOS-MED-UPLOAD-0007）。
 * iOS 使用 Core Image：灰度 → 降噪 → 对比度/亮度 → 锐化。
 * HarmonyOS 当前刻意透传：未经真机收益验证前不套滤镜，避免破坏 OCR。
 * Orchestrator 已通过 options.applyPreprocess 调用本入口；后续可接 ImageEffect。
 */
export class MedicalImagePreprocessor {
  private static readonly sharedInstance: MedicalImagePreprocessor = new MedicalImagePreprocessor();

  contrastFactor: number = 1.1;
  brightnessFactor: number = 0.02;
  sharpnessFactor: number = 0.3;
  enableNoiseReduction: boolean = true;
  enhanceEdges: boolean = false;

  static shared(): MedicalImagePreprocessor {
    return MedicalImagePreprocessor.sharedInstance;
  }

  /** 当前透传；参数字段预留给真机验证后的滤镜实现。 */
  preprocess(pixelMap: image.PixelMap): image.PixelMap {
    return pixelMap;
  }
}
