/** 检验一级 / 二级分类目录。对齐 iOS `LabExamCategoryTaxonomy`（中文落库）。 */
export class SparkLabCategoryGroup {
  primary: string = '';
  subcategories: string[] = [];

  constructor(primary: string, subcategories: string[]) {
    this.primary = primary;
    this.subcategories = subcategories.slice();
  }
}

export const SPARK_LAB_CATEGORY_GROUPS: SparkLabCategoryGroup[] = [
  new SparkLabCategoryGroup('血常规', ['全血细胞计数', '五分类血常规', '网织红细胞', '贫血三项']),
  new SparkLabCategoryGroup('尿常规', ['尿常规', '尿沉渣', '尿微量白蛋白', '24 小时尿蛋白']),
  new SparkLabCategoryGroup('生化全套', ['常规生化', '大生化', '小生化']),
  new SparkLabCategoryGroup('肝功能', ['肝功能常规', '肝功能全套', '胆红素', '转氨酶']),
  new SparkLabCategoryGroup('肾功能', ['肾功能常规', '肾小球滤过率', '尿酸', '肌酐清除率']),
  new SparkLabCategoryGroup('血脂', ['血脂常规', '血脂全套', '脂蛋白']),
  new SparkLabCategoryGroup('血糖', ['空腹血糖', '餐后 2 小时血糖', '糖化血红蛋白', '糖耐量试验']),
  new SparkLabCategoryGroup('电解质', ['钾钠氯', '钙磷镁', '血气分析']),
  new SparkLabCategoryGroup('心肌酶', ['心肌酶谱', '肌钙蛋白', '肌红蛋白', 'BNP/NT-proBNP']),
  new SparkLabCategoryGroup('淀粉酶', ['血淀粉酶', '尿淀粉酶', '脂肪酶']),
  new SparkLabCategoryGroup('凝血功能', ['凝血四项', 'D - 二聚体', '凝血全套']),
  new SparkLabCategoryGroup('免疫功能', ['免疫球蛋白', '补体', '淋巴细胞亚群']),
  new SparkLabCategoryGroup('甲状腺功能', ['甲功三项', '甲功五项', '甲功七项', '甲状腺抗体']),
  new SparkLabCategoryGroup('肿瘤标志物', ['广谱肿瘤标志物', '消化道肿瘤', '肺部肿瘤', '乳腺肿瘤', '前列腺肿瘤', '妇科肿瘤']),
  new SparkLabCategoryGroup('炎症指标', ['CRP', '血沉', '降钙素原 PCT', 'IL-6']),
  new SparkLabCategoryGroup('维生素', ['维生素 D', '维生素 B12', '叶酸', '维生素 ADEK']),
  new SparkLabCategoryGroup('激素', ['性激素', '生长激素', '皮质醇', '促肾上腺激素']),
  new SparkLabCategoryGroup('粪便常规', ['便常规', '便潜血', '寄生虫', '粪便培养']),
  new SparkLabCategoryGroup('分泌物检查', ['白带常规', '前列腺液', '精液常规', '分泌物培养']),
  new SparkLabCategoryGroup('其他检验', ['血型', '输血前检查', '过敏原', '幽门螺杆菌', '病毒检测'])
];

export class LabExamCategoryTaxonomy {
  static primaryPickerOptions(): string[] {
    const options: string[] = [];
    for (let i = 0; i < SPARK_LAB_CATEGORY_GROUPS.length; i++) {
      options.push(SPARK_LAB_CATEGORY_GROUPS[i].primary);
    }
    return options;
  }

  static resolvedCatalogPrimary(raw: string): string | undefined {
    const trimmed = raw.trim();
    if (trimmed.length === 0) {
      return undefined;
    }
    for (let i = 0; i < SPARK_LAB_CATEGORY_GROUPS.length; i++) {
      if (SPARK_LAB_CATEGORY_GROUPS[i].primary === trimmed) {
        return trimmed;
      }
    }
    return undefined;
  }

  static subcategories(primaryCN: string): string[] {
    for (let i = 0; i < SPARK_LAB_CATEGORY_GROUPS.length; i++) {
      const group = SPARK_LAB_CATEGORY_GROUPS[i];
      if (group.primary === primaryCN) {
        return group.subcategories.slice();
      }
    }
    return [];
  }

  static subcategoryPickerOptions(primaryStored: string): string[] {
    const primaryCN = LabExamCategoryTaxonomy.resolvedCatalogPrimary(primaryStored);
    if (primaryCN === undefined) {
      return [];
    }
    return LabExamCategoryTaxonomy.subcategories(primaryCN);
  }

  static defaultPrimary(): string {
    if (SPARK_LAB_CATEGORY_GROUPS.length === 0) {
      return '';
    }
    return SPARK_LAB_CATEGORY_GROUPS[0].primary;
  }

  static defaultSubcategory(primaryCN: string): string {
    const kids = LabExamCategoryTaxonomy.subcategories(primaryCN);
    if (kids.length === 0) {
      return '';
    }
    return kids[0];
  }

  static reconcileSecondary(primaryStored: string, secondaryStored: string): string {
    const primaryCN = LabExamCategoryTaxonomy.resolvedCatalogPrimary(primaryStored);
    if (primaryCN === undefined) {
      return '';
    }
    const kids = LabExamCategoryTaxonomy.subcategories(primaryCN);
    const secondary = secondaryStored.trim();
    if (secondary.length === 0) {
      return kids.length > 0 ? kids[0] : '';
    }
    for (let i = 0; i < kids.length; i++) {
      if (kids[i] === secondary) {
        return secondary;
      }
    }
    return kids.length > 0 ? kids[0] : '';
  }
}
