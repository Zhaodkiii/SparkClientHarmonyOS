import { describe, it, expect } from '@ohos/hypium';
import { PhoneRegion } from '../../../main/ets/Projects/Features/Auth/PhoneRegion';
import { AuthUiState } from '../../../main/ets/Projects/Features/Auth/AuthUiState';
import { LoginViewModel } from '../../../main/ets/Projects/Features/Auth/LoginViewModel';
import { LegalUrls } from '../../../main/ets/App/LegalAcceptanceStore';

export default function authUiTest() {
  describe('AuthUi', () => {
    it('phone_region_common_list_has_required_locales', 0, () => {
      const list = PhoneRegion.commonRegions();
      expect(list.length).assertEqual(12);
      const codes = list.map((r: PhoneRegion) => r.code);
      expect(codes.indexOf('CN') >= 0).assertTrue();
      expect(codes.indexOf('HK') >= 0).assertTrue();
      expect(codes.indexOf('TW') >= 0).assertTrue();
      expect(codes.indexOf('JP') >= 0).assertTrue();
      expect(codes.indexOf('SG') >= 0).assertTrue();
    });

    it('phone_region_ready_requires_min_digits', 0, () => {
      expect(PhoneRegion.isPhoneReady('12345')).assertFalse();
      expect(PhoneRegion.isPhoneReady('123456')).assertTrue();
      expect(PhoneRegion.isPhoneReady('138-0013-8000')).assertTrue();
    });

    it('phone_region_to_e164', 0, () => {
      const cn = PhoneRegion.china();
      expect(cn.toE164('13800138000')).assertEqual('+8613800138000');
    });

    it('legal_gate_blocks_until_accepted', 0, () => {
      const vm = new LoginViewModel();
      vm.state.legalAccepted = false;
      const allowed = vm.requestAction('device');
      expect(allowed).assertFalse();
      expect(vm.state.showLegalPrompt).assertTrue();
      expect(vm.state.pendingAction).assertEqual('device');
    });

    it('legal_gate_allows_when_accepted', 0, () => {
      const vm = new LoginViewModel();
      vm.state.legalAccepted = true;
      const allowed = vm.requestAction('phone');
      expect(allowed).assertTrue();
      expect(vm.state.showLegalPrompt).assertFalse();
    });

    it('otp_submit_requires_six_digits', 0, async () => {
      const vm = new LoginViewModel();
      vm.state.otpId = 'otp-1';
      vm.state.phoneLocalNumber = '13800138000';
      const session = await vm.verifyOtp('123');
      expect(session === undefined).assertTrue();
      expect(vm.state.errorText.length > 0).assertTrue();
    });

    it('masked_phone_redacts_middle', 0, () => {
      const vm = new LoginViewModel();
      vm.state.phoneLocalNumber = '13800138000';
      const masked = vm.maskedPhone();
      expect(masked.indexOf('****') >= 0).assertTrue();
      expect(masked.indexOf('13800138000') < 0).assertTrue();
    });

    it('legal_urls_are_https', 0, () => {
      expect(LegalUrls.TERMS.indexOf('https://') === 0).assertTrue();
      expect(LegalUrls.PRIVACY.indexOf('https://') === 0).assertTrue();
      expect(LegalUrls.urlFor('privacy')).assertEqual(LegalUrls.PRIVACY);
    });

    it('auth_ui_state_legal_version_defined', 0, () => {
      expect(AuthUiState.LEGAL_VERSION.length > 0).assertTrue();
    });

    it('countdown_starts_and_stops', 0, async () => {
      const vm = new LoginViewModel();
      vm.startCountdown(2);
      expect(vm.state.otpCountdownSec).assertEqual(2);
      vm.stopCountdown();
      expect(vm.state.otpCountdownSec).assertEqual(2);
      vm.dispose();
    });
  });
}
