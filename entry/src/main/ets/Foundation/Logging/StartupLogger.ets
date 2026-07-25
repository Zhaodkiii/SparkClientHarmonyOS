import { LogModule } from './LogModule';
import { LogFields } from './LogEvent';
import { Logger } from './Logger';

/**
 * 启动与 Ability 生命周期结构化日志。
 */
export class StartupLogger {
  static abilityOnCreate(): void {
    Logger.info('ability.on_create', LogModule.LIFECYCLE);
  }

  static abilityOnDestroy(): void {
    Logger.info('ability.on_destroy', LogModule.LIFECYCLE);
  }

  static windowStageCreate(): void {
    Logger.info('ability.window_stage_create', LogModule.LIFECYCLE);
  }

  static windowStageDestroy(): void {
    Logger.info('ability.window_stage_destroy', LogModule.LIFECYCLE);
  }

  static windowContentLoaded(): void {
    Logger.info('ability.window_content_loaded', LogModule.LIFECYCLE);
  }

  static windowContentFailed(code?: number | string): void {
    const fields = new LogFields();
    if (code !== undefined) {
      fields.code = code;
    }
    Logger.error('ability.window_content_failed', LogModule.LIFECYCLE, fields);
  }

  static foreground(): void {
    Logger.info('ability.foreground', LogModule.LIFECYCLE);
  }

  static background(): void {
    Logger.info('ability.background', LogModule.LIFECYCLE);
  }

  static appContainerReady(): void {
    Logger.info('app.container_ready', LogModule.APP);
  }

  static appContainerFailed(detail?: string): void {
    const fields = new LogFields();
    if (detail) {
      fields.detail = detail;
    }
    Logger.error('app.container_failed', LogModule.APP, fields);
  }
}
