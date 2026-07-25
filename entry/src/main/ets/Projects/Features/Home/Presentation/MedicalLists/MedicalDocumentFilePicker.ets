import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { MedicalAttachmentInput } from './MedicalDocumentAttachmentUploader';

/**
 * 医疗文档公共文件选择器。
 *
 * 对齐 iOS `MedicalDocumentFilePickerMenu`：
 * - 相册入口只选择图片；
 * - 文件入口只选择图片/PDF；
 * - 所有入口统一返回 `MedicalAttachmentInput`，调用方不感知系统 picker。
 */
export class MedicalDocumentFilePicker {
  static readonly DEFAULT_MAX_SELECTION_COUNT: number = 10;

  static async pickImages(
    context: common.UIAbilityContext,
    maxSelectionCount: number = MedicalDocumentFilePicker.DEFAULT_MAX_SELECTION_COUNT
  ): Promise<MedicalAttachmentInput[]> {
    const viewPicker = new picker.PhotoViewPicker(context);
    const options = new picker.PhotoSelectOptions();
    options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = MedicalDocumentFilePicker.limit(maxSelectionCount);
    const result = await viewPicker.select(options);
    return result.photoUris.map((uri: string): MedicalAttachmentInput =>
      MedicalDocumentFilePicker.make(uri, 'image/*'));
  }

  static async pickPDFs(
    context: common.UIAbilityContext,
    maxSelectionCount: number = MedicalDocumentFilePicker.DEFAULT_MAX_SELECTION_COUNT
  ): Promise<MedicalAttachmentInput[]> {
    const viewPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = MedicalDocumentFilePicker.limit(maxSelectionCount);
    options.fileSuffixFilters = ['PDF|.pdf'];
    const uris = await viewPicker.select(options);
    return uris.map((uri: string): MedicalAttachmentInput =>
      MedicalDocumentFilePicker.make(uri, 'application/pdf'));
  }

  /** 文件管理器入口：允许从文件系统选择图片或 PDF。 */
  static async pickImagesAndPDFs(
    context: common.UIAbilityContext,
    maxSelectionCount: number = MedicalDocumentFilePicker.DEFAULT_MAX_SELECTION_COUNT
  ): Promise<MedicalAttachmentInput[]> {
    const viewPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = MedicalDocumentFilePicker.limit(maxSelectionCount);
    options.fileSuffixFilters = ['PDF|.pdf', '图片|.png,.jpg,.jpeg,.heic,.webp'];
    const uris = await viewPicker.select(options);
    return uris.map((uri: string): MedicalAttachmentInput =>
      MedicalDocumentFilePicker.make(uri, MedicalDocumentFilePicker.mimeType(uri)));
  }

  /** 保留旧调用方 API；“文件”入口现在严格限定为图片/PDF。 */
  static async pickDocuments(
    context: common.UIAbilityContext,
    maxSelectionCount: number = MedicalDocumentFilePicker.DEFAULT_MAX_SELECTION_COUNT
  ): Promise<MedicalAttachmentInput[]> {
    return MedicalDocumentFilePicker.pickImagesAndPDFs(context, maxSelectionCount);
  }

  private static make(uri: string, mimeType: string): MedicalAttachmentInput {
    const input = new MedicalAttachmentInput();
    input.previewId = `medical_pending_${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
    input.sourceUri = uri;
    input.originalName = MedicalDocumentFilePicker.fileName(uri);
    input.mimeType = mimeType;
    return input;
  }

  private static fileName(uri: string): string {
    const clean = uri.split('?')[0];
    const slash = clean.lastIndexOf('/');
    const value = slash >= 0 ? clean.substring(slash + 1) : clean;
    return value.length > 0 ? decodeURIComponent(value) : `attachment_${Date.now()}`;
  }

  private static mimeType(uri: string): string {
    const name = MedicalDocumentFilePicker.fileName(uri).toLowerCase();
    if (name.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (name.endsWith('.png')) {
      return 'image/png';
    }
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (name.endsWith('.heic')) {
      return 'image/heic';
    }
    if (name.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'application/octet-stream';
  }

  private static limit(value: number): number {
    return Math.max(1, Math.min(50, Math.floor(value)));
  }
}

/**
 * 医疗文档选择菜单，对齐 iOS `MedicalDocumentFilePickerMenu`。
 * 通过 `content` 自定义触发按钮，业务只接收统一的文件结果。
 */
@Component
export struct MedicalDocumentFilePickerMenu {
  @BuilderParam content: () => void = this.defaultContent;
  onFilesSelected: (files: MedicalAttachmentInput[]) => void = () => {};
  maxSelectionCount: number = MedicalDocumentFilePicker.DEFAULT_MAX_SELECTION_COUNT;
  disabled: boolean = false;

  @Builder
  private defaultContent() {
    Button('添加报告')
      .fontSize(13)
      .fontColor('#0A84FF')
      .backgroundColor('#F0F7FF')
      .borderRadius(8)
  }

  private async selectImages(): Promise<void> {
    if (this.disabled) {
      return;
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const files = await MedicalDocumentFilePicker.pickImages(context, this.maxSelectionCount);
      if (files.length > 0) {
        this.onFilesSelected(files);
      }
    } catch (_e) {
      // 取消选择不视为业务错误；调用方可通过自己的状态显示错误。
    }
  }

  private async selectImagesAndPDFs(): Promise<void> {
    if (this.disabled) {
      return;
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const files = await MedicalDocumentFilePicker.pickImagesAndPDFs(
        context,
        this.maxSelectionCount
      );
      if (files.length > 0) {
        this.onFilesSelected(files);
      }
    } catch (_e) {
      // 取消选择不视为业务错误。
    }
  }

  build() {
    Row() {
      this.content()
    }
    .opacity(this.disabled ? 0.5 : 1)
    .bindMenu([
      { value: '相册图片', action: () => { this.selectImages(); } },
      { value: '文件（图片/PDF）', action: () => { this.selectImagesAndPDFs(); } }
    ])
  }
}
