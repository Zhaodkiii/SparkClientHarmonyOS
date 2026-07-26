import { medicationIsSameDay, medicationStartOfDay } from './MedicationExecutionDateUtils';

export class MedicationExecutionSupport {
  static longDateTitle(date: Date): string {
    const month = date.getMonth() + 1;
    const day = date.getDate();
    if (medicationIsSameDay(date, new Date())) {
      return `${month}月${day}日 今天`;
    }
    const weekdays: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${month}月${day}日 ${weekdays[date.getDay()]}`;
  }

  static logTitleAtTime(timeText: string): string {
    return `记录于 ${timeText}`;
  }

  static allDrugsLogTitle(): string {
    return '全部药品';
  }

  static medicineBoxLogTitle(): string {
    return '药箱药品';
  }

  static startOfDay(date: Date): Date {
    return medicationStartOfDay(date);
  }
}
