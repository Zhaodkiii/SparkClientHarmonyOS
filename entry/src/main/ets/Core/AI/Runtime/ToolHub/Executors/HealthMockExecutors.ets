import { SparkToolName } from '../Models/SparkToolName';
import { ToolExecutionResult, ToolSideEffectRecord } from '../Models/ToolingModels';

/** 营养卡 mock 载荷（避免未声明类型的对象字面量）。 */
class MockNutritionCardPayload {
  id: string = '';
  proteinGrams: number = 0;
  carbohydratesGrams: number = 0;
  fatGrams: number = 0;
  energyKilocalories: number = 0;
  isWritten: boolean = false;
  mock: boolean = true;
}

class MockNutritionCardsEnvelope {
  cards: MockNutritionCardPayload[] = [];
}

class MockSleepPayload {
  averageHours: number = 0;
  deepHours: number = 0;
  remHours: number = 0;
  mock: boolean = true;
}

class MockWorkoutPayload {
  sessions: number = 0;
  mock: boolean = true;
}

/**
 * 鸿蒙阶段：系统健康数据不访问正式 Health Kit，统一返回示例数据。
 */
export class HealthMockExecutors {
  static runFetchSteps(args: Record<string, string>): ToolExecutionResult {
    const start = args['start_date'] ?? '2026-07-15';
    const end = args['end_date'] ?? '2026-07-21';
    const text =
      `【示例数据】步数统计 ${start} ~ ${end}\n` +
      `- 2026-07-15: 6234 步\n` +
      `- 2026-07-16: 8120 步\n` +
      `- 2026-07-17: 4510 步\n` +
      `- 2026-07-18: 9980 步\n` +
      `- 2026-07-19: 7302 步\n` +
      `- 2026-07-20: 5401 步\n` +
      `- 2026-07-21: 8800 步\n` +
      `合计约 50347 步（mock，非设备真实数据）。`;
    return ToolExecutionResult.make(SparkToolName.FETCH_STEP_DETAILS, text, true, true);
  }

  static runFetchEnergy(args: Record<string, string>): ToolExecutionResult {
    const start = args['start_date'] ?? '2026-07-15';
    const end = args['end_date'] ?? '2026-07-21';
    const text =
      `【示例数据】活动能量 ${start} ~ ${end}\n` +
      `日均活动消耗约 420 kcal，静息约 1450 kcal（mock）。`;
    return ToolExecutionResult.make(SparkToolName.FETCH_ENERGY_DETAILS, text, true, true);
  }

  static runFetchNutrition(args: Record<string, string>): ToolExecutionResult {
    const start = args['start_date'] ?? '2026-07-15';
    const end = args['end_date'] ?? '2026-07-21';
    const text =
      `【示例数据】营养摄入 ${start} ~ ${end}\n` +
      `蛋白质 72g / 碳水 210g / 脂肪 58g / 能量 1680 kcal（mock 日均）。`;
    return ToolExecutionResult.make(SparkToolName.FETCH_NUTRITION_DETAILS, text, true, true);
  }

  static runFetchSleep(args: Record<string, string>): ToolExecutionResult {
    const start = args['start_date'] ?? '2026-07-15';
    const end = args['end_date'] ?? '2026-07-21';
    const text =
      `【示例数据】睡眠 ${start} ~ ${end}\n` +
      `平均睡眠 7h12m，深睡约 1h40m，REM 约 1h20m（mock）。`;
    const payload = new MockSleepPayload();
    payload.averageHours = 7.2;
    payload.deepHours = 1.67;
    payload.remHours = 1.33;
    payload.mock = true;
    const side = new ToolSideEffectRecord();
    side.type = 'sleepVisualization';
    side.text = text;
    side.jsonPayload = JSON.stringify(payload);
    return ToolExecutionResult.make(SparkToolName.FETCH_SLEEP_DETAILS, text, true, true, false, [side]);
  }

  static runFetchWorkout(args: Record<string, string>): ToolExecutionResult {
    const start = args['start_date'] ?? '2026-07-15';
    const end = args['end_date'] ?? '2026-07-21';
    const text =
      `【示例数据】运动 ${start} ~ ${end}\n` +
      `1) 步行 42 分钟，消耗 180 kcal\n` +
      `2) 骑行 30 分钟，消耗 220 kcal（mock）。`;
    const payload = new MockWorkoutPayload();
    payload.sessions = 2;
    payload.mock = true;
    const side = new ToolSideEffectRecord();
    side.type = 'workoutVisualization';
    side.text = text;
    side.jsonPayload = JSON.stringify(payload);
    return ToolExecutionResult.make(SparkToolName.FETCH_WORKOUT_DETAILS, text, true, true, false, [side]);
  }

  static runMakeNutritionData(args: Record<string, string>): ToolExecutionResult {
    const protein = Number(args['protein'] ?? '20');
    const carbs = Number(args['carbohydrates'] ?? '40');
    const fat = Number(args['fat'] ?? '15');
    const energy = Number(args['energy'] ?? '380');
    const card = new MockNutritionCardPayload();
    card.id = `nutrition_mock_${Date.now()}`;
    card.proteinGrams = protein;
    card.carbohydratesGrams = carbs;
    card.fatGrams = fat;
    card.energyKilocalories = energy;
    card.isWritten = false;
    card.mock = true;
    const envelope = new MockNutritionCardsEnvelope();
    envelope.cards = [card];
    const text =
      `营养卡片已生成（示例）：蛋白 ${protein}g / 碳水 ${carbs}g / 脂肪 ${fat}g / 能量 ${energy} kcal。` +
      `请在消息内确认后写入健康应用（鸿蒙当前为 mock，不写系统健康库）。`;
    const side = new ToolSideEffectRecord();
    side.type = 'nutritionCards';
    side.jsonPayload = JSON.stringify(envelope);
    return ToolExecutionResult.make(
      SparkToolName.MAKE_NUTRITION_DATA,
      text,
      false,
      true,
      false,
      [side]
    );
  }
}
