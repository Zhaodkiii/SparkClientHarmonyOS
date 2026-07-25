import { Member } from '../../../Core/Domain/Entities/Member';
import {
  FileTransferErrorLocalizer,
  FileTransferErrorPresentation,
  FileTransferUserAction
} from '../../../../Core/FileStorage/FileTransferErrorLocalizer';
import { FileTransferL10n } from '../../../../Core/FileStorage/FileTransferL10n';
import { FileTransferError } from '../../../../Core/FileStorage/FileStorageModels';
import { OSSErrorDecoder } from '../../../Core/OSS/OSSErrorDecoder';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogLevel } from '../../../../Foundation/Logging/LogLevel';
import { NotificationClient } from '../../../Core/Notification/Application/NotificationClient';
import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MemberContextStore } from '../../MemberContext/Presentation/MemberContextStore';
import { UploadMedicalDocumentFilesUseCase } from '../Application/UploadMedicalDocumentFilesUseCase';
import { MedicalDocumentOCRUseCase } from '../Application/MedicalDocumentOCRUseCase';
import { ResolveMedicalDocumentTypeUseCase } from '../Application/ResolveMedicalDocumentTypeUseCase';
import { ExtractTypedMedicalDocumentUseCase } from '../Application/ExtractTypedMedicalDocumentUseCase';
import { BindUploadedFilesToMedicalBusinessUseCase } from '../Application/BindUploadedFilesToMedicalBusinessUseCase';
import { SaveTypedMedicalDocumentUseCase } from '../Application/SaveTypedMedicalDocumentUseCase';
import { MedicalDocumentOCRRequest } from '../Domain/MedicalDocumentOCRModels';
import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import { MedicalDocumentSaveError } from '../Domain/TypedMedicalDocumentSaving';
import {
  MedicalDocumentAttachmentBusinessMatcher
} from '../Domain/MedicalDocumentAttachmentBusinessMatcher';
import { MedicalDocumentAttachmentBindingMapper } from '../Domain/MedicalDocumentAttachmentBindingMapper';
import {
  MedicalDocumentAttachmentMatchSummary,
  MedicalDocumentPreparedAttachmentBinding,
  MedicalDocumentSaveReceipt
} from '../Domain/MedicalDocumentAttachmentBindingModels';
import {
  MedicalDocumentUploadCapabilities,
  MedicalDocumentUploadEntry,
  MedicalDocumentUploadEntrySource,
  MedicalDocumentOCRInput,
  MedicalDocumentUploadStage,
  UploadedMedicalDocumentFile
} from '../Domain/MedicalDocumentUploadModels';
import {
  MedicalDocumentUploadFlowStepKind,
  MedicalDocumentUploadStepOutcome
} from '../Domain/MedicalDocumentUploadFlowStep';
import {
  MedicalDocumentUploadProgress,
  MedicalDocumentUploadProgressStep,
  medicalUploadPipelineOrder,
  medicalUploadPipelineSteps
} from '../Domain/MedicalDocumentUploadProgress';
import {
  MedicalDocumentTypeResolution,
  MedicalDocumentTypedExtractionOutput,
  MedicalPreSubmitValidationIssue,
  MedicalPreSubmitValidationResourceType
} from '../Domain/MedicalDocumentTypedModels';
import { MedicalDocumentTypeResolutionFactory } from '../Domain/MedicalDocumentTypeResolverProtocol';
import { MedicalDocumentDraftBuilders } from '../Domain/MedicalDocumentDraftBuilders';
import { MedicalDocumentTypedDraftTree } from '../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentResultKindResolver } from '../Domain/MedicalDocumentResultKindResolver';
import {
  MedicalPreSubmitValidating,
  MedicalPreSubmitValidator
} from '../Domain/MedicalPreSubmitValidator';
import {
  MedicalDocumentStructuredExtractionError
} from '../Domain/MedicalDocumentStructuredExtractionError';
import {
  MedicalDocumentStructuredExtractionRequest
} from '../Domain/MedicalDocumentStructuredExtractionRequest';
import { MedicalExtractionPromptSource } from '../Domain/MedicalExtractionInputSource';
import { MedicalUploadL10n } from '../Domain/SupportingModels';
import { MedicalDocumentUploadErrorNormalizer } from '../Domain/MedicalDocumentUploadErrors';
import { ExaminationReportCategory } from '../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportCategory';
import {
  MedicalReportCardDetailTarget
} from './ResultPages/MedicalReportRecognitionResult/MedicalReportResultSupport';
import { OCRWarmupCoordinator } from '../../../Core/OCR/OCRWarmupCoordinator';
import { HarmonyBuiltInOCRSession } from '../../../Core/OCR/HarmonyBuiltInOCRSession';
import { OCRDiagnostics } from '../../../Core/OCR/OCRDiagnostics';
import {
  InMemoryMedicalDocumentUploadCheckpointStore,
  MedicalCheckpointFileSnapshot,
  MedicalDocumentUploadCheckpoint,
  MedicalDocumentUploadCheckpointStore
} from '../Application/MedicalDocumentUploadCheckpointStore';
import { MedicalDocumentUploadCheckpointStage } from '../Domain/MedicalDocumentUploadPipeline';

/** 简单取消令牌：替代 iOS AIRuntimeCancellationToken。 */
export class MedicalUploadCancellationToken {
  private cancelled: boolean = false;

  cancel(): void {
    this.cancelled = true;
  }

  get isCancelled(): boolean {
    return this.cancelled;
  }

  checkCancellation(): void {
    if (this.cancelled) {
      throw new Error('CancellationError');
    }
  }
}

/**
 * 医疗单据上传与 Typed 识别流程状态机。
 * 对齐参考包 / iOS `MedicalDocumentUploadViewModel`：选文件 → 上传/OCR/类型/抽取 → 结果。
 * HOS-MED-UPLOAD-0006/0007/0010：OCR + 类型 + 抽取 + 本地附件匹配已接通；SaveUseCase 落库仍待后续。
 */
@Observed
export class MedicalDocumentUploadViewModel {
  readonly memberContextStore: MemberContextStore;
  readonly capabilities: MedicalDocumentUploadCapabilities;
  private readonly uploadFilesUseCase?: UploadMedicalDocumentFilesUseCase;
  private readonly ocrUseCase?: MedicalDocumentOCRUseCase;
  private readonly resolveTypeUseCase?: ResolveMedicalDocumentTypeUseCase;
  private readonly extractUseCase?: ExtractTypedMedicalDocumentUseCase;
  private readonly bindFilesUseCase?: BindUploadedFilesToMedicalBusinessUseCase;
  private readonly saveUseCase?: SaveTypedMedicalDocumentUseCase;
  private readonly notification?: NotificationClient;
  /** 保存成功后关闭上传页（由 Host 注入）。 */
  onDismissRequested?: () => void;
  private readonly getGeneration: () => number;
  private readonly getAccountId: () => number | undefined;
  private readonly checkpointStore: MedicalDocumentUploadCheckpointStore;
  private readonly preSubmitValidator: MedicalPreSubmitValidating;

  stage: MedicalDocumentUploadStage = MedicalDocumentUploadStage.PICKING;
  selectedFiles: MedicalAttachmentInput[] = [];
  selectedMemberID: number = 0;
  selectedMemberName: string = '';
  entrySource: MedicalDocumentUploadEntrySource = MedicalDocumentUploadEntrySource.HOME;
  errorMessage: string = '';
  /** 结构化展示模型；页面优先读此字段，errorMessage 为兼容镜像。 */
  errorPresentation?: FileTransferErrorPresentation;
  selectedKind: MedicalDocumentKind = MedicalDocumentKind.AUTO;

  progress?: MedicalDocumentUploadProgress;
  needsManualModeSelection: boolean = false;
  typedOutput: MedicalDocumentTypedExtractionOutput | undefined = undefined;
  /** 抽取后本地附件匹配摘要。 */
  attachmentMatchSummary?: MedicalDocumentAttachmentMatchSummary;
  /** 保存前准备好的 file_ids 绑定结果。 */
  preparedAttachmentBinding?: MedicalDocumentPreparedAttachmentBinding;
  /** 最近一次保存回执。 */
  saveReceipt?: MedicalDocumentSaveReceipt;
  /** 保存进行中（防重入）。 */
  isSaving: boolean = false;
  /** 保存成功序号；首页/列表可监听以刷新。 */
  saveSucceededRevision: number = 0;
  /** 结果页草稿编辑序号；驱动附件关联等嵌套草稿变更后的 UI 刷新。 */
  typedDraftRevision: number = 0;
  /** 保存前预提交校验问题（驱动结果页高亮）。 */
  preSubmitValidationIssues: MedicalPreSubmitValidationIssue[] = [];
  /** 识别结果页报告卡片 → 本地草稿详情导航目标。 */
  medicalReportCardDetailTarget?: MedicalReportCardDetailTarget;
  /**
   * 上传宿主页统一 Navigation 栈。对齐 iOS 单一 NavigationStack：
   * picking/processing/result 为栈根，报告卡片详情作为 push 目标，与宿主 “×/AI 上传报告” 头部共用同一栈，
   * 推入详情后由系统 Navigation 顶掉根内容，不再叠加双头部。由 `MedicalDocumentUploadHostView` 注入。
   */
  medicalUploadNavStack?: NavPathStack;
  /** 结果页强制展开的预校验折叠区（collapseSectionID）。 */
  expandedPreSubmitSections: string[] = [];
  /** 断点恢复后的阶段提示（仅 UI）。 */
  restoredCheckpointStage: string = '';
  failedStep?: MedicalDocumentUploadFlowStepKind;
  pipelineOCRText?: string;
  typeResolution?: MedicalDocumentTypeResolution;
  /** 上传完成后交给 OCR 的稳定输入；OCR 未接入时仍可展示/恢复。 */
  lastOCRInput?: MedicalDocumentOCRInput;
  uploadSessionId: string = '';

