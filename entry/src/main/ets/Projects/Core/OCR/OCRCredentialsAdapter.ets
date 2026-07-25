import {
  OCRAliyunCredentials,
  OCRCredentialsProvider
} from './OCRModels';

/**
 * 阿里云 OCR 凭证适配器占位。
 * 当前默认不启用远端 OCR；后续可接 SupportOCRAPI / STS。
 */
export class OCRCredentialsAdapter implements OCRCredentialsProvider {
  async fetchAliyunOCRCredentials(): Promise<OCRAliyunCredentials> {
    throw new Error('aliyun_ocr_credentials_unavailable');
  }
}
