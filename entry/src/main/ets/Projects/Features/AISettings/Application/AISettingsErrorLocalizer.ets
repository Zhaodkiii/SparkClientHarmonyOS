import { AIKeyStoreError } from '../../../../Core/AI/Infrastructure/AIKeyStore';
import { SupportNetworkError } from '../../../Core/Networking/SupportNetworkModels';

/**
 * AI 设置错误脱敏：禁止 Key/URL query/stack/body 进入 UI。
 */
export class AISettingsErrorLocalizer {
  static localize(err: Object | string | undefined): string {
    if (err === undefined || err === null) {
      return '操作失败';
    }
    if (err instanceof AIKeyStoreError) {
      if (err.code === 'secureStorageUnavailable') {
        return '安全存储不可用，无法保存 API Key';
      }
      return '密钥操作失败';
    }
    if (err instanceof SupportNetworkError) {
      if (err.statusCode === 401) {
        return '登录已失效，请重新登录';
      }
      if (err.kind === 'business') {
        return err.backend?.message || '业务请求失败';
      }
      return '网络请求失败，请稍后重试';
    }
    const raw = `${err}`;
    const lower = raw.toLowerCase();
    if (lower.indexOf('sk-') >= 0 || lower.indexOf('api_key') >= 0 || lower.indexOf('apikey') >= 0) {
      return '操作失败';
    }
    if (lower.indexOf('securestorageunavailable') >= 0) {
      return '安全存储不可用，无法保存 API Key';
    }
    if (raw.length > 120) {
      return '操作失败，请稍后重试';
    }
    // 去掉可能的堆栈
    const firstLine = raw.split('\n')[0];
    if (firstLine.indexOf('Error:') === 0) {
      return firstLine.substring(6).trim() || '操作失败';
    }
    return firstLine || '操作失败';
  }
}
