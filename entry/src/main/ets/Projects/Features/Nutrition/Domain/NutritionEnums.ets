/**
 * 对齐 iOS `NutritionMealType`（Projects/Features/Nutrition/Domain/NutritionEnums.swift）。
 */
export enum NutritionMealType {
  BREAKFAST = 'breakfast',
  LUNCH = 'lunch',
  DINNER = 'dinner',
  SNACK = 'snack'
}

/**
 * 对齐 iOS `mealType.localizationKey` 经 `L10n.text` 解析后的中/英文案。
 * Nutrition UI 字符串资源尚未迁移到 base/zh_CN/en_US，先内置双语兜底；
 * 迁移 Nutrition 功能时应改为 `$r('app.string.nutrition_meal_xxx')`。
 */
export function nutritionMealTypeLabel(mealType: NutritionMealType, isChinese: boolean): string {
  switch (mealType) {
    case NutritionMealType.BREAKFAST:
      return isChinese ? '早餐' : 'Breakfast';
    case NutritionMealType.LUNCH:
      return isChinese ? '午餐' : 'Lunch';
    case NutritionMealType.DINNER:
      return isChinese ? '晚餐' : 'Dinner';
    case NutritionMealType.SNACK:
      return isChinese ? '小吃' : 'Snack';
    default:
      return isChinese ? '未知餐次' : 'Unknown meal';
  }
}
