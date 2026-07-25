import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';

/**
 * 本地医疗文档分类引擎 — 对齐 iOS LocalMedicalDocumentClassifier
 * 与参考包 MedicalDocumentClassifier.ets。
 *
 * ArkTS 不支持 Swift「协议携带静态成员」，改用「配置对象 + 纯函数」。
 * 本文件只做六类加权打分，不负责 manual / AI 编排。
 */

/** 加权特征：一组关键词 + 对应权重 */
class WeightedFeature {
  terms: string[] = [];
  weight: number = 0;
}

function makeFeature(terms: string[], weight: number): WeightedFeature {
  const feature = new WeightedFeature();
  feature.terms = terms;
  feature.weight = weight;
  return feature;
}

/** 单个检测器的匹配结果 */
export class MedicalDocumentClassifierMatchResult {
  kind: MedicalDocumentKind = MedicalDocumentKind.MEDICAL_REPORT;
  isMatch: boolean = false;
  confidence: number = 0;
}

/** 检测器配置：阈值 + 加权特征 + 额外加/减分规则 */
class DetectorConfig {
  kind: MedicalDocumentKind = MedicalDocumentKind.MEDICAL_REPORT;
  threshold: number = 30;
  weightedFeatures: WeightedFeature[] = [];
  additionalScoring: (text: string) => number = (_text: string): number => 0;
}

function hasCaseHistoryStructure(text: string): boolean {
  return (text.indexOf('主诉') >= 0 && text.indexOf('现病史') >= 0) ||
    (text.indexOf('chief complaint') >= 0 && text.indexOf('history of present illness') >= 0) ||
    (text.indexOf('chief complaint') >= 0 && text.indexOf('assessment and plan') >= 0);
}

function hasMedicinePackageStructure(text: string): boolean {
  return text.indexOf('批准文号') >= 0 || text.indexOf('国药准字') >= 0 ||
    text.indexOf('生产批号') >= 0 || text.indexOf('有效期至') >= 0 ||
    text.indexOf('lot number') >= 0 || text.indexOf('batch number') >= 0 ||
    text.indexOf('ndc') >= 0 || text.indexOf('expiration date') >= 0;
}

function containsAny(text: string, terms: string[]): boolean {
  for (let i = 0; i < terms.length; i++) {
    if (text.indexOf(terms[i]) >= 0) {
      return true;
    }
  }
  return false;
}

function baseDetect(text: string, config: DetectorConfig): MedicalDocumentClassifierMatchResult {
  let score = 0;

  // A. 显式权重特征：标题/结构性字段权重大，普通医学词权重小。
  for (let i = 0; i < config.weightedFeatures.length; i++) {
    const feature = config.weightedFeatures[i];
    let matchedCount = 0;
    for (let j = 0; j < feature.terms.length; j++) {
      if (text.indexOf(feature.terms[j].toLowerCase()) >= 0) {
        matchedCount += 1;
      }
    }
    if (matchedCount > 0) {
      score += Math.min(matchedCount, 3) * feature.weight;
    }
  }

  // B. 结构化加分/互斥扣分
  score += config.additionalScoring(text);

  const confidence = Math.min(100, Math.max(0, score));
  const result = new MedicalDocumentClassifierMatchResult();
  result.kind = config.kind;
  result.isMatch = confidence >= config.threshold;
  result.confidence = confidence;
  return result;
}

// MARK: - 1) 检查/检验报告

