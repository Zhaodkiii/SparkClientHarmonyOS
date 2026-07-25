import {
  ModelCapabilityProbeProgressItem,
  ModelCapabilityProbeStatus,
  probeStepTitle
} from '../../Application/AddOnlineModelModels';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { L10n } from '../../../../../Foundation/L10n/L10n';

/** 对标 iOS ModelCapabilityProbeSheet */
@Component
export struct ModelCapabilityProbeSheet {
  @Prop items: ModelCapabilityProbeProgressItem[] = [];

  build() {
    Column() {
      Text(L10n.getString($r('app.string.ai_settings_models_online_probe_sheet_title'), '能力探测结果'))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AISettingsUiTokens.textPrimary)
        .padding({ top: 16, bottom: 12 })

      List({ space: 4 }) {
        ForEach(this.items, (item: ModelCapabilityProbeProgressItem) => {
          ListItem() {
            Row({ space: 12 }) {
              this.statusIcon(item.status)
              Column({ space: 4 }) {
                Text(probeStepTitle(item.step))
                  .fontSize(15)
                  .fontColor(AISettingsUiTokens.textPrimary)
                  .width('100%')
                if (item.message.length > 0) {
                  Text(item.message)
                    .fontSize(12)
                    .fontColor(AISettingsUiTokens.textSecondary)
                    .width('100%')
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          }
        }, (item: ModelCapabilityProbeProgressItem) => `${item.step}-${item.status}-${item.message}`)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }

  @Builder
  private statusIcon(status: ModelCapabilityProbeStatus) {
    if (status === ModelCapabilityProbeStatus.RUNNING) {
      LoadingProgress().width(20).height(20)
    } else if (status === ModelCapabilityProbeStatus.SUCCESS) {
      Text('✓')
        .fontSize(18)
        .fontColor(AISettingsUiTokens.success)
        .width(20)
        .textAlign(TextAlign.Center)
    } else if (status === ModelCapabilityProbeStatus.FAILED) {
      Text('✕')
        .fontSize(18)
        .fontColor(AISettingsUiTokens.error)
        .width(20)
        .textAlign(TextAlign.Center)
    } else if (status === ModelCapabilityProbeStatus.SKIPPED) {
      Text('–')
        .fontSize(18)
        .fontColor(AISettingsUiTokens.textSecondary)
        .width(20)
        .textAlign(TextAlign.Center)
    } else {
      Text('○')
        .fontSize(16)
        .fontColor(AISettingsUiTokens.textSecondary)
        .width(20)
        .textAlign(TextAlign.Center)
    }
  }
}
