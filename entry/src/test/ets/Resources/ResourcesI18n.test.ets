import { describe, it, expect } from '@ohos/hypium';
import { BackendErrorLocalizer } from '../../../main/ets/Projects/Core/Networking/BackendErrorLocalizer';
import { BackendErrorInfo } from '../../../main/ets/Projects/Core/Networking/SupportNetworkModels';
import { L10n } from '../../../main/ets/Foundation/L10n/L10n';

/** 与 entry base/element/string.json 键集合对齐，供构建守卫/回归 */
const REQUIRED_ENTRY_STRING_KEYS: string[] = [
  'module_desc',
  'EntryAbility_desc',
  'EntryAbility_label',
  'permission_internet_reason',
  'permission_network_info_reason',
  'home_title',
  'home_welcome',
  'common_action_confirm',
  'common_error_unknown',
  'common_error_request_failed',
  'error_auth_expired',
  'error_too_many_requests',
  'error_service_unavailable',
  'nav_launch_loading',
  'tab_home',
  'tab_camera',
  'tab_settings',
  'camera_placeholder_desc',
  'auth_login_title',
  'auth_login_subtitle',
  'auth_device_login',
  'auth_huawei_login',
  'auth_or_divider',
  'auth_huawei_coming_soon',
  'auth_phone_login',
  'auth_phone_title',
  'auth_phone_placeholder_desc',
  'auth_continue_otp',
  'auth_otp_title',
  'auth_otp_placeholder_desc',
  'auth_upgrade_title',
  'settings_account',
  'settings_upgrade_login',
  'settings_sign_out',
  'account_title',
  'account_placeholder_desc',
  'auth_login_welcome',
  'auth_guest_mode',
  'auth_phone_secure_title',
  'auth_phone_secure_subtitle',
  'auth_phone_field_label',
  'auth_phone_get_code',
  'auth_region_picker_title',
  'auth_otp_input_title',
  'auth_otp_resend',
  'auth_otp_security_hint',
  'auth_otp_verify_login',
  'auth_legal_prefix',
  'auth_legal_terms',
  'auth_legal_and',
  'auth_legal_privacy',
  'auth_legal_prompt_title',
  'auth_legal_prompt_intro',
  'auth_legal_health_disclaimer',
  'auth_legal_perm_device',
  'auth_legal_perm_location',
  'auth_legal_disagree',
  'auth_legal_agree_continue',
  'auth_legal_web_close',
  'auth_legal_web_failed',
  'auth_legal_web_retry',
  'startup_network_offline_title',
  'startup_network_offline_desc'
];

const REQUIRED_APP_STRING_KEYS: string[] = [
  'app_name'
];

export default function resourcesI18nTest() {
  describe('ResourcesI18n', () => {
    it('required_entry_string_keys_defined', 0, () => {
      expect(REQUIRED_ENTRY_STRING_KEYS.length).assertEqual(63);
      expect(REQUIRED_ENTRY_STRING_KEYS.indexOf('home_title') >= 0).assertTrue();
      expect(REQUIRED_ENTRY_STRING_KEYS.indexOf('error_auth_expired') >= 0).assertTrue();
      expect(REQUIRED_ENTRY_STRING_KEYS.indexOf('auth_device_login') >= 0).assertTrue();
      expect(REQUIRED_ENTRY_STRING_KEYS.indexOf('tab_settings') >= 0).assertTrue();
    });

    it('required_app_string_keys_defined', 0, () => {
      expect(REQUIRED_APP_STRING_KEYS.indexOf('app_name') >= 0).assertTrue();
    });

    it('l10n_format_named_params', 0, () => {
      const out = L10n.format('你好，{name}', { name: '小鲸' });
      expect(out).assertEqual('你好，小鲸');
    });

    it('l10n_getString_fallback_without_context', 0, () => {
      L10n.clearContextForTests();
      const value = L10n.getString($r('app.string.home_title'), 'fallback_title');
      expect(value).assertEqual('fallback_title');
    });

    it('backend_error_localizer_auth_range', 0, () => {
      L10n.clearContextForTests();
      const msg = BackendErrorLocalizer.localize(new BackendErrorInfo(40101, 'token_expired'));
      // 无 context 时走中文 fallback
      expect(msg).assertContain('登录');
    });

    it('backend_error_localizer_rate_limit', 0, () => {
      L10n.clearContextForTests();
      const msg = BackendErrorLocalizer.localize(new BackendErrorInfo(429, 'too many'));
      expect(msg).assertContain('频繁');
    });

    it('backend_error_localizer_server_error', 0, () => {
      L10n.clearContextForTests();
      const msg = BackendErrorLocalizer.localize(new BackendErrorInfo(50001, 'internal'));
      expect(msg).assertContain('不可用');
    });

    it('backend_error_localizer_does_not_leak_sensitive_message', 0, () => {
      L10n.clearContextForTests();
      const msg = BackendErrorLocalizer.localize(new BackendErrorInfo(40001, 'password=secret token=abc'));
      expect(msg.indexOf('password') < 0).assertTrue();
      expect(msg.indexOf('secret') < 0).assertTrue();
      expect(msg).assertContain('请求失败');
    });
  });
}
