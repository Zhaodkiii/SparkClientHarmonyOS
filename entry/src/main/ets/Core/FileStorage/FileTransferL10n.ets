/**
 * 文件传输领域文案（简体中文资源表）。
 * 本地化器与页面共用，避免散落硬编码。
 */
export class FileTransferL10n {
  static text(key: string, fallback?: string): string {
    switch (key) {
      case 'file.transfer.error.title':
        return '上传失败';
      case 'file.transfer.error.title.pending_save':
        return '等待保存';
      case 'file.transfer.error.title.unauthorized':
        return '未授权';
      case 'file.transfer.error.title.network':
        return '网络异常';
      case 'file.transfer.error.network':
        return '网络不稳定，请检查网络后重试。';
      case 'file.transfer.error.credentials_expired':
        return '上传凭证已失效，请重试。';
      case 'file.transfer.error.clock_skew':
        return '设备时间异常，请校准系统时间后重试。';
      case 'file.transfer.error.access_denied':
        return '暂时无法上传，请稍后再试。';
      case 'file.transfer.error.integrity':
        return '文件校验失败，请重新选择文件后重试。';
      case 'file.transfer.error.source_invalid':
        return '该文件无法上传，请重新选择。';
      case 'file.transfer.error.request_invalid_file':
        return '文件暂不支持上传，请重新选择文件。';
      case 'file.transfer.error.request_validation_unknown':
        return '上传参数异常，请重试。若持续失败，请稍后再试。';
      case 'file.transfer.error.request_validation_repeat':
        return '上传参数异常，请稍后再试。';
      case 'file.transfer.error.configuration':
        return '上传服务配置异常，请稍后再试。';
      case 'file.transfer.error.conflict':
        return '文件上传状态冲突，请稍后重试。';
      case 'file.transfer.error.transient':
        return '上传失败，请稍后重试。';
      case 'file.transfer.error.rcp_transport':
        return '网络连接不稳定，请稍后重试。';
      case 'file.transfer.error.rcp_transport_repeat':
        return '网络连接不稳定，请稍后再试。';
      case 'file.transfer.error.multipart_initiate':
        return '上传初始化失败，请稍后重试。';
      case 'file.transfer.error.multipart_part':
        return '正在重试上传，请稍候。';
      case 'file.transfer.error.multipart_complete':
        return '文件正在整理，请稍后重试。';
      case 'file.transfer.error.multipart_abort':
        return '已取消上传清理，请稍后重试。';
      case 'file.transfer.error.multipart_list':
        return '上传进度同步失败，请稍后重试。';
      case 'file.transfer.error.multipart_integrity':
        return '分片校验失败，请稍后重试。';
      case 'file.transfer.error.multipart_checkpoint':
        return '文件已变化，请重新选择。';
      case 'file.transfer.error.registration_pending':
        return '文件已上传，正在保存附件。请重试。';
      case 'file.transfer.error.unauthorized':
        return '登录状态已失效，请重新登录后重试。';
      case 'file.transfer.error.generation':
        return '账号已切换，请返回后重试。';
      case 'file.transfer.error.unavailable':
        return '文件暂不可用，请稍后重试。';
      case 'file.transfer.error.unknown':
        return '上传失败，请稍后重试。';
      case 'file.transfer.action.retry_upload':
        return '重试上传';
      case 'file.transfer.action.retry_save':
        return '重试保存';
      case 'file.transfer.action.return_picking':
        return '返回文件选择';
      case 'file.transfer.action.reselect':
        return '重新选择';
      case 'file.transfer.action.remove':
        return '移除文件';
      case 'file.transfer.action.cancel':
        return '取消';
      default:
        return fallback ?? key;
    }
  }
}
