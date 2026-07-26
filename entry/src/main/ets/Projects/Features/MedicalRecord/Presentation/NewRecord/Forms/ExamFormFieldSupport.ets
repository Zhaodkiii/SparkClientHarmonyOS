import { ExaminationReportDraftMapping } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDraftMapping';
import { LabExamCategoryTaxonomy } from './LabExamCategoryTaxonomy';

/** 检验常用单位。对齐 iOS `sparkLabCommonUnits` / `sparkLabMoreUnits`。 */
export const SPARK_LAB_COMMON_UNITS: string[] = [
  'g/L', '10^9/L', '10^12/L', '%', 'fL', 'pg', 'U/L', 'IU/L'
];

export const SPARK_LAB_MORE_UNITS: string[] = [
  'mmol/L', 'μmol/L', 'mg/L', 'ng/mL', 'pmol/L', 'mIU/L', 'IU/mL',
  'mmHg', '次/分', '℃', 'μg/L', 'nmol/L'
];

export const SPARK_LAB_FLAG_OPTIONS: string[] = [
  '正常', '偏高', '偏低', '异常', '↑', '↓', 'H', 'L'
];

const FORM_LABEL_COLOR: string = '#3C3C43';
const FORM_PLACEHOLDER_COLOR: string = '#AEAEB2';
const FORM_BORDER_COLOR: string = '#E5E5EA';
const FORM_FOCUS_COLOR: string = '#0A84FF';
const FORM_ERROR_COLOR: string = '#FF3B30';
const FORM_ACCENT_COLOR: string = '#0A84FF';
const FORM_PAGE_BG: string = '#F2F2F7';
const FORM_CARD_BG: string = '#FFFFFF';

@Component
struct ExamFormFieldLabel {
  @Prop label: string = '';
  @Prop required: boolean = false;
  @Prop titleIcon?: Resource = undefined;

