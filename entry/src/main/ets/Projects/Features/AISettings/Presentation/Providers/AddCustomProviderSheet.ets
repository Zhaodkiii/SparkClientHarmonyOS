import { promptAction } from '@kit.ArkUI';
import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { L10n } from '../../../../../Foundation/L10n/L10n';

/**
 * 对标 iOS AddCustomProviderSheet（APIKeysSettingsView.swift）。
 * 字段：供应商名称 / API Key / 请求地址；工具栏取消 + 保存；可作 bindSheet 内容。
 */
@Component
export struct AddCustomProviderSheet {
  onClose: () => void = () => {
  };
  onSaved: () => void = () => {
  };

  @State private name: string = '';
  /** 勿命名为 key：与 CustomComponent.key 冲突 */
  @State private apiKey: string = '';
  @State private requestURL: string = '';
  @State private errorMessage: string = '';
  @State private submitting: boolean = false;
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
  }

  private isBasicInputFilled(): boolean {
    return this.name.trim().length > 0 &&
      this.apiKey.trim().length > 0 &&
      this.requestURL.trim().length > 0;
  }

  private shouldShowAppendPath(): boolean {
    const url = this.requestURL.trim();
    return url.length > 0 && !url.endsWith('/v1/chat/completions');
  }

  private appendCompletionPath(): void {
    let base = this.requestURL.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    this.requestURL = `${base}/v1/chat/completions`;
  }

  private validate(): boolean {
    const url = this.requestURL.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      this.errorMessage = L10n.getString(
        $r('app.string.ai_settings_providers_add_error_invalid_url_prefix'),
        '请求地址必须以 http:// 或 https:// 开头'
      );
      return false;
    }
    this.errorMessage = '';
    return true;
  }

  private async onSave(): Promise<void> {
    if (this.submitting || !this.isBasicInputFilled()) {
      return;
    }
    if (!this.validate()) {
      return;
    }
    this.submitting = true;
    this.errorMessage = '';
    try {
      const ok = await this.vm?.addCustomProviderAndPersist(
        this.name.trim(),
        this.apiKey.trim(),
        this.requestURL.trim()
      );
      if (ok) {
        this.onSaved();
        this.onClose();
      } else {
        const msg = this.vm?.errorMessage ?? '';
        this.errorMessage = msg.length > 0 ? msg : '保存失败';
        try {
          promptAction.showToast({ message: this.errorMessage, duration: 2000 });
        } catch (_e) {
          // ignore
        }
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : `${err}`;
      this.errorMessage = msg.length > 0 ? msg : '保存失败';
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  private navigationBar() {
    Row() {
      Text(L10n.getString($r('app.string.common_cancel'), '取消'))
        .fontSize(16)
        .fontColor(AISettingsUiTokens.textSecondary)
        .width(64)
        .padding({ top: 10, bottom: 10 })
        .onClick(() => {
          this.onClose();
        })

      Text(L10n.getString($r('app.string.ai_settings_providers_add_nav_title'), '新增自定义供应商'))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AISettingsUiTokens.textPrimary)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(L10n.getString($r('app.string.common_save'), '保存'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(
          this.isBasicInputFilled() && !this.submitting
            ? AISettingsUiTokens.accent
            : AISettingsUiTokens.textSecondary
        )
        .width(64)
        .textAlign(TextAlign.End)
        .padding({ top: 10, bottom: 10 })
        .opacity(this.isBasicInputFilled() && !this.submitting ? 1 : 0.45)
        .onClick(() => {
          if (this.isBasicInputFilled() && !this.submitting) {
            this.onSave();
          }
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
  }

  build() {
    Column() {
      this.navigationBar()

      Scroll() {
        Column() {
          Column() {
            TextInput({
              text: this.name,
              placeholder: L10n.getString(
                $r('app.string.ai_settings_providers_add_field_name'),
                '供应商名称'
              )
            })
              .height(44)
              .backgroundColor(Color.Transparent)
              .padding({ left: 16, right: 16 })
              .onChange((v: string) => {
                this.name = v;
              })

            Divider().color(AISettingsUiTokens.divider).margin({ left: 16 })

            TextInput({
              text: this.apiKey,
              placeholder: L10n.getString($r('app.string.ai_settings_provider_key'), 'API Key')
            })
              .type(InputType.Password)
              .height(44)
              .backgroundColor(Color.Transparent)
              .padding({ left: 16, right: 16 })
              .onChange((v: string) => {
                this.apiKey = v;
              })

            Divider().color(AISettingsUiTokens.divider).margin({ left: 16 })

            TextInput({
              text: this.requestURL,
              placeholder: L10n.getString(
                $r('app.string.ai_settings_providers_editor_field_request_url'),
                '请求地址'
              )
            })
              .height(44)
              .backgroundColor(Color.Transparent)
              .padding({ left: 16, right: 16 })
              .onChange((v: string) => {
                this.requestURL = v;
              })

            if (this.shouldShowAppendPath()) {
              Divider().color(AISettingsUiTokens.divider).margin({ left: 16 })
              Text(L10n.getString(
                $r('app.string.ai_settings_providers_add_action_append_completion_path'),
                '补全 /v1/chat/completions'
              ))
                .fontSize(13)
                .fontColor(AISettingsUiTokens.accent)
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .onClick(() => {
                  this.appendCompletionPath();
                })
            }
          }
          .width('100%')
          .backgroundColor(AISettingsUiTokens.cardBackground)
          .borderRadius(AISettingsUiTokens.cardRadius)
          .clip(true)

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(12)
              .fontColor(AISettingsUiTokens.error)
              .width('100%')
              .margin({ top: 12 })
          }

          Blank().height(24)
        }
        .width('100%')
        .padding({
          left: AISettingsUiTokens.pagePaddingH,
          right: AISettingsUiTokens.pagePaddingH,
          top: 8,
          bottom: 16
        })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }
}
