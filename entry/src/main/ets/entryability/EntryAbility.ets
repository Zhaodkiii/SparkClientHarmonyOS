import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppContainer } from '../App/AppContainer';
import { StartupLogger } from '../Foundation/Logging/StartupLogger';
import { ErrorLogger } from '../Foundation/Logging/ErrorLogger';
import { LogModule } from '../Foundation/Logging/LogModule';
import { LogFields } from '../Foundation/Logging/LogEvent';
import { L10n } from '../Foundation/L10n/L10n';
import { AIProviderDisplayNameResolver } from '../Core/AI/Presentation/AIProviderDisplayNameResolver';
import { AIPromptL10n } from '../Core/AI/Runtime/AIPromptL10n';
import { ChatSystemPromptResolver } from '../Core/AI/Runtime/ChatSystemPromptResolver';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      ErrorLogger.log('ability.color_mode_failed', LogModule.LIFECYCLE, err as Object);
    }
    try {
      L10n.bindContext(this.context);
      AIProviderDisplayNameResolver.bindContext(this.context);
      AIPromptL10n.bindContext(this.context);
      ChatSystemPromptResolver.bindContext(this.context);
      AppContainer.live(this.context);
    } catch (err) {
      const fields = new LogFields();
      fields.detail = ErrorLogger.summarize(err as Object);
      StartupLogger.appContainerFailed(fields.detail);
    }
    StartupLogger.abilityOnCreate();
  }

  onDestroy(): void {
    const container = AppContainer.shared();
    if (container) {
      container.shutdown();
    }
    StartupLogger.abilityOnDestroy();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    StartupLogger.windowStageCreate();

    // 全屏 ContentCover 会从屏幕顶部开始布局，保存系统状态栏避让高度，
    // 供详情页等全屏页面把顶部操作栏下移到安全区域内。
    const mainWindow = windowStage.getMainWindowSync();
    const updateTopAvoidArea = (): void => {
      const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      AppStorage.setOrCreate('topRectHeight', avoidArea.topRect.height);
    };
    updateTopAvoidArea();
    mainWindow.on('avoidAreaChange', updateTopAvoidArea);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        StartupLogger.windowContentFailed(err.code);
        return;
      }
      StartupLogger.windowContentLoaded();
    });
  }

  onWindowStageDestroy(): void {
    StartupLogger.windowStageDestroy();
  }

  onForeground(): void {
    StartupLogger.foreground();
    AppContainer.shared()?.lifecycle.onForeground();
  }

  onBackground(): void {
    StartupLogger.background();
  }
}
