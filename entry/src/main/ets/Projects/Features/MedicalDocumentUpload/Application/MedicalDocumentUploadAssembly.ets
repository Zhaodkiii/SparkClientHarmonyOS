import { FileTransferService } from '../../../../Core/FileStorage/FileTransferService';
import { AIRuntimeService } from '../../../../Core/AI/Runtime/AIRuntimeService';
import { PromptLocalizer } from '../../../../Core/AI/Runtime/PromptLocalizer';
import { SparkCombinedMedicalCreateAPI } from '../../../Core/Networking/API/Medical/CombinedMedicalCreateAPI';
import { SparkMedicalWorkflowAPI } from '../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { NotificationClient } from '../../../Core/Notification/Application/NotificationClient';
import { OCRConfiguration } from '../../../Core/OCR/OCRModels';
import { OCROrchestrator } from '../../../Core/OCR/OCROrchestrator';
import { MedicalDocumentAttachmentUploader } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MemberContextStore } from '../../MemberContext/Presentation/MemberContextStore';
import {
  MedicalDocumentUploadCapabilities
} from '../Domain/MedicalDocumentUploadModels';
import { MedicalPreSubmitValidator } from '../Domain/MedicalPreSubmitValidator';
import { TypedMedicalDocumentSaving } from '../Domain/TypedMedicalDocumentSaving';
import { DefaultMedicalDocumentTypeResolver } from '../Infrastructure/DefaultMedicalDocumentTypeResolver';
import { DefaultTypedMedicalDocumentSaver } from '../Infrastructure/DefaultTypedMedicalDocumentSaver';
import { HarmonyMedicalDocumentOCRAdapter } from '../Infrastructure/HarmonyMedicalDocumentOCRAdapter';
import { LocalMedicalDocumentTypeResolver } from '../Infrastructure/LocalMedicalDocumentTypeResolver';
import { MedicalDocumentExtractionErrorNormalizer } from '../Infrastructure/MedicalDocumentExtractionErrorNormalizer';
import { MedicalDocumentStructuredJSONDecoder } from '../Infrastructure/MedicalDocumentStructuredJSONDecoder';
import { MedicalDocumentStructuredPromptFactory } from '../Infrastructure/MedicalDocumentStructuredPromptFactory';
import { MedicalDocumentStructuredRuntimeClient } from '../Infrastructure/MedicalDocumentStructuredRuntimeClient';
import { MedicalDocumentTypeAIClient } from '../Infrastructure/MedicalDocumentTypeAIClient';
import { MedicalDocumentUploadViewModel } from '../Presentation/MedicalDocumentUploadViewModel';
import { DefaultMedicalDocumentAttachmentBinder } from '../Infrastructure/DefaultMedicalDocumentAttachmentBinder';
import {
  MedicalDocumentAttachmentBinding
} from '../Domain/MedicalDocumentAttachmentBindingModels';
import { BindUploadedFilesToMedicalBusinessUseCase } from './BindUploadedFilesToMedicalBusinessUseCase';
import { ExtractTypedMedicalDocumentUseCase } from './ExtractTypedMedicalDocumentUseCase';
import { MedicalDocumentOCRUseCase } from './MedicalDocumentOCRUseCase';
import {
  InMemoryMedicalDocumentUploadCheckpointStore,
  MedicalDocumentUploadCheckpointStore
} from './MedicalDocumentUploadCheckpointStore';
import { ResolveMedicalDocumentTypeUseCase } from './ResolveMedicalDocumentTypeUseCase';
import { SaveTypedMedicalDocumentUseCase } from './SaveTypedMedicalDocumentUseCase';
import { UploadMedicalDocumentFilesUseCase } from './UploadMedicalDocumentFilesUseCase';

/** Assembly 依赖槽位。saver / workflow API 注入后开启 capabilities.save。 */
export class MedicalDocumentUploadDependencies {
  memberContextStore?: MemberContextStore;
  fileTransferService?: FileTransferService;
  activeAccountIdProvider?: () => number | undefined;
  sessionGenerationProvider?: () => number;
  notificationClient?: NotificationClient;
  checkpointStore?: MedicalDocumentUploadCheckpointStore;
  ocrOrchestrator?: OCROrchestrator;
  ocrUseCase?: MedicalDocumentOCRUseCase;
  resolveTypeUseCase?: ResolveMedicalDocumentTypeUseCase;
  extractUseCase?: ExtractTypedMedicalDocumentUseCase;
  aiRuntimeService?: AIRuntimeService;
  promptLocalizer?: PromptLocalizer;
  typeResolver?: Object;
  extractor?: Object;
  saver?: TypedMedicalDocumentSaving;
  workflowAPI?: SparkMedicalWorkflowAPI;
  combinedCreateAPI?: SparkCombinedMedicalCreateAPI;
  attachmentBinder?: MedicalDocumentAttachmentBinding;
  ocrCacheDir?: string;
}

/**
 * 上传功能装配：上传 + OCR + 类型判定 + 结构化抽取 + capability + 断点。
 * 有 AIRuntime 时打开 extraction；保存未注入时 capability.save 仍为 false。
 */
