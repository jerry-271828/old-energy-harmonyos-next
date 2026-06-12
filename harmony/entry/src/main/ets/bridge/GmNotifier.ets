import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'GmNotifier';

const SLOT_TYPE: notificationManager.SlotType = notificationManager.SlotType.SOCIAL_COMMUNICATION;

export class GmNotifier {
  private static initialized: boolean = false;
  private static seq: number = 1000;

  static init(ctx: common.UIAbilityContext): void {
    if (GmNotifier.initialized) {
      return;
    }
    GmNotifier.initialized = true;
    notificationManager.addSlot(SLOT_TYPE)
      .then(() => {
        hilog.info(DOMAIN, TAG, 'slot added');
      })
      .catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'addSlot failed: %{public}s', err.message);
      });

    notificationManager.isNotificationEnabled()
      .then((enabled: boolean) => {
        if (!enabled) {
          notificationManager.requestEnableNotification(ctx)
            .catch((err: BusinessError) => {
              hilog.info(DOMAIN, TAG, 'requestEnable rejected: %{public}s', err.message);
            });
        }
      })
      .catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'isEnabled failed: %{public}s', err.message);
      });
  }

  static publish(title: string, text: string): void {
    const t = title || '提示';
    const body = text || '';
    const id = GmNotifier.seq++;

    const request: notificationManager.NotificationRequest = {
      id: id,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: t,
          text: body,
          additionalText: ''
        }
      },
      deliveryTime: new Date().getTime(),
      showDeliveryTime: true,
      tapDismissed: true
    };

    notificationManager.publish(request)
      .catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'publish failed: %{public}s', err.message);
      });
  }
}