function buildMedicalReportConfig(): DetectorConfig {
  const config = new DetectorConfig();
  config.kind = MedicalDocumentKind.MEDICAL_REPORT;
  config.threshold = 30;
  config.weightedFeatures = [
    makeFeature([
      '诊断报告单', '检查报告单', '检验报告单', '检验报告', '检测报告',
      '影像诊断', '病理诊断', '彩超检查', 'radiology report', 'diagnostic report',
      'imaging report', 'ultrasound report', 'ct report', 'mri report',
      'pathology report', 'laboratory report', 'lab report', 'test report'
    ], 18),
    makeFeature([
      '影像表现', '诊断意见', '检查所见', '超声描述', '超声提示',
      '镜下所见', '肉眼所见', '标本类型', '标本号', '条码号',
      'findings', 'impression', 'conclusion', 'specimen type', 'specimen id',
      'accession number', 'clinical indication', 'technique'
    ], 10),
    makeFeature([
      '检查项目', '检测项目', '检查部位', '报告医生', '审核医生',
      '检验者', '申请医生', '送检医生', '临床检验',
      'exam', 'procedure', 'body part', 'reported by', 'verified by',
      'ordering physician', 'referring physician', 'collected', 'resulted'
    ], 6),
    makeFeature([
      'ct', 'mri', 'b超', '超声', 'x-ray', 'xray', 'ultrasound', 'radiograph',
      '回声', '结节', '肿块', '占位', '病灶', 'nodule', 'mass', 'lesion',
      'opacity', 'density', 'calcification'
    ], 3)
  ];
  config.additionalScoring = (text: string): number => {
    let extra = 0;
    if ((text.indexOf('影像表现') >= 0 || text.indexOf('检查所见') >= 0) &&
      text.indexOf('诊断意见') >= 0) {
      extra += 20;
    }
    if (containsAny(text, ['ti-rads', 'bi-rads', 'li-rads', 'pi-rads', 'lung-rads'])) {
      extra += 25;
    }
    if (text.indexOf('结果') >= 0 && text.indexOf('参考区间') >= 0 && text.indexOf('单位') >= 0) {
      extra += 25;
    }
    if (text.indexOf('result') >= 0 &&
      (text.indexOf('reference range') >= 0 || text.indexOf('normal range') >= 0) &&
      text.indexOf('unit') >= 0) {
      extra += 25;
    }
    if (text.indexOf('检验互认项目') >= 0 || text.indexOf('质评合格') >= 0) {
      extra += 15;
    }
    if (containsAny(text, ['处方笺', '处方单', 'prescription', 'rx'])) {
      if (text.indexOf('检查') < 0 && text.indexOf('诊断') < 0 && text.indexOf('report') < 0) {
        extra -= 15;
      }
    }
    if (hasCaseHistoryStructure(text)) {
      extra -= 20;
    }
    return extra;
  };
  return config;
}

// MARK: - 2) 病历

function buildCaseDocumentConfig(): DetectorConfig {
  const config = new DetectorConfig();
  config.kind = MedicalDocumentKind.CASE_DOCUMENT;
  config.threshold = 30;
  config.weightedFeatures = [
    makeFeature([
      '门诊病历', '住院病历', '急诊病历', '入院记录', '出院记录', '出院小结',
      '病程记录', 'medical record', 'clinical record', 'visit note',
      'progress note', 'discharge summary', 'admission note', 'emergency record'
    ], 18),
    makeFeature([
      '主诉', '现病史', '既往史', '个人史', '家族史', '体格检查',
      'chief complaint', 'history of present illness', 'hpi', 'past medical history',
      'pmh', 'review of systems', 'physical examination', 'family history'
    ], 12),
    makeFeature([
      '初步诊断', '处理意见', '出院诊断', '入院诊断', '治疗经过', '出院医嘱',
      'assessment and plan', 'assessment/plan', 'plan', 'hospital course',
      'discharge diagnosis', 'admission diagnosis'
    ], 8),
    makeFeature([
      '辅助检查', '过敏史', '入院日期', '出院日期', '住院号', '医师签名', '门诊号',
      '症状', '体征', '随访', '医嘱', '复诊', '诊断', '治疗',
      'allergies', 'mrn', 'medical record number', 'encounter', 'follow-up',
      'symptom', 'diagnosis', 'treatment'
    ], 4)
  ];
  config.additionalScoring = (text: string): number => {
    let extra = 0;
    if (text.indexOf('病历') >= 0 && (text.indexOf('门诊') >= 0 || text.indexOf('急诊') >= 0)) {
      extra += 50;
    }
    if (text.indexOf('medical record') >= 0 &&
      (text.indexOf('visit') >= 0 || text.indexOf('encounter') >= 0)) {
      extra += 30;
    }
    if (hasCaseHistoryStructure(text)) {
      extra += 20;
    }
    if (text.indexOf('影像诊断') >= 0 || text.indexOf('诊断意见') >= 0) {
      if (text.indexOf('初步诊断') < 0 && text.indexOf('处理意见') < 0) {
        extra -= 15;
      }
    }
    return extra;
  };
  return config;
}

// MARK: - 3) 处方

