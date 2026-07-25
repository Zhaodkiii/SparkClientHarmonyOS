import { describe, it, expect } from '@ohos/hypium';
import { UserSession } from '../../../main/ets/Projects/Core/Domain/Entities/UserSession';
import { AccountProfile } from '../../../main/ets/Projects/Features/AccountManagement/Domain/AccountProfile';
import {
  AccountIdentityProviders,
  AccountIdentityStatus,
  AccountIdentityList,
  AccountIdentityOperation
} from '../../../main/ets/Projects/Features/AccountManagement/Domain/AccountIdentityModels';
import {
  VerifyIdentityRequest,
  BindIdentityRequest,
  ChangeIdentityRequest,
  IdentityVerificationRequestBody
} from '../../../main/ets/Projects/Core/Networking/API/Account/AccountIdentityAPI';
import { DeactivationVerificationPayload } from '../../../main/ets/Projects/Core/Networking/API/Account/DeactivationAPI';
import { SettingsAccountRouting } from '../../../main/ets/Projects/Features/Settings/SettingsAccountRouting';
import { AccountIdentityFlowState } from '../../../main/ets/Projects/Features/AccountManagement/Presentation/AccountIdentityFlowState';
import { AccountDeactivationFlowState } from '../../../main/ets/Projects/Features/AccountManagement/Presentation/AccountDeactivationFlowState';