export class MedicalDocumentUploadAssembly {
  static makeViewModelFromDeps(deps: MedicalDocumentUploadDependencies): MedicalDocumentUploadViewModel {
    const memberContextStore = deps.memberContextStore;
    const fileTransferService = deps.fileTransferService;
    const activeAccountIdProvider = deps.activeAccountIdProvider;
    const sessionGenerationProvider = deps.sessionGenerationProvider;
    if (!memberContextStore || !fileTransferService || !activeAccountIdProvider || !sessionGenerationProvider) {
      throw new Error('medicalDocumentUploadDependenciesInvalid');
    }
    const uploader = new MedicalDocumentAttachmentUploader(
      fileTransferService,
      activeAccountIdProvider,
      sessionGenerationProvider
    );
    const uploadFilesUseCase = new UploadMedicalDocumentFilesUseCase(uploader);

    let ocrOrchestrator = deps.ocrOrchestrator;
    if (ocrOrchestrator === undefined) {
      const config = new OCRConfiguration();
      config.cacheDir = deps.ocrCacheDir ?? '';
      ocrOrchestrator = new OCROrchestrator(config);
    }
    const ocrUseCase = deps.ocrUseCase ??
      new MedicalDocumentOCRUseCase(new HarmonyMedicalDocumentOCRAdapter(ocrOrchestrator));

    const promptLocalizer = deps.promptLocalizer ?? new PromptLocalizer();

    let resolveTypeUseCase = deps.resolveTypeUseCase;
    if (resolveTypeUseCase === undefined) {
      const localResolver = new LocalMedicalDocumentTypeResolver();
      let aiClient: MedicalDocumentTypeAIClient | undefined = undefined;
      if (deps.aiRuntimeService !== undefined) {
        aiClient = new MedicalDocumentTypeAIClient(
          deps.aiRuntimeService,
          activeAccountIdProvider,
          promptLocalizer
        );
      }
      resolveTypeUseCase = new ResolveMedicalDocumentTypeUseCase(
        new DefaultMedicalDocumentTypeResolver(localResolver, aiClient)
      );
    }

    let extractUseCase = deps.extractUseCase;
    if (extractUseCase === undefined) {
      if (deps.aiRuntimeService !== undefined) {
        extractUseCase = new ExtractTypedMedicalDocumentUseCase(
          ocrUseCase,
          resolveTypeUseCase,
          new MedicalDocumentStructuredPromptFactory(promptLocalizer),
          new MedicalDocumentStructuredRuntimeClient(deps.aiRuntimeService, activeAccountIdProvider),
          new MedicalDocumentStructuredJSONDecoder(),
          new MedicalDocumentExtractionErrorNormalizer()
        );
      } else {
        extractUseCase = new ExtractTypedMedicalDocumentUseCase(ocrUseCase, resolveTypeUseCase);
      }
    }

    const attachmentBinder = deps.attachmentBinder ??
      new DefaultMedicalDocumentAttachmentBinder(fileTransferService, sessionGenerationProvider);
    const bindFilesUseCase = new BindUploadedFilesToMedicalBusinessUseCase(attachmentBinder);

    let saver = deps.saver;
    if (saver === undefined && deps.workflowAPI !== undefined && deps.combinedCreateAPI !== undefined) {
      saver = new DefaultTypedMedicalDocumentSaver(deps.workflowAPI, deps.combinedCreateAPI);
    }
    const saveUseCase = saver !== undefined ? new SaveTypedMedicalDocumentUseCase(saver) : undefined;

    const capabilities = new MedicalDocumentUploadCapabilities();
    capabilities.upload = true;
    capabilities.ocr = true;
    capabilities.typeRecognition = true;
    capabilities.extraction = extractUseCase.isExtractionReady ||
      deps.extractor !== undefined ||
      saver !== undefined;
    capabilities.attachmentBinding = true;
    capabilities.save = saveUseCase !== undefined;

    return new MedicalDocumentUploadViewModel(
      memberContextStore,
      uploadFilesUseCase,
      deps.notificationClient,
      sessionGenerationProvider,
      capabilities,
      deps.checkpointStore ?? new InMemoryMedicalDocumentUploadCheckpointStore(),
      activeAccountIdProvider,
      ocrUseCase,
      resolveTypeUseCase,
      extractUseCase,
      new MedicalPreSubmitValidator(),
      bindFilesUseCase,
      saveUseCase
    );
  }

  /** 兼容 AppContainer 既有调用签名。 */
  static makeViewModel(
    memberContextStore: MemberContextStore,
    fileTransferService: FileTransferService,
    getAccountID: () => number | undefined,
    getGeneration: () => number,
    notification?: NotificationClient,
    checkpointStore?: MedicalDocumentUploadCheckpointStore,
    ocrCacheDir?: string,
    aiRuntimeService?: AIRuntimeService,
    workflowAPI?: SparkMedicalWorkflowAPI,
    combinedCreateAPI?: SparkCombinedMedicalCreateAPI
  ): MedicalDocumentUploadViewModel {
    const deps = new MedicalDocumentUploadDependencies();
    deps.memberContextStore = memberContextStore;
    deps.fileTransferService = fileTransferService;
    deps.activeAccountIdProvider = getAccountID;
    deps.sessionGenerationProvider = getGeneration;
    deps.notificationClient = notification;
    deps.checkpointStore = checkpointStore;
    deps.ocrCacheDir = ocrCacheDir;
    deps.aiRuntimeService = aiRuntimeService;
    deps.workflowAPI = workflowAPI;
    deps.combinedCreateAPI = combinedCreateAPI;
    return MedicalDocumentUploadAssembly.makeViewModelFromDeps(deps);
  }
}
