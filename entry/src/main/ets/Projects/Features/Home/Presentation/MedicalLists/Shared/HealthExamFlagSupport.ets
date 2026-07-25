/**
 * 检验/体检 flag 异常启发式。对齐 iOS ExaminationReportDetailSupport.isPotentiallyAbnormal。
 */
export function isPotentiallyAbnormalFlag(flag: string): boolean {
  const normalized = flag.trim().toLowerCase();
  if (normalized.length === 0) {
    return false;
  }
  return normalized.indexOf('高') >= 0
    || normalized.indexOf('低') >= 0
    || normalized.indexOf('异常') >= 0
    || normalized.indexOf('阳性') >= 0
    || normalized.indexOf('abnormal') >= 0
    || normalized.indexOf('positive') >= 0
    || normalized.indexOf('high') >= 0
    || normalized.indexOf('low') >= 0
    || normalized.indexOf('↑') >= 0
    || normalized.indexOf('↓') >= 0;
}

/** 详情页风险分级。对齐 iOS MedicalReportItem.inferredRiskLevel。 */
export type HealthExamRiskLevel = 'high' | 'mid' | 'low' | 'normal';

export function inferredHealthExamRiskLevel(
  flag: string,
  diagnosis: string,
  resultValue: string,
  referenceRange: string
): HealthExamRiskLevel {
  const f = flag.trim().toLowerCase();
  if (f.length === 0
    || f === 'normal'
    || f === '阴性'
    || f === 'negative'
    || f === 'n'
    || f === '正常') {
    return 'normal';
  }
  const token = `${flag} ${diagnosis} ${resultValue} ${referenceRange}`.toLowerCase();
  if (token.indexOf('critical') >= 0
    || token.indexOf('危急') >= 0
    || token.indexOf('高危') >= 0
    || token.indexOf('+++') >= 0
    || token.indexOf('阳性') >= 0
    || token.indexOf('positive') >= 0
    || token.indexOf('high') >= 0
    || token.indexOf('↑') >= 0) {
    return 'high';
  }
  if (token.indexOf('abnormal') >= 0
    || token.indexOf('异常') >= 0
    || token.indexOf('偏高') >= 0
    || token.indexOf('偏低') >= 0
    || token.indexOf('++') >= 0
    || token.indexOf('+') >= 0) {
    return 'mid';
  }
  return 'low';
}

export function healthExamRiskTint(level: HealthExamRiskLevel): string {
  if (level === 'high') {
    return '#FF3B30';
  }
  if (level === 'mid') {
    return '#FF9500';
  }
  if (level === 'low') {
    return '#34C759';
  }
  return '#5AC8FA';
}

export function healthExamRiskTitle(level: HealthExamRiskLevel): string {
  if (level === 'high') {
    return '高风险';
  }
  if (level === 'mid') {
    return '中风险';
  }
  if (level === 'low') {
    return '低风险';
  }
  return '正常';
}

export function nonEmptyText(value?: string): string {
  if (!value) {
    return '';
  }
  const trimmed = value.trim();
  return trimmed;
}

export function formatExamDateText(examDate?: string): string {
  const raw = nonEmptyText(examDate);
  if (raw.length >= 10) {
    return raw.substring(0, 10).replace(/-/g, '/');
  }
  return raw;
}