export default function accountManagementTest() {
  describe('AccountManagement', () => {
    it('profile_from_session_maps_fields', 0, () => {
      const session = new UserSession(99, 'phone', '+8613800138000', '小鲸', 1000, true, false, false);
      const profile = AccountProfile.fromSession(session);
      expect(profile.accountId).assertEqual(99);
      expect(profile.displayName).assertEqual('小鲸');
      expect(profile.contact).assertEqual('+8613800138000');
      expect(profile.isDeviceAccount).assertFalse();
      expect(profile.signInMethodDescription().indexOf('手机') >= 0).assertTrue();
    });

    it('profile_from_phone_session_uses_display_name_as_contact_fallback', 0, () => {
      const session = new UserSession(99, 'phone', '', '+8613800138000', 1000, true, false, false);
      const profile = AccountProfile.fromSession(session);
      expect(profile.contact).assertEqual('+8613800138000');
    });

    it('identity_providers_filter_unknown', 0, () => {
      expect(AccountIdentityProviders.parse('phone')).assertEqual('phone');
      expect(AccountIdentityProviders.parse('email')).assertEqual('email');
      expect(AccountIdentityProviders.parse('huawei')).assertEqual('huawei');
      expect(AccountIdentityProviders.parse('apple')).assertEqual('huawei');
      expect(AccountIdentityProviders.parse('google') === undefined).assertTrue();
      expect(AccountIdentityProviders.isComingSoon('huawei')).assertTrue();
      expect(AccountIdentityProviders.isComingSoon('phone')).assertFalse();
    });

    it('identity_list_unknown_provider_not_kept_by_parse', 0, () => {
      const kept: AccountIdentityStatus[] = [];
      const raws = ['phone', 'apple', 'email', 'unknown'];
      for (let i = 0; i < raws.length; i++) {
        const p = AccountIdentityProviders.parse(raws[i]);
        if (p !== undefined) {
          kept.push(new AccountIdentityStatus(p, true, 'x', true, false));
        }
      }
      expect(kept.length).assertEqual(3);
      expect(kept[0].provider).assertEqual('phone');
      expect(kept[1].provider).assertEqual('huawei');
      expect(kept[2].provider).assertEqual('email');
      const list = new AccountIdentityList(1, 'bundle', 'scope', kept);
      expect(list.identities.length).assertEqual(3);
    });

    it('identity_operation_purpose_and_scene', 0, () => {
      const bind = AccountIdentityOperation.bind('phone');
      expect(bind.purpose).assertEqual('bind_identity');
      expect(bind.targetOtpScene()).assertEqual('identity_bind');
      const change = AccountIdentityOperation.change('email');
      expect(change.purpose).assertEqual('change_identity');
      expect(change.targetOtpScene()).assertEqual('identity_change');
    });

    it('api_verify_bind_change_request_fields', 0, () => {
      const verify = VerifyIdentityRequest.phoneOtp('change_identity', 'otp1', '123456', 'b', 'd');
      const vr = verify.toRecord();
      expect(`${vr['provider']}`).assertEqual('phone');
      expect(`${vr['purpose']}`).assertEqual('change_identity');
      expect(`${vr['otp_id']}`).assertEqual('otp1');
      expect(`${vr['code']}`).assertEqual('123456');
      expect(`${vr['bundle_id']}`).assertEqual('b');

      const bind = BindIdentityRequest.email('ticket', 'a@b.c', 'otp2', '654321', 'b', 'd');
      const br = bind.toRecord();
      expect(`${br['provider']}`).assertEqual('email');
      expect(`${br['verification_ticket']}`).assertEqual('ticket');
      expect(`${br['target']}`).assertEqual('a@b.c');
      expect(`${br['otp_id']}`).assertEqual('otp2');

      const change = new ChangeIdentityRequest('phone', 't', '+86111', 'otp3', '111111', 'b', 'd');
      const cr = change.toRecord();
      expect(`${cr['new_target']}`).assertEqual('+86111');
      expect(`${cr['new_otp_id']}`).assertEqual('otp3');
      expect(`${cr['new_code']}`).assertEqual('111111');

      const req = new IdentityVerificationRequestBody('phone', 'bind_identity', 'b', 'd');
      const rr = req.toRecord();
      expect(`${rr['bundle_id']}`).assertEqual('b');
      expect(`${rr['device_id']}`).assertEqual('d');
    });

    it('deactivation_verification_payload_uses_type', 0, () => {
      const phone = DeactivationVerificationPayload.phone('oid', 'code');
      const pr = phone.toRecord();
      expect(`${pr['type']}`).assertEqual('phone');
      expect(`${pr['otp_id']}`).assertEqual('oid');
      expect(`${pr['code']}`).assertEqual('code');
      const email = DeactivationVerificationPayload.email('e1', '999999');
      expect(`${email.toRecord()['type']}`).assertEqual('email');
    });

    it('settings_account_routing_guest_formal_loading', 0, () => {
      const guest = new UserSession(1, 'device', '', '游客', Date.now(), false, true, true);
      const formal = new UserSession(2, 'phone', '138****0000', '正式', Date.now(), false, false, false);
      expect(SettingsAccountRouting.resolveAction('loading', formal)).assertEqual('disabled');
      expect(SettingsAccountRouting.resolveAction('signedIn', guest)).assertEqual('upgrade');
      expect(SettingsAccountRouting.resolveAction('signedIn', formal)).assertEqual('openAccount');
      expect(SettingsAccountRouting.resolveAction('signedOut', undefined)).assertEqual('none');
      expect(SettingsAccountRouting.summaryText('signedIn', guest)).assertEqual('游客模式');
      expect(SettingsAccountRouting.summaryText('signedIn', formal)).assertEqual('正式');
    });

    it('identity_and_deactivation_flow_phases', 0, () => {
      const idFlow = AccountIdentityFlowState.idle();
      expect(idFlow.isOverlayPresented()).assertFalse();
      idFlow.phase = 'choosingReauth';
      idFlow.operation = AccountIdentityOperation.bind('phone');
      expect(idFlow.isOverlayPresented()).assertTrue();
      idFlow.verificationTicket = 'secret-ticket';
      idFlow.reset();
      expect(idFlow.phase).assertEqual('idle');
      expect(idFlow.verificationTicket).assertEqual('');

      const deact = AccountDeactivationFlowState.idle();
      deact.phase = 'chooseVerification';
      expect(deact.isOverlayPresented()).assertTrue();
      deact.phase = 'completed';
      expect(deact.isOverlayPresented()).assertFalse();
    });
  });
}