function buildPrescriptionConfig(): DetectorConfig {
  const config = new DetectorConfig();
  config.kind = MedicalDocumentKind.PRESCRIPTION;
  config.threshold = 30;
  config.weightedFeatures = [
    makeFeature([
      '处方笺', '处方单', '门诊处方', '电子处方', 'prescription', 'prescription form',
      'rx', 'e-prescription', 'outpatient prescription'
    ], 18),
    makeFeature([
      '处方号', '处方编号', '开方日期', '发药清单', '审核', '调配', '发药',
      '医师签名', '药师签名', 'prescription no', 'rx number', 'date prescribed',
      'dispense', 'dispensed', 'pharmacist', 'prescriber', 'refills'
    ], 12),
    makeFeature([
      '药品名称', '用法', '用量', '频次', '每次', '每日', 'sig', 'directions',
      'dosage', 'dose', 'route', 'frequency', 'take', 'inject', 'apply'
    ], 8),
    makeFeature([
      'tid', 'bid', 'qd', 'qn', 'qhs', 'prn', 'po', 'iv', 'ivgtt', 'im',
      '片', '粒', '支', '瓶', '盒', 'mg', 'ml', 'tablet', 'capsule', 'cap', 'tab'
    ], 4)
  ];
  config.additionalScoring = (text: string): number => {
    let extra = 0;
    if (containsAny(text, ['处方', 'rp', 'rx', 'prescription']) &&
      containsAny(text, ['用法', 'sig', 'directions'])) {
      extra += 20;
    }
    if (hasCaseHistoryStructure(text)) {
      extra -= 20;
    }
    if (text.indexOf('检查所见') >= 0 || text.indexOf('影像诊断') >= 0) {
      if (text.indexOf('处方') < 0 && text.indexOf('用药') < 0) {
        extra -= 15;
      }
    }
    if (hasMedicinePackageStructure(text) &&
      text.indexOf('处方') < 0 && text.indexOf('prescription') < 0) {
      extra -= 20;
    }
    return extra;
  };
  return config;
}

// MARK: - 4) 体检报告

function buildHealthExamConfig(): DetectorConfig {
  const config = new DetectorConfig();
  config.kind = MedicalDocumentKind.HEALTH_EXAM_REPORT;
  config.threshold = 30;
  config.weightedFeatures = [
    makeFeature([
      '体检报告', '健康体检', '体检中心', '体检结论', '体检建议', '体检日期', '体检编号',
      'health examination report', 'health check report', 'annual physical',
      'executive health check', 'wellness report', 'preventive screening'
    ], 18),
    makeFeature([
      '总检结论', '总结建议', '体检套餐', '体检项目表', '一般检查', '内科检查', '外科检查',
      'summary recommendation', 'health summary', 'exam package', 'screening package',
      'general examination', 'physical examination'
    ], 10),
    makeFeature([
      '参考范围', '正常范围', '总胆固醇', '甘油三酯', '血红蛋白', '尿素氮',
      '身高', '体重', '血压', 'bmi', 'reference range', 'normal range',
      'cholesterol', 'triglycerides', 'hemoglobin', 'blood pressure', 'body mass index'
    ], 5),
    makeFeature([
      '偏高', '偏低', '建议', '复查', '进一步检查', '定期体检',
      'high', 'low', 'abnormal', 'follow up', 'recheck', 'recommendation'
    ], 3)
  ];
  config.additionalScoring = (text: string): number => {
    let extra = 0;
    if (text.length > 5000) {
      extra += 10;
    } else if (text.length > 2000) {
      extra += 5;
    }
    if (text.indexOf('总结建议') >= 0 && text.indexOf('体检中心') >= 0) {
      extra += 20;
    }
    if (text.indexOf('summary recommendation') >= 0 &&
      (text.indexOf('health check') >= 0 || text.indexOf('physical exam') >= 0)) {
      extra += 20;
    }
    if (text.indexOf('健康体检') >= 0 || text.indexOf('导读') >= 0) {
      extra += 10;
    }
    if (text.indexOf('health check') >= 0 || text.indexOf('annual physical') >= 0) {
      extra += 10;
    }
    if (text.indexOf('主诉') >= 0 || text.indexOf('现病史') >= 0 ||
      text.indexOf('chief complaint') >= 0) {
      extra -= 20;
    }
    if (text.indexOf('影像表现') >= 0 && text.indexOf('诊断意见') >= 0) {
      extra -= 15;
    }
    return extra;
  };
  return config;
}

// MARK: - 5) 用药计划