  private recognitionTaskRunning: boolean = false;
  private cancellationToken?: MedicalUploadCancellationToken;
  private progressTimerId?: number;
  private stepStartedAt: Map<string, number> = new Map();
  private listeners: Array<() => void> = [];
  private lastPresentedKey: string = '';
  private lastPresentedAtMs: number = 0;
  private pipelineGeneration: number = 0;
  /** 相同参数失败指纹；连续两次后降级 userCanRetry。 */
  private lastValidationFailureFingerprint: string = '';
  private lastValidationFailureCount: number = 0;

  constructor(
    memberContextStore: MemberContextStore,
    uploadFilesUseCase?: UploadMedicalDocumentFilesUseCase,
    notification?: NotificationClient,
    getGeneration: () => number = (): number => 0,
    capabilities: MedicalDocumentUploadCapabilities = new MedicalDocumentUploadCapabilities(),
    checkpointStore: MedicalDocumentUploadCheckpointStore =
      new InMemoryMedicalDocumentUploadCheckpointStore(),
    getAccountId: () => number | undefined = (): number | undefined => undefined,
    ocrUseCase?: MedicalDocumentOCRUseCase,
    resolveTypeUseCase?: ResolveMedicalDocumentTypeUseCase,
    extractUseCase?: ExtractTypedMedicalDocumentUseCase,
    preSubmitValidator: MedicalPreSubmitValidating = new MedicalPreSubmitValidator(),
    bindFilesUseCase?: BindUploadedFilesToMedicalBusinessUseCase,
    saveUseCase?: SaveTypedMedicalDocumentUseCase
  ) {
    this.memberContextStore = memberContextStore;
    this.uploadFilesUseCase = uploadFilesUseCase;
    this.notification = notification;
    this.getGeneration = getGeneration;
    this.capabilities = capabilities;
    this.checkpointStore = checkpointStore;
    this.getAccountId = getAccountId;
    this.ocrUseCase = ocrUseCase;
    this.resolveTypeUseCase = resolveTypeUseCase;
    this.extractUseCase = extractUseCase;
    this.preSubmitValidator = preSubmitValidator;
    this.bindFilesUseCase = bindFilesUseCase;
    this.saveUseCase = saveUseCase;
    this.syncMemberContext();
    this.memberContextStore.onMembersDidChange(() => {
      this.syncMemberContext();
      this.notifyChanged();
    });
  }

  onChanged(listener: () => void): void {
    this.listeners.push(listener);
  }

  members(): Member[] {
    return this.memberContextStore.context.members;
  }

  get canStartRecognition(): boolean {
    return this.selectedMemberID > 0 && this.selectedFiles.length > 0;
  }

  get hasRemoteFiles(): boolean {
    return this.selectedFiles.some((file: MedicalAttachmentInput): boolean =>
      file.remoteFile !== undefined && file.remoteFile.id > 0
    );
  }

  get primaryActionLabel(): string {
    if (!this.errorPresentation) {
      return this.failedStep !== undefined ? MedicalUploadL10n.text('medical.upload.action.retry') : '';
    }
    return FileTransferErrorLocalizer.primaryActionLabel(this.errorPresentation.primaryAction);
  }

  get secondaryActionLabel(): string {
    if (!this.errorPresentation) {
      return MedicalUploadL10n.text('medical.upload.action.return_picking');
    }
    return FileTransferErrorLocalizer.secondaryActionLabel(this.errorPresentation.secondaryAction);
  }

  prepareForEntry(entry: MedicalDocumentUploadEntry): void {
    this.reset(false);
    this.entrySource = entry.source;
    this.uploadSessionId = MedicalDocumentUploadViewModel.newSessionId();
    if (entry.memberId > 0) {
      void this.selectMember(entry.memberId);
      this.selectedMemberID = entry.memberId;
      if (entry.memberName.length > 0) {
        this.selectedMemberName = entry.memberName;
      }
    }
    if (entry.preferredKind !== undefined) {
      this.selectedKind = entry.preferredKind;
    }
    const seeded = entry.initialFiles.length > 0 ? entry.initialFiles : entry.externalFiles;
    if (seeded.length > 0) {
      this.selectedFiles = seeded.slice();
    }
    void this.tryRestoreUploadedCheckpoint().then(() => {
      void this.persistCheckpoint(
        this.restoredCheckpointStage.length > 0 ?
          (this.restoredCheckpointStage as MedicalDocumentUploadCheckpointStage) :
          'picking'
      );
    });
    this.notifyChanged();
    // 入口就绪后即预热，覆盖 home.open → 用户点开始识别的窗口。
    this.prewarmOCR('upload_open');
  }

  /** 后台预热系统 OCR；不阻塞选文件。 */
  prewarmOCR(reason: string): void {
    if (!this.capabilities.ocr) {
      return;
    }
    OCRWarmupCoordinator.shared().prewarm(reason);
  }

  /** 上传页关闭：不强制 release 系统 OCR，避免下次打开再撞 init 超时。 */
  releaseOCRSession(reason: string): void {
    // 仅清阻塞态；真正 release 交给 keepAlive TTL。
    HarmonyBuiltInOCRSession.shared().clearBlockingState(reason);
    OCRDiagnostics.info('ocr.session.host_close', `reason=${reason};action=clear_block_only`);
  }

  private applyOCRWarmingStatus(): void {
    if (!this.progress) {
      return;
    }
    const snap = HarmonyBuiltInOCRSession.shared().snapshot();
    const current = this.progress;
    if (snap.state === 'ready') {
      current.statusLabel = MedicalUploadL10n.text('medical.upload.ocr.recognizing');
    } else if (snap.state === 'cooldown') {
      current.statusLabel = MedicalUploadL10n.text('medical.upload.ocr.unavailable');
    } else {
      current.statusLabel = MedicalUploadL10n.text('medical.upload.ocr.warming');
    }
    this.progress = current;
    this.notifyChanged();
  }

  setSelectedFiles(files: MedicalAttachmentInput[]): void {
    this.selectedFiles = files.slice();
    this.clearPipelineCheckpoints();
    this.clearPresentedError(false);
    this.lastOCRInput = undefined;
    void this.persistCheckpoint('picking');
    this.notifyChanged();
  }

  appendFiles(files: MedicalAttachmentInput[]): void {
    this.setSelectedFiles(this.selectedFiles.concat(files));
  }

  removeFile(previewID: string): void {
    this.setSelectedFiles(this.selectedFiles.filter(
      (file: MedicalAttachmentInput): boolean => file.previewId !== previewID
    ));
  }

  async selectMember(memberID: number): Promise<void> {
    await this.memberContextStore.select(memberID);
    this.syncMemberContext();
    this.clearPresentedError(false);
    this.notifyChanged();
  }

  /** 结果页内切换保存归属成员。对齐 iOS `updateResultMemberID(_:)`，仅改写结果归属，不切换全局成员上下文。 */
  updateResultMemberID(memberID: number): void {
    if (memberID <= 0) {
      return;
    }
    if (this.typedOutput !== undefined) {
      this.typedOutput.envelope.memberID = memberID;
    }
    this.applyResultMemberSelection(memberID);
  }

  /** 进入结果页时，以 envelope.memberID 为结果归属的单一事实源。 */
  syncResultMemberFromEnvelope(): void {
    if (this.typedOutput === undefined) {
      return;
    }
    const envelopeMemberID = this.typedOutput.envelope.memberID ?? 0;
    if (envelopeMemberID > 0) {
      this.applyResultMemberSelection(envelopeMemberID);
      return;
    }
    if (this.selectedMemberID > 0) {
      this.typedOutput.envelope.memberID = this.selectedMemberID;
      this.applyResultMemberSelection(this.selectedMemberID);
    }
  }

  memberNameForID(memberID: number): string {
    if (memberID <= 0) {
      return '';
    }
    const members = this.memberContextStore.context.members;
    const selected = members.find((member: Member): boolean => member.id === memberID);
    return selected?.name ?? '';
  }

  private applyResultMemberSelection(memberID: number): void {
    this.selectedMemberID = memberID;
    this.selectedMemberName = this.memberNameForID(memberID);
    this.notifyChanged();
  }

  openMedicalReportCardDetail(index: number, category: ExaminationReportCategory): void {
    const target = new MedicalReportCardDetailTarget();
    target.index = index;
    target.category = category;
    this.medicalReportCardDetailTarget = target;
    this.notifyChanged();
  }

  clearMedicalReportCardDetail(): void {
    this.medicalReportCardDetailTarget = undefined;
    this.notifyChanged();
  }