  build() {
    Row({ space: 6 }) {
      if (this.titleIcon !== undefined) {
        SymbolGlyph(this.titleIcon)
          .fontSize(14)
          .fontColor([FORM_ACCENT_COLOR])
      }
      Text(this.label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(FORM_LABEL_COLOR)
      if (this.required) {
        Text('*')
          .fontSize(15)
          .fontColor(FORM_ERROR_COLOR)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

@Component
struct ExamFormFieldShell {
  @Prop isFocused: boolean = false;
  @Prop isError: boolean = false;
  @Prop minHeight: number = 44;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder
  defaultContent() {
  }

  build() {
    Row() {
      this.content()
    }
    .width('100%')
    .constraintSize({ minHeight: this.minHeight })
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(FORM_CARD_BG)
    .borderRadius(12)
    .border({
      width: this.isFocused || this.isError ? 1.5 : 1,
      color: this.isError ? FORM_ERROR_COLOR : (this.isFocused ? FORM_FOCUS_COLOR : FORM_BORDER_COLOR)
    })
    .shadow({
      radius: this.isFocused ? 8 : 4,
      color: this.isFocused ? '#1A000000' : '#14000000',
      offsetX: 0,
      offsetY: 2
    })
  }
}

/**
 * 表单卡片容器。对齐 iOS `SparkFormCard`：标题 + 蓝色图标 + 更大内边距。
 */
@Component
export struct ExamFormCard {
  @Prop title: string = '';
  @Prop titleIcon?: Resource = undefined;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder
  defaultContent() {
  }

  build() {
    Column({ space: 16 }) {
      if (this.title.length > 0) {
        ExamFormFieldLabel({
          label: this.title,
          titleIcon: this.titleIcon
        })
      }
      this.content()
    }
    .width('100%')
    .padding(16)
    .backgroundColor(FORM_CARD_BG)
    .borderRadius(16)
    .shadow({
      radius: 10,
      color: '#14000000',
      offsetX: 0,
      offsetY: 2
    })
  }
}

/** 嵌套分组卡片。对齐 iOS 检查类型内层 `SparkFormCard`。 */
@Component
export struct ExamFormInsetCard {
  @Prop title: string = '';
  @BuilderParam content: () => void = this.defaultContent;

  @Builder
  defaultContent() {
  }

  build() {
    Column({ space: 16 }) {
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(FORM_LABEL_COLOR)
          .width('100%')
      }
      this.content()
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#F9F9FB')
    .borderRadius(12)
    .border({ width: 1, color: '#EBEBF0' })
  }
}

@Component
export struct ExamFormDivider {
  @Prop verticalPadding: number = 8;

  build() {
    Divider()
      .color('#EBEBF0')
      .strokeWidth(0.5)
      .margin({ top: this.verticalPadding, bottom: this.verticalPadding })
  }
}

/**
 * 单行输入。对齐 iOS `SparkFormTextRow`：描边、聚焦高亮、必填校验边框。
 */
@Component
export struct ExamFormTextField {
  @Prop label: string = '';
  @Prop placeholder: string = '';
  @Prop required: boolean = false;
  @Link value: string;
  onKeyboardFocus?: (visible: boolean) => void;

  @State private isFocused: boolean = false;

  private showsError(): boolean {
    return this.required && this.value.trim().length === 0;
  }

  build() {
    Column({ space: 8 }) {
      ExamFormFieldLabel({
        label: this.label,
        required: this.required
      })

      ExamFormFieldShell({
        isFocused: this.isFocused,
        isError: this.showsError()
      }) {
        TextInput({
          text: this.value,
          placeholder: this.placeholder.length > 0 ? this.placeholder : this.label
        })
          .width('100%')
          .height(44)
          .fontSize(17)
          .fontColor('#1C1C1E')
          .placeholderColor(FORM_PLACEHOLDER_COLOR)
          .backgroundColor(Color.Transparent)
          .border({ width: 0 })
          .padding(0)
          .onChange((text: string) => {
            this.value = text;
          })
          .onFocus(() => {
            this.isFocused = true;
            if (this.onKeyboardFocus) {
              this.onKeyboardFocus(true);
            }
          })
          .onBlur(() => {
            this.isFocused = false;
            if (this.onKeyboardFocus) {
              this.onKeyboardFocus(false);
            }
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct ExamFormTextAreaField {
  @Prop label: string = '';
  @Prop placeholder: string = '';
  @Link value: string;
  onKeyboardFocus?: (visible: boolean) => void;

  @State private isFocused: boolean = false;

  build() {
    Column({ space: 8 }) {
      ExamFormFieldLabel({ label: this.label })
      ExamFormFieldShell({
        isFocused: this.isFocused,
        isError: false,
        minHeight: 96
      }) {
        TextArea({
          text: this.value,
          placeholder: this.placeholder.length > 0 ? this.placeholder : this.label
        })
          .width('100%')
          .height(88)
          .fontSize(17)
          .fontColor('#1C1C1E')
          .placeholderColor(FORM_PLACEHOLDER_COLOR)
          .backgroundColor(Color.Transparent)
          .border({ width: 0 })
          .padding(0)
          .onChange((text: string) => {
            this.value = text;
          })
          .onFocus(() => {
            this.isFocused = true;
            if (this.onKeyboardFocus) {
              this.onKeyboardFocus(true);
            }
          })
          .onBlur(() => {
            this.isFocused = false;
            if (this.onKeyboardFocus) {
              this.onKeyboardFocus(false);
            }
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * 紧凑日期行 + 系统日期弹窗。对齐 iOS `.datePickerStyle(.compact)` 单行控件。
 */
@Component
export struct ExamFormDateField {
  @Prop label: string = '';
  @Link examDay: Date;
  @Link dateText: string;

  private formattedDate(): string {
    if (this.dateText.trim().length > 0) {
      return this.dateText.trim();
    }
    return ExaminationReportDraftMapping.formatDate(this.examDay);
  }

  private openDatePicker(): void {
    DatePickerDialog.show({
      start: new Date('1970-1-1'),
      end: new Date('2100-12-31'),
      selected: this.examDay,
      lunar: false,
      onDateAccept: (value: Date) => {
        this.examDay = value;
        this.dateText = ExaminationReportDraftMapping.formatDate(value);
      }
    });
  }

  build() {
    Column({ space: 8 }) {
      ExamFormFieldLabel({ label: this.label })
      ExamFormFieldShell({ isFocused: false, isError: false }) {
        Row({ space: 8 }) {
          Text(this.formattedDate())
            .fontSize(17)
            .fontColor('#1C1C1E')
            .layoutWeight(1)
          SymbolGlyph($r('sys.symbol.calendar'))
            .fontSize(16)
            .fontColor(['#8E8E93'])
        }
        .width('100%')
        .onClick(() => {
          this.openDatePicker();
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** bindMenu 用的显式菜单项（ArkTS 禁止内联对象字面量）。 */
export class ExamFormBindMenuItem {
  value: string = '';
  action: () => void = () => {};

  constructor(value: string, action: () => void) {
    this.value = value;
    this.action = action;
  }
}

/** 菜单分组。对齐 iOS `SparkFormMenuCustomRow` sections。 */
export class ExamFormMenuSection {
  header: string = '';
  options: string[] = [];

  constructor(header: string, options: string[]) {
    this.header = header;
    this.options = options.slice();
  }
}

export function labFlagSymbolResource(flag: string): Resource | undefined {
  const text = flag.trim();
  if (text === '正常') {
    return $r('sys.symbol.checkmark_circle_fill');
  }
  if (text === '异常') {
    return $r('sys.symbol.exclamationmark_circle_fill');
  }
  return undefined;
}

/**
 * 带预设菜单 + 自定义输入的下拉行。对齐 iOS `SparkFormMenuCustomRow`。
 */
@Component
export struct ExamFormMenuCustomRow {
  @Prop label: string = '';
  @Prop required: boolean = false;
  @Prop sections: ExamFormMenuSection[] = [];
  @Prop customMenuTitle: string = '自定义';
  @Prop customPlaceholder: string = '请输入';
  @Prop placeholder: string = '';
  @Prop unselectedMenuTitle: string = '';
  @Prop showLeadingIcon: boolean = false;
  @Prop customAutofocus: boolean = false;
  @Link @Watch('onValueChanged') value: string;
  onKeyboardFocus?: (visible: boolean) => void;

  @State private useCustomInput: boolean = false;
  @State private isCustomFocused: boolean = false;
  @State private pendingCustomFocus: boolean = false;

  aboutToAppear(): void {
    this.syncCustomModeFromValue();
  }

  private onValueChanged(): void {
    this.syncCustomModeFromValue();
  }

  private syncCustomModeFromValue(): void {
    const trimmed = this.value.trim();
    if (trimmed.length === 0) {
      this.useCustomInput = false;
      return;
    }
    this.useCustomInput = !this.isPresetValue(trimmed);
  }

  private allPresetOptions(): string[] {
    const all: string[] = [];
    for (let i = 0; i < this.sections.length; i++) {
      const section = this.sections[i];
      for (let j = 0; j < section.options.length; j++) {
        all.push(section.options[j]);
      }
    }
    return all;
  }

  private isPresetValue(raw: string): boolean {
    const presets = this.allPresetOptions();
    for (let i = 0; i < presets.length; i++) {
      if (presets[i] === raw) {
        return true;
      }
    }
    return false;
  }

  private resolvedDisplayValue(): string {
    const trimmed = this.value.trim();
    if (trimmed.length > 0) {
      return trimmed;
    }
    if (this.placeholder.length > 0) {
      return this.placeholder;
    }
    return '请选择';
  }

  private isPlaceholder(): boolean {
    return this.value.trim().length === 0;
  }

  private bindMenuItems(): ExamFormBindMenuItem[] {
    const items: ExamFormBindMenuItem[] = [];
    const presets = this.allPresetOptions();
    for (let i = 0; i < presets.length; i++) {
      const option = presets[i];
      items.push(new ExamFormBindMenuItem(option, (): void => {
        this.value = option;
        this.useCustomInput = false;
      }));
    }
    if (this.unselectedMenuTitle.length > 0) {
      items.push(new ExamFormBindMenuItem(this.unselectedMenuTitle, (): void => {
        this.value = '';
        this.useCustomInput = false;
      }));
    }
    items.push(new ExamFormBindMenuItem(this.customMenuTitle, (): void => {
      this.useCustomInput = true;
      this.pendingCustomFocus = this.customAutofocus;
      if (this.value.trim().length === 0 || this.isPresetValue(this.value.trim())) {
        this.value = '';
      }
    }));
    return items;
  }

  private leadingIcon(): Resource | undefined {
    if (!this.showLeadingIcon || this.isPlaceholder()) {
      return undefined;
    }
    return labFlagSymbolResource(this.value);
  }

  @Builder
  private pickerRow() {
    ExamFormFieldShell({
      isFocused: false,
      isError: this.required && this.isPlaceholder()
    }) {
      Row({ space: 8 }) {
        if (this.leadingIcon() !== undefined) {
          SymbolGlyph(this.leadingIcon()!)
            .fontSize(16)
            .fontColor([FORM_ACCENT_COLOR])
        }
        Text(this.resolvedDisplayValue())
          .fontSize(17)
          .fontColor(this.isPlaceholder() ? FORM_PLACEHOLDER_COLOR : '#1C1C1E')
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(12)
          .fontColor(['#8E8E93'])
      }
      .width('100%')
    }
  }

  build() {
    Column({ space: 8 }) {
      ExamFormFieldLabel({
        label: this.label,
        required: this.required
      })
      Row({ space: 10 }) {
        Column() {
          this.pickerRow()
        }
        .layoutWeight(this.useCustomInput ? 0.42 : 1)
        .bindMenu(this.bindMenuItems())

        if (this.useCustomInput) {
          Column() {
            ExamFormFieldShell({
              isFocused: this.isCustomFocused,
              isError: this.required && this.value.trim().length === 0
            }) {
              TextInput({
                text: this.value,
                placeholder: this.customPlaceholder
              })
                .width('100%')
                .height(44)
                .fontSize(17)
                .fontColor('#1C1C1E')
                .placeholderColor(FORM_PLACEHOLDER_COLOR)
                .backgroundColor(Color.Transparent)
                .border({ width: 0 })
                .padding(0)
                .onChange((text: string) => {
                  this.value = text;
                })
                .defaultFocus(this.pendingCustomFocus)
                .onAppear(() => {
                  if (this.pendingCustomFocus) {
                    this.pendingCustomFocus = false;
                  }
                })
                .onFocus(() => {
                  this.isCustomFocused = true;
                  this.pendingCustomFocus = false;
                  if (this.onKeyboardFocus) {
                    this.onKeyboardFocus(true);
                  }
                })
                .onBlur(() => {
                  this.isCustomFocused = false;
                  if (this.onKeyboardFocus) {
                    this.onKeyboardFocus(false);
                  }
                })
            }
          }
          .layoutWeight(0.58)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** Sheet 顶部居中标题。对齐 iOS `navigationTitle`。 */
@Component
export struct ExamFormSheetHeader {
  @Prop title: string = '';

  build() {
    Column({ space: 0 }) {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ left: 20, right: 20, top: 8, bottom: 10 })
    }
    .width('100%')
  }
}

/** Scroll 内嵌大标题。对齐 iOS `.headline` 行。 */
@Component
export struct ExamFormInlineHeadline {
  @Prop title: string = '';

  build() {
    Text(this.title)
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor('#1C1C1E')
      .width('100%')
      .textAlign(TextAlign.Start)
      .padding({ bottom: 2 })
  }
}

/**
 * 菜单选择行。对齐 iOS `Picker(.menu)` / `SparkFormSheetPickerRow`。
 */
@Component
export struct ExamFormMenuPickerRow {
  @Prop label: string = '';
  @Prop displayValue: string = '';
  @Prop placeholder: string = '请选择';
  @Prop required: boolean = false;
  @Prop menuOptions: ExamFormBindMenuItem[] = [];

  private resolvedLabel(): string {
    return this.displayValue.trim().length > 0 ? this.displayValue.trim() : this.placeholder;
  }

  private isPlaceholder(): boolean {
    return this.displayValue.trim().length === 0;
  }

  private bindMenuItems(): ExamFormBindMenuItem[] {
    return this.menuOptions;
  }

  build() {
    Column({ space: 8 }) {
      if (this.label.length > 0) {
        ExamFormFieldLabel({
          label: this.label,
          required: this.required
        })
      }
      ExamFormFieldShell({
        isFocused: false,
        isError: this.required && this.isPlaceholder()
      }) {
        Row({ space: 8 }) {
          Text(this.resolvedLabel())
            .fontSize(17)
            .fontColor(this.isPlaceholder() ? FORM_PLACEHOLDER_COLOR : '#1C1C1E')
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(12)
            .fontColor(['#8E8E93'])
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .bindMenu(this.bindMenuItems())
  }
}

@Component
export struct SparkLabExamCategoryCascadeRow {
  @Prop primaryTitle: string = '默认一级分类';
  @Prop secondaryTitle: string = '默认二级分类';
  @Prop primaryPlaceholder: string = '如 血常规';
  @Prop secondaryPlaceholder: string = '如 肝功能（可选）';
  @Prop primaryRequired: boolean = true;
  @Prop secondaryRequired: boolean = false;
  @Link @Watch('onPrimaryChanged') primary: string;
  @Link secondary: string;
  onKeyboardFocus?: (visible: boolean) => void;

  @State private secondaryFieldKey: number = 0;

  aboutToAppear(): void {
    this.seedDefaultsIfNeeded();
    this.secondary = LabExamCategoryTaxonomy.reconcileSecondary(this.primary, this.secondary);
  }

  private onPrimaryChanged(): void {
    this.secondary = LabExamCategoryTaxonomy.reconcileSecondary(this.primary, this.secondary);
    this.secondaryFieldKey++;
  }

  private seedDefaultsIfNeeded(): void {
    if (!this.primaryRequired) {
      return;
    }
    if (this.primary.trim().length > 0) {
      return;
    }
    const defaultPrimary = LabExamCategoryTaxonomy.defaultPrimary();
    this.primary = defaultPrimary;
    if (this.secondary.trim().length === 0) {
      this.secondary = LabExamCategoryTaxonomy.defaultSubcategory(defaultPrimary);
    }
  }

  private primarySections(): ExamFormMenuSection[] {
    return [
      new ExamFormMenuSection('', LabExamCategoryTaxonomy.primaryPickerOptions())
    ];
  }

  private secondarySections(): ExamFormMenuSection[] {
    const options = LabExamCategoryTaxonomy.subcategoryPickerOptions(this.primary);
    if (options.length === 0) {
      return [];
    }
    return [
      new ExamFormMenuSection('', options)
    ];
  }

  private unselectedMenuTitle(): string {
    if (this.primaryRequired) {
      return '';
    }
    return '未选择';
  }

  build() {
    Column({ space: 16 }) {
      ExamFormMenuCustomRow({
        label: this.primaryTitle,
        required: this.primaryRequired,
        sections: this.primarySections(),
        customMenuTitle: '自定义',
        customPlaceholder: this.primaryPlaceholder,
        placeholder: this.primaryPlaceholder,
        unselectedMenuTitle: this.unselectedMenuTitle(),
        customAutofocus: true,
        value: $primary,
        onKeyboardFocus: (visible: boolean): void => {
          if (this.onKeyboardFocus) {
            this.onKeyboardFocus(visible);
          }
        }
      })

      ExamFormMenuCustomRow({
        label: this.secondaryTitle,
        required: this.secondaryRequired,
        sections: this.secondarySections(),
        customMenuTitle: '自定义',
        customPlaceholder: this.secondaryPlaceholder,
        placeholder: this.secondaryPlaceholder,
        unselectedMenuTitle: this.unselectedMenuTitle(),
        customAutofocus: true,
        value: $secondary,
        onKeyboardFocus: (visible: boolean): void => {
          if (this.onKeyboardFocus) {
            this.onKeyboardFocus(visible);
          }
        }
      })
        .key(`lab-sub-${this.secondaryFieldKey}`)
    }
    .width('100%')
  }
}

/**
 * 行内标题 + 当前值 + 下拉箭头。对齐 iOS 归属选择器 / `SparkFormSheetPickerRow` 单行形态。
 */
@Component
export struct ExamFormCompactMenuRow {
  @Prop leftTitle: string = '';
  @Prop displayValue: string = '';
  @Prop placeholder: string = '请选择';
  @Prop menuOptions: ExamFormBindMenuItem[] = [];

  private resolvedLabel(): string {
    return this.displayValue.trim().length > 0 ? this.displayValue.trim() : this.placeholder;
  }

  private isPlaceholder(): boolean {
    return this.displayValue.trim().length === 0;
  }

  build() {
    Column() {
      ExamFormFieldShell({ isFocused: false, isError: false }) {
        Row({ space: 8 }) {
          Text(this.leftTitle)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(FORM_LABEL_COLOR)
          Blank()
          Text(this.resolvedLabel())
            .fontSize(17)
            .fontColor(this.isPlaceholder() ? FORM_PLACEHOLDER_COLOR : '#1C1C1E')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(11)
            .fontColor(['#C7C7CC'])
        }
        .width('100%')
      }
    }
    .width('100%')
    .bindMenu(this.menuOptions)
  }
}

/**
 * 点击后打开 Sheet 的选择行。对齐 iOS `SparkFormSheetPickerRow`。
 */
@Component
export struct ExamFormSheetPickerRow {
  @Prop label: string = '';
  @Prop displayValue: string = '';
  @Prop placeholder: string = '请选择';
  @Prop required: boolean = false;
  onTap?: () => void;

  private resolvedLabel(): string {
    return this.displayValue.trim().length > 0 ? this.displayValue.trim() : this.placeholder;
  }

  private isPlaceholder(): boolean {
    return this.displayValue.trim().length === 0;
  }

  build() {
    Column({ space: 8 }) {
      if (this.label.length > 0) {
        ExamFormFieldLabel({
          label: this.label,
          required: this.required
        })
      }
      ExamFormFieldShell({
        isFocused: false,
        isError: this.required && this.isPlaceholder()
      }) {
        Row({ space: 8 }) {
          Text(this.resolvedLabel())
            .fontSize(17)
            .fontColor(this.isPlaceholder() ? FORM_PLACEHOLDER_COLOR : '#1C1C1E')
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(12)
            .fontColor(['#8E8E93'])
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      if (this.onTap) {
        this.onTap();
      }
    })
  }
}

/** 行内开关。对齐 iOS 表单中的 `Toggle` 设置项。 */
@Component
export struct ExamFormToggleRow {
  @Prop label: string = '';
  @Link isOn: boolean;

  build() {
    Row() {
      Text(this.label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(FORM_LABEL_COLOR)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .onChange((value: boolean) => {
          this.isOn = value;
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 44 })
    .alignItems(VerticalAlign.Center)
  }
}

/** 轻量次级操作按钮。对齐 iOS bordered + plus 图标。 */
@Component
export struct ExamFormAddItemButton {
  @Prop label: string = '添加项目';
  onTap?: () => void;

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.plus_circle_fill'))
          .fontSize(16)
          .fontColor([FORM_ACCENT_COLOR])
        Text(this.label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(FORM_ACCENT_COLOR)
      }
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(40)
    .backgroundColor(FORM_CARD_BG)
    .borderRadius(12)
    .border({ width: 1, color: '#D6E8FF' })
    .onClick(() => {
      if (this.onTap) {
        this.onTap();
      }
    })
  }
}

@Component
export struct ExamFormBottomBar {
  @Prop canSubmit: boolean = true;
  @Prop saveTitle: string = '保存';
  @Prop keyboardVisible: boolean = false;
  onCancel?: () => void;
  onSave?: () => void;
  onKeyboardDone?: () => void;

  build() {
    Column() {
      if (this.keyboardVisible) {
        Row() {
          Blank()
          Button('完成')
            .fontSize(16)
            .fontColor(FORM_ACCENT_COLOR)
            .backgroundColor('#F2F2F7')
            .borderRadius(16)
            .height(34)
            .padding({ left: 14, right: 14 })
            .onClick(() => {
              if (this.onKeyboardDone) {
                this.onKeyboardDone();
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      } else {
        Row({ space: 12 }) {
          Button('取消')
            .layoutWeight(1)
            .height(44)
            .fontSize(17)
            .fontColor('#1C1C1E')
            .backgroundColor('#F2F2F7')
            .borderRadius(14)
            .border({ width: 1, color: '#E5E5EA' })
            .onClick(() => {
              if (this.onCancel) {
                this.onCancel();
              }
            })
          Button(this.saveTitle)
            .layoutWeight(1)
            .height(44)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor(this.canSubmit ? FORM_ACCENT_COLOR : '#C7C7CC')
            .borderRadius(14)
            .enabled(this.canSubmit)
            .onClick(() => {
              if (this.canSubmit && this.onSave) {
                this.onSave();
              }
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#F9F9FB')
        .borderRadius(16)
        .border({ width: 1, color: '#EBEBF0' })
        .shadow({
          radius: 10,
          color: '#1F000000',
          offsetX: 0,
          offsetY: 4
        })
        .margin({ left: 16, right: 16, top: 8, bottom: 12 })
      }
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
  }
}

export const EXAM_FORM_PAGE_BACKGROUND: string = FORM_PAGE_BG;
