import { AIRuntimeResponse } from '../Domain/AIConfigModels';
import { Logger } from '../../../Foundation/Logging/Logger';
import { LogModule } from '../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../Foundation/Logging/LogEvent';
import { AIRuntimeRequestLogRedactor } from './AIRuntimeRequestLogRedactor';

export class AIRuntimeOutputLog {
  static recordFinalModelOutput(
    scenario: string,
    inferenceSource: string,
    response: AIRuntimeResponse,
    modelName: string
  ): void {
    const fields = new LogFields();
    fields.detail = AIRuntimeRequestLogRedactor.summarizeResponse(scenario, inferenceSource, response, modelName);
    Logger.info('ai.runtime.completed', LogModule.AI_CONFIG, fields);
  }
}
