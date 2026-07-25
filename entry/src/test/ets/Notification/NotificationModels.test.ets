import { describe, it, expect } from '@ohos/hypium';
import {
  NotificationIntent,
  NotificationMessage
} from '../../../main/ets/Projects/Core/Notification/Domain/NotificationModels';

export default function notificationModelsTest() {
  describe('NotificationModels', () => {
    it('fallback_dedupe_key_from_level_presentation_message', 0, () => {
      const intent = new NotificationIntent('Hello World', 'info', 'toast', 'test');
      const msg = NotificationMessage.fromIntent(intent);
      expect(msg.dedupeKey).assertEqual('info|toast|hello world');
    });

    it('explicit_dedupe_key_wins', 0, () => {
      const intent = new NotificationIntent('Hello', 'info', 'toast', 'test', undefined, 'custom.key');
      const msg = NotificationMessage.fromIntent(intent);
      expect(msg.dedupeKey).assertEqual('custom.key');
    });

    it('default_presentation_maps_success_info_to_toast', 0, () => {
      expect(NotificationMessage.defaultPresentationFor('success')).assertEqual('toast');
      expect(NotificationMessage.defaultPresentationFor('info')).assertEqual('toast');
    });

    it('default_presentation_maps_warning_error_to_banner', 0, () => {
      expect(NotificationMessage.defaultPresentationFor('warning')).assertEqual('banner');
      expect(NotificationMessage.defaultPresentationFor('error')).assertEqual('banner');
    });

    it('ui_json_roundtrip_keeps_message', 0, () => {
      const intent = NotificationIntent.toast('ok', 'success', 'unit');
      const msg = NotificationMessage.fromIntent(intent);
      const restored = NotificationMessage.fromUiJson(msg.toUiJson());
      expect(restored !== undefined).assertTrue();
      expect(restored!.message).assertEqual('ok');
      expect(restored!.level).assertEqual('success');
    });
  });
}