  /**
   * 上传流程宿主标题栏文案。
   * picking / processing →「AI 上传报告」；result → 各类型导航标题（检查报告、处方等），对齐 iOS。
   */
  hostBarTitle(): string {
    if (this.stage !== MedicalDocumentUploadStage.RESULT) {
      return MedicalUploadL10n.text('medical.upload.title');
    }
    const kind = MedicalDocumentResultKindResolver.resolve(
      this.typedOutput,
      this.typeResolution,
      this.selectedKind
    );
    return MedicalDocumentResultKindResolver.resultNavTitle(kind);
  }

  startRecognitionTask(): void {
    if (this.recognitionTaskRunning) {
      this.log('medical.upload.vm.ignore_duplicate_start', '已有识别任务运行中');
      return;
    }
    this.recognitionTaskRunning = true;
    this.startRecognition().then(() => {
      this.recognitionTaskRunning = false;
    }).catch(() => {
      this.recognitionTaskRunning = false;
    });
  }

  resumeRecognitionTask(): void {
    if (this.recognitionTaskRunning) {
      return;
    }
    this.clearPresentedError(true);
    this.recognitionTaskRunning = true;
    this.resumeRecognition().then(() => {
      this.recognitionTaskRunning = false;
    }).catch(() => {
      this.recognitionTaskRunning = false;
    });
  }

  /** 按展示模型执行主操作。 */
  performPrimaryErrorAction(): void {
    const action = this.errorPresentation?.primaryAction ??
      (this.failedStep !== undefined ? 'retryUpload' as FileTransferUserAction : 'none');
    this.performErrorAction(action);
  }

  performSecondaryErrorAction(): void {
    const action = this.errorPresentation?.secondaryAction ?? 'returnToPicking';
    this.performErrorAction(action);
  }

  private performErrorAction(action: FileTransferUserAction): void {
    switch (action) {
      case 'retryUpload':
      case 'retryRegister':
        this.resumeRecognitionTask();
        break;
      case 'returnToPicking':
      case 'reselectFile':
        this.returnToPickingPreservingFiles();
        break;
      case 'cancel':
        this.cancelRecognition();
        break;
      default:
        break;
    }
  }

  cancelRecognition(): void {
    this.log('medical.upload.vm.cancel', '用户取消医疗识别流程');
    this.cancellationToken?.cancel();
    this.cancellationToken = undefined;
    this.recognitionTaskRunning = false;
    this.resetRecognitionState();
    this.stage = MedicalDocumentUploadStage.PICKING;
    this.notifyChanged();
  }

  /**
   * 低置信确认：接受当前判定，从 EXTRACT 继续。
   * confidence < 0.5 或 ai_fallback_default 时 ViewModel 会暂停在此。
   */
  confirmDetectedType(): void {
    if (!this.needsManualModeSelection || this.recognitionTaskRunning) {
      return;
    }
    this.needsManualModeSelection = false;
    this.clearPresentedError(false);
    this.recognitionTaskRunning = true;
    this.runRecognitionPipeline(MedicalDocumentUploadFlowStepKind.EXTRACT, false).then(() => {
      this.recognitionTaskRunning = false;
    }).catch(() => {
      this.recognitionTaskRunning = false;
    });
  }

  /**
   * 低置信确认：用户改选手动类型，按 manual 覆盖后从 EXTRACT 继续。
   */
  selectManualKindAndContinue(kind: MedicalDocumentKind): void {
    if (kind === MedicalDocumentKind.AUTO || this.recognitionTaskRunning) {
      return;
    }
    this.selectedKind = kind;
    this.typeResolution = MedicalDocumentTypeResolutionFactory.manual(kind);
    this.needsManualModeSelection = false;
    this.clearPresentedError(false);
    this.recognitionTaskRunning = true;
    this.runRecognitionPipeline(MedicalDocumentUploadFlowStepKind.EXTRACT, false).then(() => {
      this.recognitionTaskRunning = false;
    }).catch(() => {
      this.recognitionTaskRunning = false;
    });
  }

  /** 对齐工单：低置信或兜底必须进入手动确认，避免“已成功但其实不可信”。 */
  static shouldRequireManualTypeConfirmation(resolution: MedicalDocumentTypeResolution): boolean {
    return resolution.confidence < 0.5 || resolution.reason === 'ai_fallback_default';
  }

  async startRecognition(): Promise<void> {
    await this.runRecognitionPipeline(MedicalDocumentUploadFlowStepKind.UPLOAD, true);
  }

  async resumeRecognition(): Promise<void> {
    const start = this.failedStep ?? MedicalDocumentUploadFlowStepKind.UPLOAD;
    await this.runRecognitionPipeline(start, false);
  }

