import { BackendErrorInfo } from './SupportNetworkModels';
import { L10n } from '../../../Foundation/L10n/L10n';

function buildCodeMessages(): Record<string, string> {
  const m: Record<string, string> = {};
  m['4030'] = '仅上传者可删除此附件。';
  m['4040'] = '文件不存在或已删除。';
  m['4042'] = '文件存储信息缺失，暂时无法访问。';
  return m;
}

function buildMsgMessages(): Record<string, string> {
  const m: Record<string, string> = {};
  m['apple_bundle_audience_not_configured'] = 'Apple 登录配置未完成，请联系管理员。';
  m['apple_identity_bind_failed'] = 'Apple 账号绑定失败，请稍后重试。';
  m['apple_identity_change_not_supported'] = 'Apple 登录暂不支持修改';
  m['apple_jwks_invalid'] = 'Apple 登录校验失败，请稍后重试。';
  m['apple_nonce_mismatch'] = 'Apple 登录校验失败，请重试。';
  m['apple_public_key_not_found'] = 'Apple 登录校验失败，请稍后重试。';
  m['apple_sub_missing'] = 'Apple 登录信息不完整，请重试。';
  m['apple_subject_mismatch'] = 'Apple 登录账号不匹配，请重新登录。';
  m['apple_token_kid_missing'] = 'Apple 登录令牌缺少必要标识。';
  m['bundle_id_mismatch'] = '当前应用环境不匹配，请重新获取验证码。';
  m['bundle_id_not_allowed'] = '当前应用版本暂不支持该登录方式。';
  m['email_send_failed'] = '邮件发送失败，请稍后重试。';
  m['file_not_found'] = '文件不存在或已删除。';
  m['file_permission_denied'] = '仅上传者可删除此附件。';
  m['identity_already_bound_to_active_user'] = '该登录方式已绑定其他账号，无法绑定或修改';
  m['identity_not_bound'] = '当前账号尚未绑定该登录方式';
  m['identity_token_required'] = '无法读取 Apple 身份令牌。';
  m['invalid_credentials'] = '账号或密码不正确。';
  m['invalid_otp'] = '验证码错误，请重新输入。';
  m['invalid_phone_number'] = '手机号格式不正确，请重新输入。';
  m['last_identity_cannot_be_removed'] = '请至少保留一种可用登录方式';
  m['otp_already_used'] = '验证码已使用，请重新获取。';
  m['otp_expired'] = '验证码已过期，请重新获取。';
  m['otp_not_found'] = '验证码不存在或已失效，请重新获取。';
  m['otp_otp_invalid'] = '验证码错误，请重新输入';
  m['otp_requested_too_frequently'] = '验证码请求过于频繁，请稍后再试。';
  m['otp_sms_not_sent'] = '验证码短信未发送成功，请重新获取。';
  m['otp_temporarily_locked'] = '验证码尝试次数过多，请稍后再试。';
  m['otp_unavailable'] = '当前验证码不可用，请重新获取。';
  m['phone_identity_not_linked_to_current_user'] = '手机号未绑定到当前账号。';
  m['phone_number_required'] = '请输入手机号。';
  m['phone_region_not_supported'] = '当前手机号地区暂不支持短信验证码服务。';
  m['sms_send_failed'] = '短信发送失败，请稍后重试。';
  m['sms_send_rate_limited'] = '短信发送过于频繁，请稍后再试。';
  m['sms_send_unknown'] = '短信发送结果暂时未知，请稍后重试。';
  m['target_otp_expired'] = '验证码已过期，请重新获取';
  m['target_otp_invalid'] = '验证码错误，请重新输入';
  m['token_not_valid'] = '登录状态失效，请重新登录。';
  m['unsupported_verification_type'] = '当前验证方式暂不支持。';
  m['user_context_mismatch'] = '当前用户信息不匹配，请重新进入后重试。';
  m['user_id_required_for_account_deactivation'] = '注销申请缺少用户信息，请重试。';
  m['user_identity_mismatch'] = '当前账号与验证信息不匹配，请重新获取验证码。';
  m['user_inactive'] = '当前账号已停用，请联系管理员。';
  m['verification_required'] = '请先完成验证后再继续。';
  m['verification_ticket_expired'] = '验证已过期，请重新验证';
  m['verification_ticket_invalid'] = '验证无效，请重新验证';
  m['verification_ticket_used'] = '验证已失效，请重新验证';
  return m;
}

const CODE_MESSAGES: Record<string, string> = buildCodeMessages();
const MSG_MESSAGES: Record<string, string> = buildMsgMessages();

/**
 * 将后端错误映射为本地化提示；规则对齐 iOS BackendErrorLocalizer。
 */
export class BackendErrorLocalizer {
  static localize(error: BackendErrorInfo | undefined, statusCode?: number): string {
    if (error) {
      const embedded = BackendErrorLocalizer.embeddedUserMessage(error.rawMsg);
      if (embedded.length > 0) {
        return embedded;
      }

      const validationText = BackendErrorLocalizer.validationMessage(error.rawMsg);
      if (validationText.length > 0) {
        return validationText;
      }

      const codeText = CODE_MESSAGES[`${error.code}`];
      if (codeText) {
        return codeText;
      }

      const msgKey = BackendErrorLocalizer.messageKey(error.message);
      const msgText = MSG_MESSAGES[msgKey];
      if (msgText) {
        return msgText;
      }

      const cleanMessage = error.message.trim();
      if (cleanMessage.length > 0) {
        return cleanMessage;
      }
    }

    if (statusCode !== undefined) {
      return `请求失败（HTTP ${statusCode}），请稍后重试。`;
    }

    return L10n.getString($r('app.string.api_error_unknown'), '操作失败，请稍后重试。');
  }

  static unknown(): string {
    return L10n.getString($r('app.string.api_error_unknown'), '操作失败，请稍后重试。');
  }

  private static embeddedUserMessage(raw: Object | undefined): string {
    if (!raw || typeof raw !== 'object') {
      return '';
    }
    const obj = raw as Record<string, Object | string | number | boolean | null | undefined>;
    const message = obj['message'];
    if (typeof message === 'string') {
      return message.trim();
    }
    const msg = obj['msg'];
    if (typeof msg === 'string') {
      return msg.trim();
    }
    return '';
  }

  private static validationMessage(raw: Object | undefined): string {
    if (!raw || typeof raw !== 'object') {
      return '';
    }
    const obj = raw as Record<string, Object | string | number | boolean | null | undefined>;
    if (obj['phone_number'] !== undefined || obj['phoneNumber'] !== undefined) {
      return MSG_MESSAGES['phone_number_required'];
    }
    if (obj['code'] !== undefined || obj['otp'] !== undefined || obj['otp_code'] !== undefined) {
      return MSG_MESSAGES['invalid_otp'];
    }
    if (obj['bundle_id'] !== undefined || obj['bundleId'] !== undefined ||
      obj['device_id'] !== undefined || obj['deviceId'] !== undefined) {
      return MSG_MESSAGES['bundle_id_mismatch'];
    }
    return '';
  }

  private static messageKey(message: string): string {
    const normalized = message
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .replace(/_+/g, '_');
    return normalized.length > 0 ? normalized : 'unknown';
  }
}
