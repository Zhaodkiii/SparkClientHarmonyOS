import {
  NOTIFICATION_BANNER_KEY,
  NOTIFICATION_TOAST_KEY
} from '../../Projects/Core/Notification/Application/NotificationStore';
import { NotificationToastView } from './NotificationToast';
import { NotificationBannerView } from './NotificationBanner';
import { AppContainer } from '../AppContainer';

/**
 * 根级通知 Host：顶部 banner + toast overlay。
 */
@Component
export struct AppNotificationHost {
  @StorageLink(NOTIFICATION_TOAST_KEY) toastJson: string = '';
  @StorageLink(NOTIFICATION_BANNER_KEY) bannerJson: string = '';

  build() {
    Column({ space: 8 }) {
      if (this.bannerJson.length > 0) {
        NotificationBannerView({
          json: this.bannerJson,
          onClose: () => {
            AppContainer.shared()?.notificationAssembly.delivery.dismissCurrentBanner(false);
          },
          onTap: () => {
            AppContainer.shared()?.notificationAssembly.delivery.dismissCurrentBanner(true);
          }
        })
      }
      if (this.toastJson.length > 0) {
        NotificationToastView({ json: this.toastJson })
      }
    }
    .width('100%')
    .padding({ top: 12, left: 8, right: 8 })
    .alignItems(HorizontalAlign.Center)
  }
}