  /**
   * 流水线：上传 → OCR → 类型识别 → 结构化抽取 → 附件绑定。
   * OCR 及后续在服务未接入时以明确错误结束，上传成功后仍保留 remoteFile。
   */
  private async runRecognitionPipeline(
    requestedStartStep: MedicalDocumentUploadFlowStepKind,
    resetForFreshRun: boolean
  ): Promise<void> {
    if (this.selectedMemberID <= 0) {
      this.applyLocalValidationError(MedicalUploadL10n.text('medical.upload.error.no_member'));
      return;
    }
    if (this.selectedFiles.length === 0) {
      this.applyLocalValidationError(MedicalUploadL10n.text('medical.upload.error.no_files'));
      return;
    }

    this.clearPresentedError(false);
    this.typedOutput = undefined;
    this.stage = MedicalDocumentUploadStage.PROCESSING;
    this.needsManualModeSelection = false;
    this.failedStep = undefined;
    this.pipelineGeneration = this.getGeneration();
    if (resetForFreshRun) {
      this.lastValidationFailureFingerprint = '';
      this.lastValidationFailureCount = 0;
    }

    if (resetForFreshRun || this.progress === undefined) {
      this.clearPipelineCheckpoints();
      this.progress = this.createProgress();
    } else {
      this.prepareProgressForRetry(requestedStartStep);
    }
    this.startProgressTimer();
    this.notifyChanged();

    const token = new MedicalUploadCancellationToken();
    this.cancellationToken = token;
    let currentStep: MedicalDocumentUploadFlowStepKind = requestedStartStep;

    try {
      if (this.shouldRun(MedicalDocumentUploadFlowStepKind.UPLOAD, requestedStartStep)) {
        currentStep = MedicalDocumentUploadFlowStepKind.UPLOAD;
        this.reportStart(currentStep);
        if (!this.capabilities.upload || !this.uploadFilesUseCase) {
          throw new Error('上传服务未装配');
        }
        void this.persistCheckpoint('uploading');
        const uploaded = await this.uploadFilesUseCase.execute(
          this.selectedMemberID,
          this.selectedFiles,
          false
        );
        token.checkCancellation();
        this.selectedFiles = uploaded;
        this.reportComplete(
          currentStep,
          MedicalDocumentUploadStepOutcome.SUCCESS,
          `已上传 ${uploaded.length} 个文件`
        );
        this.lastOCRInput = this.buildOCRInput();
        void this.persistCheckpoint('uploaded');
      } else if (this.hasRemoteFiles) {
        const uploadedCount = this.selectedFiles.filter(
          (f: MedicalAttachmentInput): boolean => f.remoteFile !== undefined && f.remoteFile.id > 0
        ).length;
        this.reportComplete(
          MedicalDocumentUploadFlowStepKind.UPLOAD,
          MedicalDocumentUploadStepOutcome.SKIPPED,
          `沿用 ${uploadedCount} 个已上传文件`
        );
        this.lastOCRInput = this.buildOCRInput();
        void this.persistCheckpoint('uploaded');
      }

      // OCR：真实编排；若断点已恢复 pipelineOCRText 则跳过。
      if (this.shouldRun(MedicalDocumentUploadFlowStepKind.OCR, requestedStartStep)) {
        currentStep = MedicalDocumentUploadFlowStepKind.OCR;
        this.reportStart(currentStep);
        this.applyOCRWarmingStatus();
        token.checkCancellation();
        if ((this.pipelineOCRText ?? '').trim().length > 0) {
          this.reportComplete(
            currentStep,
            MedicalDocumentUploadStepOutcome.SKIPPED,
            `沿用 OCR 文本 ${this.pipelineOCRText!.length} 字`
          );
          void this.persistCheckpoint('ocr_done');
        } else if (!this.capabilities.ocr || this.ocrUseCase === undefined) {
          void this.persistCheckpoint('ocr_pending');
          throw new Error('OCR_PENDING');
        } else {
          this.lastOCRInput = this.buildOCRInput();
          const ocrRequest = new MedicalDocumentOCRRequest();
          ocrRequest.uploadSessionId = this.lastOCRInput.uploadSessionId;
          ocrRequest.memberId = this.selectedMemberID;
          ocrRequest.selectedKind = this.selectedKind;
          ocrRequest.files = this.selectedFiles.slice();
          ocrRequest.reRecognizeAll = false;
          const ocrResult = await this.ocrUseCase.execute(ocrRequest);
          token.checkCancellation();
          this.selectedFiles = MedicalDocumentOCRUseCase.applyOCRTextToFiles(
            this.selectedFiles,
            ocrResult
          );
          this.pipelineOCRText = ocrResult.mergedOCRText;
          this.reportComplete(
            currentStep,
            MedicalDocumentUploadStepOutcome.SUCCESS,
            `OCR 完成 ${ocrResult.fileResults.length} 个文件 · ${ocrResult.selectedEngine}`
          );
          void this.persistCheckpoint('ocr_done');
        }
      }

      // 类型识别：manual → localRules → AI → ai_fallback_default。
      if (this.shouldRun(MedicalDocumentUploadFlowStepKind.TYPE_RECOGNITION, requestedStartStep)) {
        currentStep = MedicalDocumentUploadFlowStepKind.TYPE_RECOGNITION;
        this.reportStart(currentStep);
        token.checkCancellation();
        if (this.typeResolution !== undefined) {
          this.reportComplete(
            currentStep,
            MedicalDocumentUploadStepOutcome.SKIPPED,
            `沿用类型 ${this.typeResolution.kindLabel}`
          );
          void this.persistCheckpoint('type_resolved');
        } else {
          const mergedText = this.pipelineOCRText ?? '';
          if (mergedText.trim().length === 0) {
            throw new Error('OCR 文本为空，无法识别类型');
          }
          if (!this.capabilities.typeRecognition || this.resolveTypeUseCase === undefined) {
            throw new Error('TYPE_PENDING');
          }
          const resolution = await this.resolveTypeUseCase.execute(this.selectedKind, mergedText);
          token.checkCancellation();
          this.typeResolution = resolution;
          if (this.selectedKind === MedicalDocumentKind.AUTO) {
            this.selectedKind = resolution.kind;
          }
          this.needsManualModeSelection =
            MedicalDocumentUploadViewModel.shouldRequireManualTypeConfirmation(resolution);
          this.reportComplete(
            currentStep,
            MedicalDocumentUploadStepOutcome.SUCCESS,
            `${resolution.kindLabel}（${resolution.sourceLabel}）`
          );
          void this.persistCheckpoint('type_resolved');
          // 低置信 / fallback：停在 PROCESSING，等用户确认或手动改类型后再进抽取。
          if (this.needsManualModeSelection) {
            this.stopProgressTimer();
            this.notifyChanged();
            return;
          }
        }
      }

      if (this.shouldRun(MedicalDocumentUploadFlowStepKind.EXTRACT, requestedStartStep)) {
        currentStep = MedicalDocumentUploadFlowStepKind.EXTRACT;
        this.reportStart(currentStep);
        if (this.hasReusableTypedOutput()) {
          this.reportComplete(
            currentStep,
            MedicalDocumentUploadStepOutcome.SKIPPED,
            '沿用已抽取结构化结果'
          );
          void this.persistCheckpoint('extracted');
        } else if (!this.capabilities.extraction || this.extractUseCase === undefined ||
          !this.extractUseCase.isExtractionReady) {
          this.reportComplete(
            currentStep,
            MedicalDocumentUploadStepOutcome.SKIPPED,
            '结构化抽取待接入'
          );
          // 未装配抽取时仍进入结果页，保留 OCR/类型检查点，不伪造 extractedJSON。
          if (this.typeResolution !== undefined) {
            const skipped = new MedicalDocumentTypedExtractionOutput();
            skipped.envelope.memberID = this.selectedMemberID;
            skipped.envelope.typeResolution = this.typeResolution;
            skipped.envelope.uploadSessionId = this.uploadSessionId;
            skipped.envelope.ocrTextPreview = (this.pipelineOCRText ?? '').substring(0, 400);
            skipped.payloadPreview = skipped.envelope.ocrTextPreview;
            skipped.source = MedicalExtractionPromptSource.OCR_TEXT;
            this.typedOutput = skipped;
          }
        } else {
          token.checkCancellation();
          const extractRequest = new MedicalDocumentStructuredExtractionRequest();
          extractRequest.memberId = this.selectedMemberID;
          extractRequest.uploadSessionId = this.uploadSessionId;
          extractRequest.selectedKind = this.selectedKind;
          extractRequest.typeResolution = this.typeResolution;
          extractRequest.mergedOCRText = this.pipelineOCRText ?? '';
          extractRequest.files = this.selectedFiles;
          extractRequest.promptSource = MedicalExtractionPromptSource.OCR_TEXT;
          this.log('medical.upload.extract.start',
            `kind=${this.selectedKind};ocrLen=${extractRequest.mergedOCRText.length}`);
          const typed = await this.extractUseCase.extractStructured(extractRequest);
          token.checkCancellation();
          this.typedOutput = typed;
          if (typed.envelope.typeResolution !== undefined) {
            this.typeResolution = typed.envelope.typeResolution;
          }
          this.reportComplete(
            currentStep,
            MedicalDocumentUploadStepOutcome.SUCCESS,
            typed.typedResult.title.length > 0 ?
              typed.typedResult.title : '结构化抽取完成'
          );
          void this.persistCheckpoint('extracted');
        }
      }

      // 附件业务匹配：本地把源文件 previewId 写入 typedDrafts.attachmentFileIds（无网络）。
      if (this.shouldRun(MedicalDocumentUploadFlowStepKind.ATTACHMENT_BINDING, requestedStartStep)) {
        currentStep = MedicalDocumentUploadFlowStepKind.ATTACHMENT_BINDING;
        this.reportStart(currentStep);
        token.checkCancellation();
        if (this.typedOutput === undefined) {
          this.reportComplete(
            currentStep,
            MedicalDocumentUploadStepOutcome.SKIPPED,
            '无结构化结果，跳过附件匹配'
          );
        } else if (!this.capabilities.attachmentBinding) {
          this.reportComplete(
            currentStep,
            MedicalDocumentUploadStepOutcome.SKIPPED,
            '附件匹配能力未开启'
          );
        } else {
          this.typedOutput = MedicalDocumentAttachmentBusinessMatcher.matchAndUpdate(
            this.selectedFiles,
            this.typedOutput
          );
          this.attachmentMatchSummary = MedicalDocumentAttachmentBindingMapper.buildMatchSummary(
            this.typedOutput.typedDrafts,
            this.selectedFiles
          );
          this.preparedAttachmentBinding = MedicalDocumentAttachmentBindingMapper.prepare(
            this.typedOutput.typedDrafts,
            this.selectedFiles
          );
          this.reportComplete(
            currentStep,
            MedicalDocumentUploadStepOutcome.SUCCESS,
            `已匹配 ${this.preparedAttachmentBinding.matchedLocalFileIds.length} 个附件` +
              ` / ${this.preparedAttachmentBinding.remoteFileIds.length} 远端 ID`
          );
          void this.persistCheckpoint('extracted');
        }
      }

      this.stopProgressTimer();
      this.syncResultMemberFromEnvelope();
      this.stage = MedicalDocumentUploadStage.RESULT;
      this.notifyChanged();
    } catch (error) {
      if (token.isCancelled) {
        if (this.cancellationToken === token) {
          this.resetRecognitionState();
          this.stage = MedicalDocumentUploadStage.PICKING;
          this.notifyChanged();
        }
        return;
      }
      if (this.cancellationToken !== token) {
        return;
      }
      // 切号/登出：旧任务不得向新会话发通知。
      if (this.pipelineGeneration > 0 && this.pipelineGeneration !== this.getGeneration()) {
        this.log('medical.upload.vm.pipeline_dropped', 'generation_mismatch');
        return;
      }
      this.failedStep = currentStep;
      this.presentPipelineError(currentStep, error);
      this.reportFail(currentStep);
    } finally {
      if (this.cancellationToken === token) {
        this.cancellationToken = undefined;
      }
    }
  }

  returnToPickingPreservingFiles(): void {
    this.cancellationToken?.cancel();
    this.cancellationToken = undefined;
    this.recognitionTaskRunning = false;
    this.stage = MedicalDocumentUploadStage.PICKING;
    this.progress = undefined;
    this.stopProgressTimer(true);
    this.needsManualModeSelection = false;
    this.clearPresentedError(false);
    this.selectedKind = MedicalDocumentKind.AUTO;
    this.failedStep = undefined;
    this.notifyChanged();
  }

  reset(keepAttachments: boolean = false): void {
    this.cancellationToken?.cancel();
    this.cancellationToken = undefined;
    this.recognitionTaskRunning = false;
    this.stage = MedicalDocumentUploadStage.PICKING;
    if (!keepAttachments) {
      this.selectedFiles = [];
      this.uploadSessionId = '';
      this.lastOCRInput = undefined;
    }
    this.progress = undefined;
    this.stopProgressTimer(true);
    this.needsManualModeSelection = false;
    this.typedOutput = undefined;
    this.attachmentMatchSummary = undefined;
    this.preparedAttachmentBinding = undefined;
    this.saveReceipt = undefined;
    this.preSubmitValidationIssues = [];
    this.expandedPreSubmitSections = [];
    this.restoredCheckpointStage = '';
    this.pipelineOCRText = undefined;
    this.typeResolution = undefined;
    this.clearPresentedError(false);
    this.selectedKind = MedicalDocumentKind.AUTO;
    this.clearPipelineCheckpoints();
    this.syncMemberContext();
  }

  resetRecognitionState(): void {
    this.typedOutput = undefined;
    this.attachmentMatchSummary = undefined;
    this.preparedAttachmentBinding = undefined;
    this.saveReceipt = undefined;
    this.preSubmitValidationIssues = [];
    this.expandedPreSubmitSections = [];
    this.restoredCheckpointStage = '';
    this.pipelineOCRText = undefined;
    this.typeResolution = undefined;
    this.progress = undefined;
    this.stopProgressTimer(true);
    this.needsManualModeSelection = false;
    this.clearPresentedError(false);
    this.failedStep = undefined;
    this.stepStartedAt.clear();
  }

