import { SparkToolName } from '../Models/SparkToolName';
import { ToolExecutionResult } from '../Models/ToolingModels';

/** 真实 Health Kit 适配器接入前的生产默认实现：明确不可用，绝不伪造健康数据。 */
export class HealthUnavailableExecutors {
  static run(tool: string): ToolExecutionResult {
    return ToolExecutionResult.make(
      tool,
      '鸿蒙端当前未接入真实健康数据能力，未读取或生成任何设备健康数据。',
      true,
      true,
      false
    );
  }

  static supports(tool: string): boolean {
    return tool === SparkToolName.FETCH_STEP_DETAILS ||
      tool === SparkToolName.FETCH_ENERGY_DETAILS ||
      tool === SparkToolName.FETCH_NUTRITION_DETAILS ||
      tool === SparkToolName.FETCH_SLEEP_DETAILS ||
      tool === SparkToolName.FETCH_WORKOUT_DETAILS ||
      tool === SparkToolName.MAKE_NUTRITION_DATA;
  }
}