function buildMedicationPlanConfig(): DetectorConfig {
  const config = new DetectorConfig();
  config.kind = MedicalDocumentKind.MEDICATION_PLAN;
  config.threshold = 32;
  config.weightedFeatures = [
    makeFeature([
      '用药计划', '服药计划', '用药方案', '服药提醒', '药物治疗方案',
      'medication plan', 'medicine schedule', 'drug schedule', 'medication schedule',
      'treatment plan', 'medication regimen'
    ], 18),
    makeFeature([
      '开始日期', '结束日期', '长期服用', '提醒时间', '服药时间', '疗程',
      'start date', 'end date', 'duration', 'course', 'reminder time',
      'take at', 'morning', 'evening', 'bedtime'
    ], 12),
    makeFeature([
      '每日', '每周', '每隔', '饭前', '饭后', '睡前', '每次', '一次',
      'daily', 'weekly', 'every other day', 'before meals', 'after meals',
      'with food', 'at bedtime', 'once daily', 'twice daily'
    ], 8),
    makeFeature([
      '药品名称', '剂型', '规格', '剂量', 'mg', 'ml', 'tablet', 'capsule',
      'strength', 'dose', 'dosage form', 'instructions'
    ], 4)
  ];
  config.additionalScoring = (text: string): number => {
    let extra = 0;
    if (containsAny(text, ['用药计划', 'medication plan', 'medication schedule']) &&
      containsAny(text, ['开始', 'start date', 'reminder'])) {
      extra += 25;
    }
    if ((text.indexOf('reminder') >= 0 || text.indexOf('提醒') >= 0) &&
      (text.indexOf('daily') >= 0 || text.indexOf('每日') >= 0)) {
      extra += 15;
    }
    if (containsAny(text, ['处方笺', '处方单', 'prescription no', 'rx number'])) {
      extra -= 18;
    }
    if (hasMedicinePackageStructure(text)) {
      extra -= 15;
    }
    return extra;
  };
  return config;
}

// MARK: - 6) 药品/药盒包装

function buildMedicineBoxConfig(): DetectorConfig {
  const config = new DetectorConfig();
  config.kind = MedicalDocumentKind.MEDICINE_BOX;
  config.threshold = 32;
  config.weightedFeatures = [
    makeFeature([
      '药盒', '药品包装', '药瓶', '药品标签', '说明书', '外包装',
      'medicine box', 'drug package', 'medication package', 'pill bottle',
      'package label', 'drug label', 'patient information leaflet'
    ], 18),
    makeFeature([
      '国药准字', '批准文号', '生产批号', '产品批号', '有效期至', '生产日期',
      'manufacturer', 'lot number', 'batch number', 'expiry date', 'expiration date',
      'exp.', 'ndc', 'rx only', 'store at'
    ], 12),
    makeFeature([
      '通用名称', '商品名称', '成份', '性状', '适应症', '禁忌', '不良反应',
      'generic name', 'brand name', 'active ingredient', 'indications',
      'contraindications', 'side effects', 'warnings'
    ], 8),
    makeFeature([
      '规格', '剂型', '贮藏', '每盒', '片/盒', '粒/盒', 'capsules', 'tablets',
      'strength', 'dosage form', 'storage', 'keep out of reach'
    ], 4)
  ];
  config.additionalScoring = (text: string): number => {
    let extra = 0;
    if (hasMedicinePackageStructure(text)) {
      extra += 25;
    }
    if ((text.indexOf('国药准字') >= 0 || text.indexOf('ndc') >= 0) &&
      (text.indexOf('有效期') >= 0 || text.indexOf('expiration') >= 0)) {
      extra += 20;
    }
    if (containsAny(text, ['处方号', 'prescription no', 'rx number'])) {
      extra -= 25;
    }
    if (containsAny(text, ['开始日期', 'reminder time', '服药提醒'])) {
      extra -= 18;
    }
    return extra;
  };
  return config;
}

/**
 * 对齐 iOS `LocalMedicalDocumentClassifier`。
 * 对外只暴露 classify；规则命中阈值由调用方（Resolver）解释。
 */
export class MedicalDocumentClassifier {
  private static readonly configs: DetectorConfig[] = [
    buildCaseDocumentConfig(),
    buildPrescriptionConfig(),
    buildHealthExamConfig(),
    buildMedicalReportConfig(),
    buildMedicationPlanConfig(),
    buildMedicineBoxConfig()
  ];

  static classify(text: string): MedicalDocumentClassifierMatchResult[] {
    const input = text.toLowerCase();
    const results: MedicalDocumentClassifierMatchResult[] = [];
    for (let i = 0; i < MedicalDocumentClassifier.configs.length; i++) {
      results.push(baseDetect(input, MedicalDocumentClassifier.configs[i]));
    }
    return results;
  }

  /** 调试：输出 kind:score 列表。 */
  static debugScores(text: string): string {
    const results = MedicalDocumentClassifier.classify(text);
    const parts: string[] = [];
    for (let i = 0; i < results.length; i++) {
      parts.push(`${results[i].kind}:${results[i].confidence}`);
    }
    return parts.join(', ');
  }
}

/** 兼容参考包命名。 */
export class LocalMedicalDocumentClassifier {
  static classify(text: string): MedicalDocumentClassifierMatchResult[] {
    return MedicalDocumentClassifier.classify(text);
  }
}