  dismiss(): void {
    this.reset(false);
    this.notifyChanged();
  }

  /**
   * 保存前预校验：对齐 iOS saveResult 的 Gate 1。
   * @returns true 表示可进入保存；false 表示已阻断并写入 preSubmitValidationIssues。
   */
  runPreSubmitValidation(): boolean {
    if (this.typedOutput === undefined) {
      this.preSubmitValidationIssues = [
        MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.CASE_DOCUMENT,
          'typed_output',
          '识别结果',
          '缺少可保存的结构化结果',
          '识别结果'
        )
      ];
      this.notifyChanged();
      return false;
    }
    const issues = this.preSubmitValidator.validate(this.typedOutput);
    const blocking = MedicalPreSubmitValidationIssue.blockingIssues(issues);
    if (blocking.length > 0) {
      this.preSubmitValidationIssues = issues;
      this.log('medical.upload.presubmit.blocked', `issues=${blocking.length}`);
      this.notifyChanged();
      return false;
    }
    this.preSubmitValidationIssues = [];
    this.notifyChanged();
    return true;
  }

  clearAllPreSubmitValidationIssues(): void {
    this.preSubmitValidationIssues = [];
    this.notifyChanged();
  }

  clearPreSubmitValidationIssuesMatchingFieldKeys(fieldKeys: string[]): void {
    if (fieldKeys.length === 0 || this.preSubmitValidationIssues.length === 0) {
      return;
    }
    this.preSubmitValidationIssues = this.preSubmitValidationIssues.filter(
      (issue: MedicalPreSubmitValidationIssue): boolean => fieldKeys.indexOf(issue.fieldKey) < 0
    );
    this.notifyChanged();
  }

  /** 是否已有可复用的抽取结果（跳过 EXTRACT 或允许保存）。 */
  private hasReusableTypedOutput(): boolean {
    const output: MedicalDocumentTypedExtractionOutput | undefined = this.typedOutput;
    if (output === undefined) {
      return false;
    }
    return output.extractedJSON.trim().length > 0 ||
      MedicalDocumentTypedDraftTree.ensureInstance(output.typedDrafts).displayTitle().length > 0;
  }

  /** 结果页是否允许触发「校验并保存」。 */
  get canAttemptSave(): boolean {
    return this.hasReusableTypedOutput();
  }

  /** 结果页展示用：预提交问题摘要行。 */
  preSubmitValidationIssueLines(): string[] {
    return this.preSubmitValidationIssues.map(
      (issue: MedicalPreSubmitValidationIssue): string => issue.summaryLine()
    );
  }

  preSubmitIssues(): MedicalPreSubmitValidationIssue[] {
    return this.preSubmitValidationIssues.slice();
  }

  preSubmitIssueMessage(fieldKey: string): string {
    for (let i = 0; i < this.preSubmitValidationIssues.length; i++) {
      if (this.preSubmitValidationIssues[i].fieldKey === fieldKey) {
        return this.preSubmitValidationIssues[i].message;
      }
    }
    return '';
  }

  /** 结果页路由用文档类型。 */
  resultDocumentKind(): MedicalDocumentKind {
    return MedicalDocumentResultKindResolver.resolve(
      this.typedOutput,
      this.typeResolution,
      this.selectedKind
    );
  }

  /**
   * 确保 typedOutput / typedDrafts 存在，并设定 kind。
   * 结果页编辑前调用。
   */
  ensureTypedDraftTree(kind: MedicalDocumentKind): MedicalDocumentTypedDraftTree {
    if (this.typedOutput === undefined) {
      const output = new MedicalDocumentTypedExtractionOutput();
      output.typedDrafts.kind = kind;
      output.typedResult.kind = kind;
      this.typedOutput = output;
    } else {
      this.typedOutput.typedDrafts.kind = kind;
      this.typedOutput.typedResult.kind = kind;
    }
    return MedicalDocumentTypedDraftTree.ensureInstance(this.typedOutput.typedDrafts);
  }

  /** 草稿字段变更后同步摘要并清理对应校验问题。 */
  notifyTypedDraftChanged(clearedFieldKeys: string[] = []): void {
    if (this.typedOutput !== undefined) {
      const drafts = MedicalDocumentTypedDraftTree.ensureInstance(this.typedOutput.typedDrafts);
      this.typedOutput.typedDrafts = drafts;
      this.typedOutput.typedResult.kind = drafts.kind;
      this.typedOutput.typedResult.title = drafts.displayTitle();
      this.typedOutput.typedResult.summary = drafts.displaySummary();
      // 编辑后保留 extractedJSON；若为空则用标题占位，保证 canAttemptSave。
      if (this.typedOutput.extractedJSON.trim().length === 0 &&
        drafts.displayTitle().length > 0) {
        this.typedOutput.extractedJSON = '{}';
      }
    }
    if (clearedFieldKeys.length > 0) {
      this.clearPreSubmitValidationIssuesMatchingFieldKeys(clearedFieldKeys);
      this.typedDraftRevision += 1;
      return;
    }
    this.typedDraftRevision += 1;
    this.notifyChanged();
  }

  expandPreSubmitSection(sectionID: string): void {
    if (sectionID.length === 0) {
      return;
    }
    if (this.expandedPreSubmitSections.indexOf(sectionID) < 0) {
      this.expandedPreSubmitSections = this.expandedPreSubmitSections.concat([sectionID]);
      this.notifyChanged();
    }
  }

  isPreSubmitSectionExpanded(sectionID: string): boolean {
    return this.expandedPreSubmitSections.indexOf(sectionID) >= 0;
  }

  /**
   * 结果页 CTA：启动异步保存（对齐 iOS saveResult）。
   * @returns false 表示本地校验已阻断；true 表示已进入或完成异步保存流程。
   */
  attemptSave(): boolean {
    if (this.isSaving) {
      return false;
    }
    if (!this.runPreSubmitValidation()) {
      const blocking = MedicalPreSubmitValidationIssue.blockingIssues(
        this.preSubmitValidationIssues
      );
      if (blocking.length > 0) {
        const section = blocking[0].collapseSectionID();
        if (section !== undefined) {
          this.expandPreSubmitSection(section);
        }
      }
      return false;
    }
    if (this.typedOutput !== undefined) {
      this.preparedAttachmentBinding = MedicalDocumentAttachmentBindingMapper.prepare(
        this.typedOutput.typedDrafts,
        this.selectedFiles
      );
      if ((this.typedOutput.envelope.memberID ?? 0) <= 0) {
        this.typedOutput.envelope.memberID = this.selectedMemberID;
      }
    }
    if (!this.capabilities.save || this.saveUseCase === undefined) {
      this.log(
        'medical.upload.save.pending',
        `presubmit_passed;fileIds=${this.preparedAttachmentBinding?.remoteFileIds.length ?? 0}`
      );
      return true;
    }
    void this.saveResult();
    return true;
  }

  /**
   * 正式保存：预校验已在 attemptSave 通过。对齐 iOS saveResult。
   */
  async saveResult(): Promise<boolean> {
    if (this.isSaving) {
      return false;
    }
    if (this.typedOutput === undefined || this.saveUseCase === undefined) {
      this.applyLocalValidationError('缺少可保存的识别结果');
      return false;
    }
    this.isSaving = true;
    this.reportStart(MedicalDocumentUploadFlowStepKind.SAVE);
    this.notifyChanged();
    try {
      const receipt = await this.saveUseCase.execute(this.typedOutput, this.selectedFiles);
      this.saveReceipt = receipt;
      this.reportComplete(
        MedicalDocumentUploadFlowStepKind.SAVE,
        MedicalDocumentUploadStepOutcome.SUCCESS,
        receipt.message.length > 0 ? receipt.message : '保存成功'
      );
      try {
        await this.bindUploadedFilesAfterSave(receipt);
      } catch (_bindErr) {
        this.log('medical.upload.bind.after_save_failed', `record=${receipt.recordID}`);
      }
      void this.checkpointStore.clear(this.uploadSessionId);
      this.saveSucceededRevision += 1;
      this.notification?.success(
        receipt.message.length > 0 ? receipt.message : '医疗记录已保存',
        '保存成功',
        'medical.upload.save'
      );
      this.reset(false);
      this.onDismissRequested?.();
      this.notifyChanged();
      return true;
    } catch (error) {
      this.reportFail(MedicalDocumentUploadFlowStepKind.SAVE);
      const message = this.localizedSaveErrorMessage(error);
      this.applyLocalValidationError(message);
      this.log('medical.upload.save.failed', message);
      return false;
    } finally {
      this.isSaving = false;
      this.notifyChanged();
    }
  }

  private localizedSaveErrorMessage(error: Object | Error): string {
    if (error instanceof MedicalDocumentSaveError) {
      return error.message;
    }
    if (error instanceof Error && error.message.length > 0) {
      return error.message;
    }
    return '保存失败，请稍后重试';
  }

  /**
   * 保存成功后回写文件业务归属。供 SaveUseCase 接线后调用。
   * 绑定失败不删除源文件、不清空 typedOutput。
   */
  async bindUploadedFilesAfterSave(receipt: MedicalDocumentSaveReceipt): Promise<void> {
    this.saveReceipt = receipt;
    if (this.bindFilesUseCase === undefined || !receipt.isSuccess) {
      return;
    }
    const remoteIds = this.preparedAttachmentBinding?.remoteFileIds ?? [];
    const fallbackIds: number[] = [];
    for (let i = 0; i < this.selectedFiles.length; i++) {
      const remote = this.selectedFiles[i].remoteFile;
      if (remote !== undefined && remote.id > 0 && fallbackIds.indexOf(remote.id) < 0) {
        fallbackIds.push(remote.id);
      }
    }
    const ids = remoteIds.length > 0 ? remoteIds : fallbackIds;
    const kind = receipt.kind !== MedicalDocumentKind.AUTO ?
      receipt.kind :
      (this.typedOutput?.typedDrafts.kind ?? this.selectedKind);
    await this.bindFilesUseCase.execute(ids, kind, receipt);
  }

  clearError(): void {
    this.clearPresentedError(false);
    this.notifyChanged();
  }

  private applyLocalValidationError(message: string): void {
    const presentation = new FileTransferErrorPresentation();
    presentation.normalizedErrorCode = 'sourceInvalid';
    presentation.message = message;
    presentation.title = MedicalUploadL10n.text('common.error');
    presentation.primaryAction = 'reselectFile';
    presentation.secondaryAction = 'none';
    presentation.showGlobalBanner = false;
    presentation.bannerLevel = 'none';
    presentation.retryable = false;
    this.errorPresentation = presentation;
    this.errorMessage = message;
    this.notifyChanged();
  }

  private presentPipelineError(step: MedicalDocumentUploadFlowStepKind, error: Object | Error): void {
    const stageError = MedicalDocumentUploadErrorNormalizer.normalize(
      error,
      error instanceof Error ? error.message : ''
    );

    // OCR 待接入：与文件传输错误区分，展示可恢复「识别待接入」。
    if (stageError.stage === 'ocr_pending' ||
      (!(error instanceof FileTransferError) &&
        error instanceof Error &&
        (error.message === 'OCR_PENDING' ||
          error.message === MedicalUploadL10n.text('medical.upload.ocr.pending')))) {
      const ocrPresentation = new FileTransferErrorPresentation();
      ocrPresentation.normalizedErrorCode = 'ocr_pending';
      ocrPresentation.message = MedicalUploadL10n.text('medical.upload.ocr.pending');
      ocrPresentation.title = MedicalUploadL10n.text('medical.upload.status.failed');
      ocrPresentation.primaryAction = 'returnToPicking';
      ocrPresentation.secondaryAction = 'none';
      ocrPresentation.showGlobalBanner = true;
      ocrPresentation.bannerLevel = 'warning';
      ocrPresentation.retryable = false;
      ocrPresentation.stage = step;
      this.errorPresentation = ocrPresentation;
      this.errorMessage = ocrPresentation.message;
      this.publishErrorNotificationOnce(step, ocrPresentation);
      this.logPipelineFailed(step, ocrPresentation, error);
      this.notifyChanged();
      return;
    }

    if (stageError.stage === 'ocr_failed') {
      const ocrFail = new FileTransferErrorPresentation();
      ocrFail.normalizedErrorCode = 'ocr_failed';
      // 优先阶段化用户文案（来自 OCRError.userMessage / normalizer），避免展示 raw 错误串。
      ocrFail.message = stageError.message.length > 0 ?
        stageError.message : MedicalUploadL10n.text('medical.upload.ocr.failed');
      ocrFail.title = MedicalUploadL10n.text('medical.upload.status.failed');
      ocrFail.primaryAction = 'retryUpload';
      ocrFail.secondaryAction = 'returnToPicking';
      ocrFail.showGlobalBanner = true;
      ocrFail.bannerLevel = 'error';
      ocrFail.retryable = stageError.recoverable;
      ocrFail.stage = step;
      this.errorPresentation = ocrFail;
      this.errorMessage = ocrFail.message;
      this.publishErrorNotificationOnce(step, ocrFail);
      this.logPipelineFailed(step, ocrFail, error);
      this.notifyChanged();
      return;
    }

    if (stageError.stage === 'extract_failed' ||
      (error instanceof MedicalDocumentStructuredExtractionError && error.code !== 'cancelled')) {
      const extractFail = new FileTransferErrorPresentation();
      extractFail.normalizedErrorCode = stageError.code.length > 0 ?
        stageError.code : 'extract_failed';
      extractFail.message = stageError.message.length > 0 ?
        stageError.message : '结构化抽取失败，可重试';
      extractFail.title = MedicalUploadL10n.text('medical.upload.status.failed');
      extractFail.primaryAction = 'retryUpload';
      extractFail.secondaryAction = 'returnToPicking';
      extractFail.showGlobalBanner = true;
      extractFail.bannerLevel = 'error';
      extractFail.retryable = stageError.recoverable;
      extractFail.stage = step;
      this.errorPresentation = extractFail;
      this.errorMessage = extractFail.message;
      if (error instanceof MedicalDocumentStructuredExtractionError &&
        error.feedback !== undefined) {
        this.log('medical.upload.extract.retry_feedback',
          `code=${error.code};field=${error.fieldPath};suggestion=${error.feedback.suggestion ?? ''}`);
      }
      this.publishErrorNotificationOnce(step, extractFail);
      this.logPipelineFailed(step, extractFail, error);
      this.notifyChanged();
      return;
    }

    const presentation = FileTransferErrorLocalizer.present(error);
    presentation.stage = step;
    if (stageError.code.length > 0) {
      // 保留 localizer 文案，同时写入业务阶段码便于诊断。
      presentation.normalizedErrorCode = presentation.normalizedErrorCode.length > 0 ?
        presentation.normalizedErrorCode : stageError.code;
    }
    if (error instanceof FileTransferError &&
      error.code === 'ossRequestValidationUnknown') {
      this.applyRepeatValidationFailure(presentation, error);
    } else if (error instanceof FileTransferError &&
      error.code === 'ossTransientFailure' &&
      OSSErrorDecoder.isRcpTransportReason(error.requestValidationReason ?? '')) {
      this.applyRepeatRcpFailure(presentation, error);
    } else {
      this.lastValidationFailureFingerprint = '';
      this.lastValidationFailureCount = 0;
    }
    this.errorPresentation = presentation;
    this.errorMessage = presentation.message;
    this.publishErrorNotificationOnce(step, presentation);
    this.logPipelineFailed(step, presentation, error);
    this.notifyChanged();
  }

  /**
   * 相同 ossCode+ossEc+policy+keyFp+contentType 连续失败：不再鼓励无限重试。
   */
  private applyRepeatValidationFailure(
    presentation: FileTransferErrorPresentation,
    error: FileTransferError
  ): void {
    const fingerprint =
      `${error.ossCode ?? ''}|${error.ossEc ?? ''}|${error.transportPolicyVersion ?? ''}|` +
      `${error.objectKeyFingerprint ?? ''}|${error.contentTypeCategory ?? ''}`;
    if (fingerprint.length > 4 && fingerprint === this.lastValidationFailureFingerprint) {
      this.lastValidationFailureCount += 1;
    } else {
      this.lastValidationFailureFingerprint = fingerprint;
      this.lastValidationFailureCount = 1;
    }
    if (this.lastValidationFailureCount >= 2) {
      presentation.retryable = false;
      presentation.primaryAction = 'returnToPicking';
      presentation.secondaryAction = 'none';
      presentation.message = FileTransferL10n.text('file.transfer.error.request_validation_repeat');
      const fields = new LogFields();
      fields.operation = 'medical_upload_vm';
      fields.code = 'ossRequestValidationUnknown';
      fields.detail = `repeatFailure=true;count=${this.lastValidationFailureCount}`;
      Logger.info('medical.upload.repeat_validation_failure', LogModule.HOME, fields);
    }
  }

  /** 相同 RCP reason+policy+keyFp 连续两次：停止鼓励重试。 */
  private applyRepeatRcpFailure(
    presentation: FileTransferErrorPresentation,
    error: FileTransferError
  ): void {
    const fingerprint =
      `rcp|${error.requestValidationReason ?? ''}|${error.transportPolicyVersion ?? ''}|` +
      `${error.objectKeyFingerprint ?? ''}|${error.contentTypeCategory ?? ''}`;
    if (fingerprint.length > 8 && fingerprint === this.lastValidationFailureFingerprint) {
      this.lastValidationFailureCount += 1;
    } else {
      this.lastValidationFailureFingerprint = fingerprint;
      this.lastValidationFailureCount = 1;
    }
    if (this.lastValidationFailureCount >= 2) {
      presentation.retryable = false;
      presentation.primaryAction = 'returnToPicking';
      presentation.secondaryAction = 'none';
      presentation.message = FileTransferL10n.text('file.transfer.error.rcp_transport_repeat');
      const fields = new LogFields();
      fields.operation = 'medical_upload_vm';
      fields.code = 'ossTransientFailure';
      fields.detail =
        `repeatRcpFailure=true;count=${this.lastValidationFailureCount};` +
        `reason=${error.requestValidationReason ?? ''}`;
      Logger.info('medical.upload.repeat_rcp_failure', LogModule.HOME, fields);
    }
  }

  private publishErrorNotificationOnce(
    step: MedicalDocumentUploadFlowStepKind,
    presentation: FileTransferErrorPresentation
  ): void {
    if (!presentation.showGlobalBanner || presentation.bannerLevel === 'none') {
      this.logErrorPresented(presentation, 'inline', false);
      return;
    }
    if (!this.notification) {
      this.logErrorPresented(presentation, 'inline', false);
      return;
    }
    const key = `${this.pipelineGeneration}|${step}|${presentation.normalizedErrorCode}`;
    const now = Date.now();
    if (key === this.lastPresentedKey && now - this.lastPresentedAtMs < 3000) {
      this.logErrorPresented(presentation, 'banner', true);
      return;
    }
    this.lastPresentedKey = key;
    this.lastPresentedAtMs = now;
    const source = 'medical.upload';
    if (presentation.bannerLevel === 'warning') {
      this.notification.warning(presentation.message, presentation.title, source);
    } else {
      this.notification.error(presentation.message, presentation.title, source);
    }
    this.logErrorPresented(presentation, 'banner', false);
  }

  private logErrorPresented(
    presentation: FileTransferErrorPresentation,
    mode: string,
    deduplicated: boolean
  ): void {
    const fields = new LogFields();
    fields.operation = 'medical_upload_vm';
    fields.code = presentation.normalizedErrorCode;
    fields.detail = `presentation=${mode};deduplicated=${deduplicated};retryable=${presentation.retryable}`;
    Logger.info('medical.upload.error_presented', LogModule.HOME, fields);
  }

  private logPipelineFailed(
    step: MedicalDocumentUploadFlowStepKind,
    presentation: FileTransferErrorPresentation,
    error: Object | Error
  ): void {
    const fields = new LogFields();
    fields.operation = 'medical_upload_vm';
    fields.code = presentation.normalizedErrorCode;
    fields.detail =
      `step=${step};retryable=${presentation.retryable};` +
      `transferCount=${this.selectedFiles.length}`;
    if (error instanceof FileTransferError && error.ossRequestId) {
      fields.ossRequestId = error.ossRequestId;
    }
    if (error instanceof FileTransferError && error.requestId) {
      fields.requestId = error.requestId;
    }
    const level = presentation.bannerLevel === 'warning' ? LogLevel.WARN : LogLevel.ERROR;
    if (level === LogLevel.WARN) {
      Logger.warn('medical.upload.vm.pipeline_failed', LogModule.HOME, fields);
    } else {
      Logger.error('medical.upload.vm.pipeline_failed', LogModule.HOME, fields);
    }
  }

  private clearPresentedError(allowRepublish: boolean): void {
    this.errorMessage = '';
    this.errorPresentation = undefined;
    if (allowRepublish) {
      this.lastPresentedKey = '';
      this.lastPresentedAtMs = 0;
    }
  }

  private createProgress(): MedicalDocumentUploadProgress {
    const steps = medicalUploadPipelineSteps().map(
      (kind: MedicalDocumentUploadFlowStepKind): MedicalDocumentUploadProgressStep =>
        new MedicalDocumentUploadProgressStep(kind)
    );
    return new MedicalDocumentUploadProgress(
      MedicalUploadL10n.text('medical.upload.processing.title'),
      MedicalUploadL10n.text('medical.upload.status.processing'),
      0,
      this.estimatedRecognitionSeconds(),
      steps
    );
  }

  private estimatedRecognitionSeconds(): number {
    const fileCount = this.selectedFiles.length;
    if (fileCount === 0) {
      return 60;
    }
    const seconds = 35 + fileCount * 20;
    return Math.min(Math.max(seconds, 48), 900);
  }

  private clearPipelineCheckpoints(): void {
    this.pipelineOCRText = undefined;
    this.typeResolution = undefined;
    this.failedStep = undefined;
    this.stepStartedAt.clear();
  }

  private shouldRun(
    step: MedicalDocumentUploadFlowStepKind,
    startStep: MedicalDocumentUploadFlowStepKind
  ): boolean {
    return medicalUploadPipelineOrder(step) >= medicalUploadPipelineOrder(startStep);
  }

  private prepareProgressForRetry(step: MedicalDocumentUploadFlowStepKind): void {
    if (!this.progress) {
      return;
    }
    const current = this.progress;
    this.ensurePipelineSteps(current);
    for (let i = 0; i < current.steps.length; i++) {
      const s = current.steps[i];
      if (medicalUploadPipelineOrder(s.kind) < medicalUploadPipelineOrder(step)) {
        if (!s.isTerminalSuccess) {
          s.outcome = MedicalDocumentUploadStepOutcome.SKIPPED;
        }
      } else {
        s.outcome = MedicalDocumentUploadStepOutcome.PENDING;
        s.resultSummary = '';
        if (medicalUploadPipelineOrder(s.kind) > medicalUploadPipelineOrder(step)) {
          s.elapsedMilliseconds = 0;
          this.stepStartedAt.delete(s.kind);
        }
      }
    }
    this.stepStartedAt.delete(step);
    current.statusLabel = MedicalUploadL10n.text('medical.upload.status.processing');
    this.progress = current;
  }

  private ensurePipelineSteps(current: MedicalDocumentUploadProgress): void {
    const existing = new Map<string, MedicalDocumentUploadProgressStep>();
    for (let i = 0; i < current.steps.length; i++) {
      existing.set(current.steps[i].kind, current.steps[i]);
    }
    current.steps = medicalUploadPipelineSteps().map(
      (kind: MedicalDocumentUploadFlowStepKind): MedicalDocumentUploadProgressStep =>
        existing.get(kind) ?? new MedicalDocumentUploadProgressStep(kind)
    );
  }

  private reportStart(step: MedicalDocumentUploadFlowStepKind): void {
    if (!this.progress) {
      return;
    }
    const current = this.progress;
    this.ensurePipelineSteps(current);
    for (let i = 0; i < current.steps.length; i++) {
      const s = current.steps[i];
      if (s.kind === step) {
        s.outcome = MedicalDocumentUploadStepOutcome.RUNNING;
      } else if (medicalUploadPipelineOrder(s.kind) < medicalUploadPipelineOrder(step)
        && !s.isTerminalSuccess
        && s.outcome !== MedicalDocumentUploadStepOutcome.FAILED) {
        s.outcome = MedicalDocumentUploadStepOutcome.SUCCESS;
      } else if (s.outcome === MedicalDocumentUploadStepOutcome.RUNNING) {
        s.outcome = MedicalDocumentUploadStepOutcome.PENDING;
        s.resultSummary = '';
      }
    }
    this.stepStartedAt.set(step, Date.now());
    current.statusLabel = MedicalUploadL10n.text('medical.upload.status.processing');
    this.progress = current;
    this.notifyChanged();
  }

  private reportComplete(
    step: MedicalDocumentUploadFlowStepKind,
    outcome: MedicalDocumentUploadStepOutcome,
    resultSummary: string = ''
  ): void {
    if (!this.progress) {
      return;
    }
    const current = this.progress;
    this.ensurePipelineSteps(current);
    this.finalizeStepElapsed(step, current);
    const target = current.steps.find(
      (s: MedicalDocumentUploadProgressStep): boolean => s.kind === step
    );
    if (target) {
      target.outcome = outcome;
      target.resultSummary = resultSummary;
    }
    this.progress = current;
    this.notifyChanged();
  }

  private reportFail(step: MedicalDocumentUploadFlowStepKind): void {
    if (!this.progress) {
      return;
    }
    const current = this.progress;
    this.ensurePipelineSteps(current);
    this.finalizeStepElapsed(step, current);
    const target = current.steps.find(
      (s: MedicalDocumentUploadProgressStep): boolean => s.kind === step
    );
    if (target) {
      target.outcome = MedicalDocumentUploadStepOutcome.FAILED;
      if (this.errorPresentation && this.errorPresentation.message.length > 0) {
        target.resultSummary = this.errorPresentation.message;
      }
    }
    current.statusLabel = MedicalUploadL10n.text('medical.upload.status.failed');
    this.progress = current;
    this.stopProgressTimer();
    this.notifyChanged();
  }

  private finalizeStepElapsed(
    step: MedicalDocumentUploadFlowStepKind,
    current: MedicalDocumentUploadProgress
  ): void {
    const startedAt = this.stepStartedAt.get(step);
    if (startedAt === undefined) {
      return;
    }
    this.stepStartedAt.delete(step);
    const target = current.steps.find(
      (s: MedicalDocumentUploadProgressStep): boolean => s.kind === step
    );
    if (!target) {
      return;
    }
    const measured = Math.ceil(Date.now() - startedAt);
    target.elapsedMilliseconds = Math.max(target.elapsedMilliseconds, measured);
  }

  private startProgressTimer(): void {
    if (this.progressTimerId !== undefined) {
      return;
    }
    this.progressTimerId = setInterval(() => {
      if (this.stage !== MedicalDocumentUploadStage.PROCESSING || !this.progress) {
        return;
      }
      const current = this.progress;
      current.elapsedSeconds += 1;
      const running = current.steps.find(
        (s: MedicalDocumentUploadProgressStep): boolean =>
          s.outcome === MedicalDocumentUploadStepOutcome.RUNNING
      );
      if (running) {
        running.elapsedMilliseconds += 1000;
      }
      // 重新赋值以触发 @ObjectLink 刷新
      this.progress = current;
      this.notifyChanged();
    }, 1000);
  }

  private stopProgressTimer(resetElapsedSeconds: boolean = false): void {
    if (this.progressTimerId !== undefined) {
      clearInterval(this.progressTimerId);
      this.progressTimerId = undefined;
    }
    if (resetElapsedSeconds && this.progress) {
      this.progress.elapsedSeconds = 0;
      for (let i = 0; i < this.progress.steps.length; i++) {
        this.progress.steps[i].elapsedMilliseconds = 0;
      }
      this.stepStartedAt.clear();
    }
  }

  private syncMemberContext(): void {
    const selectedID = this.memberContextStore.context.selectedMemberID;
    this.selectedMemberID = selectedID ?? 0;
    const members = this.memberContextStore.context.members;
    const selected = members.find((member: Member): boolean => member.id === this.selectedMemberID);
    this.selectedMemberName = selected?.name ?? '';
  }

  private notifyChanged(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }

  private log(event: string, detail: string): void {
    const fields = new LogFields();
    fields.operation = 'medical_upload_vm';
    fields.detail = detail;
    Logger.info(event, LogModule.HOME, fields);
  }

  private buildOCRInput(): MedicalDocumentOCRInput {
    const input = new MedicalDocumentOCRInput();
    input.uploadSessionId = this.uploadSessionId.length > 0 ?
      this.uploadSessionId : MedicalDocumentUploadViewModel.newSessionId();
    input.memberId = this.selectedMemberID;
    input.selectedKind = this.selectedKind;
    input.reRecognizeAll = false;
    const uploaded: UploadedMedicalDocumentFile[] = [];
    for (let i = 0; i < this.selectedFiles.length; i++) {
      const file = this.selectedFiles[i];
      if (file.remoteFile === undefined || file.remoteFile.id <= 0) {
        continue;
      }
      const item = new UploadedMedicalDocumentFile();
      item.localId = file.previewId;
      item.remoteFile = file.remoteFile;
      item.sourceBusinessType = 'medical_document_upload_source';
      item.sourceBusinessId = `${this.selectedMemberID}`;
      uploaded.push(item);
    }
    input.files = uploaded;
    this.uploadSessionId = input.uploadSessionId;
    return input;
  }

  private async persistCheckpoint(stage: MedicalDocumentUploadCheckpointStage): Promise<void> {
    if (this.uploadSessionId.length === 0) {
      this.uploadSessionId = MedicalDocumentUploadViewModel.newSessionId();
    }
    const snapshot = new MedicalDocumentUploadCheckpoint();
    snapshot.uploadSessionId = this.uploadSessionId;
    snapshot.accountId = this.getAccountId() ?? 0;
    snapshot.memberId = this.selectedMemberID;
    snapshot.source = this.entrySource;
    snapshot.stage = stage;
    snapshot.updatedAt = new Date().toISOString();
    snapshot.selectedKind = this.selectedKind;
    snapshot.pipelineOCRText = this.pipelineOCRText ?? '';
    if (this.typeResolution !== undefined) {
      snapshot.typeResolutionJSON = JSON.stringify({
        kind: this.typeResolution.kind,
        kindLabel: this.typeResolution.kindLabel,
        sourceLabel: this.typeResolution.sourceLabel,
        confidence: this.typeResolution.confidence,
        source: this.typeResolution.source,
        reason: this.typeResolution.reason
      });
    }
    snapshot.extractedJSON = this.typedOutput?.extractedJSON ?? '';
    snapshot.failedStep = this.failedStep ?? '';
    snapshot.selectedFiles = this.selectedFiles.map(MedicalCheckpointFileSnapshot.fromAttachment);
    snapshot.uploadedFiles = this.selectedFiles
      .filter((f: MedicalAttachmentInput): boolean =>
        f.remoteFile !== undefined && f.remoteFile.id > 0)
      .map(MedicalCheckpointFileSnapshot.fromAttachment);
    try {
      await this.checkpointStore.save(snapshot);
    } catch (_e) {
      this.log('medical.upload.checkpoint.save_failed', `stage=${stage}`);
    }
  }

  /**
   * 重进页面恢复：上传层 remoteFile + OCR 文本 + 类型/抽取上下文。
   * stage 决定恢复深度；不自动重跑流水线。
   */
  private async tryRestoreUploadedCheckpoint(): Promise<void> {
    const accountId = this.getAccountId() ?? 0;
    if (accountId <= 0 || this.selectedMemberID <= 0) {
      return;
    }
    try {
      const latest = await this.checkpointStore.loadLatest(accountId, this.selectedMemberID);
      if (!latest ||
        (latest.stage !== 'uploaded' &&
          latest.stage !== 'ocr_pending' &&
          latest.stage !== 'ocr_done' &&
          latest.stage !== 'type_resolved' &&
          latest.stage !== 'extracted')) {
        return;
      }
      if (latest.uploadedFiles.length === 0 && latest.selectedFiles.length === 0) {
        return;
      }
      this.uploadSessionId = latest.uploadSessionId;
      this.restoredCheckpointStage = latest.stage;
      const sourceFiles = latest.uploadedFiles.length > 0 ?
        latest.uploadedFiles : latest.selectedFiles;
      const byLocalId = new Map<string, MedicalCheckpointFileSnapshot>();
      for (let i = 0; i < sourceFiles.length; i++) {
        byLocalId.set(sourceFiles[i].localId, sourceFiles[i]);
      }
      if (this.selectedFiles.length === 0) {
        this.selectedFiles = sourceFiles.map(
          (s: MedicalCheckpointFileSnapshot): MedicalAttachmentInput => s.toAttachment()
        );
      } else {
        const merged: MedicalAttachmentInput[] = [];
        for (let i = 0; i < this.selectedFiles.length; i++) {
          const current = this.selectedFiles[i];
          const snap = byLocalId.get(current.previewId);
          if (snap) {
            const restored = snap.toAttachment();
            if (current.remoteFile !== undefined && current.remoteFile.id > 0) {
              restored.remoteFile = current.remoteFile;
            }
            if (current.ocrText.length > 0 && restored.ocrText.length === 0) {
              restored.ocrText = current.ocrText;
            }
            merged.push(restored);
          } else {
            merged.push(current);
          }
        }
        this.selectedFiles = merged;
      }
      if (latest.selectedKind.length > 0) {
        this.selectedKind = latest.selectedKind as MedicalDocumentKind;
      }
      if (latest.pipelineOCRText.length > 0 &&
        (latest.stage === 'ocr_done' || latest.stage === 'type_resolved' ||
          latest.stage === 'extracted')) {
        this.pipelineOCRText = latest.pipelineOCRText;
      }
      if (latest.typeResolutionJSON.length > 0 &&
        (latest.stage === 'type_resolved' || latest.stage === 'extracted')) {
        this.typeResolution = MedicalDocumentUploadViewModel.parseTypeResolution(
          latest.typeResolutionJSON
        );
      }
      if (latest.extractedJSON.length > 0 && latest.stage === 'extracted') {
        this.rebuildTypedOutputFromCheckpoint(latest);
        this.syncResultMemberFromEnvelope();
        this.stage = MedicalDocumentUploadStage.RESULT;
      }
      this.lastOCRInput = this.buildOCRInput();
      this.log('medical.upload.checkpoint.restored',
        `session=${latest.uploadSessionId};stage=${latest.stage};` +
          `uploaded=${latest.uploadedFiles.length};ocrLen=${latest.pipelineOCRText.length}`);
      this.notifyChanged();
    } catch (_e) {
      this.log('medical.upload.checkpoint.restore_failed', 'loadLatest');
    }
  }

  private rebuildTypedOutputFromCheckpoint(latest: MedicalDocumentUploadCheckpoint): void {
    const kind = (latest.selectedKind.length > 0 ?
      latest.selectedKind : this.selectedKind) as MedicalDocumentKind;
    const drafts = MedicalDocumentDraftBuilders.buildTree(kind, latest.extractedJSON);
    const output = new MedicalDocumentTypedExtractionOutput();
    output.extractedJSON = latest.extractedJSON;
    output.typedDrafts = drafts;
    output.typedResult.kind = drafts.kind;
    output.typedResult.title = drafts.displayTitle();
    output.typedResult.summary = drafts.displaySummary();
    output.typedResult.fieldsJSON = latest.extractedJSON;
    output.envelope.memberID = this.selectedMemberID;
    output.envelope.uploadSessionId = latest.uploadSessionId;
    output.envelope.ocrTextPreview = (latest.pipelineOCRText ?? '').substring(0, 400);
    if (this.typeResolution !== undefined) {
      output.envelope.typeResolution = this.typeResolution;
    }
    this.typedOutput = output;
  }

  private static parseTypeResolution(raw: string): MedicalDocumentTypeResolution | undefined {
    try {
      const obj = JSON.parse(raw) as Record<string, Object | string | number>;
      const resolution = new MedicalDocumentTypeResolution();
      resolution.kind = `${obj['kind'] ?? MedicalDocumentKind.MEDICAL_REPORT}` as MedicalDocumentKind;
      resolution.kindLabel = `${obj['kindLabel'] ?? ''}`;
      resolution.sourceLabel = `${obj['sourceLabel'] ?? ''}`;
      resolution.confidence = typeof obj['confidence'] === 'number' ? obj['confidence'] : 0;
      resolution.source = `${obj['source'] ?? ''}`;
      resolution.reason = `${obj['reason'] ?? ''}`;
      return resolution;
    } catch (_e) {
      return undefined;
    }
  }

  private static newSessionId(): string {
    return `med_upload_${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
  }
}
