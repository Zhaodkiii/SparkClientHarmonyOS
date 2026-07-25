import { common } from '@kit.AbilityKit';
import { BackendEnvironment } from './BackendEnvironment';
import { SupportBackend } from '../Core/Networking/SupportBackend';
import { NetworkTransport } from '../Projects/Core/Networking/SupportNetworkTransport';
import { Logger, LoggerConfig } from '../Foundation/Logging/Logger';
import { LogLevel } from '../Foundation/Logging/LogLevel';
import { StartupLogger } from '../Foundation/Logging/StartupLogger';
import { AppSessionStore } from './AppSessionStore';
import { RouteCoordinator } from './RouteCoordinator';
import { NotificationHost } from './NotificationHost';
import { NotificationAssembly } from './Notification/NotificationAssembly';
import { NotificationClient } from '../Projects/Core/Notification/Application/NotificationClient';
import { AccountSessionRuntime } from './AccountSessionRuntime';
import { DeviceCredentialStore } from '../Foundation/Security/DeviceCredentialStore';
import { SessionSnapshotStore } from '../Projects/Features/Auth/Infrastructure/SessionSnapshotStore';
import { DefaultAuthRepository } from '../Projects/Features/Auth/Infrastructure/DefaultAuthRepository';
import { AuthRepository } from '../Projects/Features/Auth/Domain/AuthRepository';
import { RestoreSessionUseCase } from '../Projects/Features/Auth/Application/RestoreSessionUseCase';
import { SignInWithDeviceUseCase } from '../Projects/Features/Auth/Application/SignInWithDeviceUseCase';
import { RequestPhoneOTPUseCase } from '../Projects/Features/Auth/Application/RequestPhoneOTPUseCase';
import { SignInWithPhoneOTPUseCase } from '../Projects/Features/Auth/Application/SignInWithPhoneOTPUseCase';
import { SignOutUseCase } from '../Projects/Features/Auth/Application/SignOutUseCase';
import { LegalAcceptanceStore } from './LegalAcceptanceStore';
import { AppLifecycleCoordinator } from './AppLifecycleCoordinator';
import { SignedInSessionPreparationRegistry } from './SignedInSessionPreparationRegistry';
import { DeviceRegistrationCoordinator } from './DeviceRegistrationCoordinator';
import { AppBootstrapper, AIConfigRepositoryBootstrapGateway } from './AppBootstrapper';
import { AppRelationalDatabase } from '../Core/Storage/AppRelationalDatabase';
import { AppRdbWriteQueue } from '../Core/Storage/AppRdbWriteQueue';
import { AIConfigRdbStore } from '../Core/AI/Infrastructure/AIConfigRdbStore';
import { AIKeyStore } from '../Core/AI/Infrastructure/AIKeyStore';
import { AIConfigResolver } from '../Core/AI/Application/AIConfigResolver';
import { AIConfigRepository } from '../Core/AI/Application/AIConfigRepository';
import { AIRuntimeSnapshotStore } from '../Core/AI/Runtime/AIRuntimeSnapshotStore';
import { AIRuntimeService } from '../Core/AI/Runtime/AIRuntimeService';
import { ChatOrchestrator } from '../Core/AI/Runtime/ChatOrchestrator';
import { ToolHub } from '../Core/AI/Runtime/ToolHub/ToolHub';
import { ChatRepository } from '../Projects/Features/Chat/Infrastructure/ChatRepository';
import { MessageRunActor } from '../Projects/Features/Chat/Application/MessageRunActor';
import { SendChatMessageUseCase } from '../Projects/Features/Chat/Application/SendChatMessageUseCase';
import { CreateThreadUseCase } from '../Projects/Features/Chat/Application/CreateThreadUseCase';
import { RetryFailedMessageUseCase } from '../Projects/Features/Chat/Application/RetryFailedMessageUseCase';
import { ChatRemoteAPI } from '../Projects/Core/Networking/API/AI/ChatRemoteAPI';
import { ChatSyncEngine } from '../Projects/Features/Chat/Infrastructure/ChatSyncEngine';
import { ChatSyncSupervisor } from '../Projects/Features/Chat/Infrastructure/ChatSyncSupervisor';
import { ChatAttachmentPipeline } from '../Projects/Features/Chat/Infrastructure/ChatAttachmentPipeline';
import { ChatAttachmentPreprocessor } from '../Projects/Features/Chat/Infrastructure/ChatAttachmentPreprocessor';
import { HarmonyVisionOCRAdapter } from '../Projects/Features/Chat/Infrastructure/HarmonyVisionOCRAdapter';
import { StructuredRuntimeClient } from '../Core/AI/Runtime/StructuredRuntimeClient';
import { AISettingsKVAdapter } from '../Core/AI/Infrastructure/AISettingsKVAdapter';
import { LocalModelFileService } from '../Core/AI/Infrastructure/LocalModelFileService';
import { AISettingsViewModel } from '../Projects/Features/AISettings/Presentation/AISettingsViewModel';
import { NetworkLogger } from '../Foundation/Logging/NetworkLogger';
import { UserSession } from '../Projects/Core/Domain/Entities/UserSession';
import { SupportSystemInfo } from '../Foundation/SupportSystemInfo';
import { AccountManagementRepository } from '../Projects/Features/AccountManagement/Domain/AccountManagementRepository';
import { DefaultAccountManagementRepository } from '../Projects/Features/AccountManagement/Infrastructure/DefaultAccountManagementRepository';
import { LoadAccountProfileUseCase } from '../Projects/Features/AccountManagement/Application/LoadAccountProfileUseCase';
import { LoadAccountIdentitiesUseCase } from '../Projects/Features/AccountManagement/Application/LoadAccountIdentitiesUseCase';
import { RequestIdentityVerificationUseCase } from '../Projects/Features/AccountManagement/Application/RequestIdentityVerificationUseCase';
import { VerifyIdentityVerificationUseCase } from '../Projects/Features/AccountManagement/Application/VerifyIdentityVerificationUseCase';
import { BindAccountIdentityUseCase } from '../Projects/Features/AccountManagement/Application/BindAccountIdentityUseCase';
import { ChangeAccountIdentityUseCase } from '../Projects/Features/AccountManagement/Application/ChangeAccountIdentityUseCase';
import { RequestTargetOTPUseCase } from '../Projects/Features/AccountManagement/Application/RequestTargetOTPUseCase';
import { RequestAccountVerificationUseCase } from '../Projects/Features/AccountManagement/Application/RequestAccountVerificationUseCase';
import { SubmitAccountDeactivationUseCase } from '../Projects/Features/AccountManagement/Application/SubmitAccountDeactivationUseCase';
import { AccountManagementViewModel } from '../Projects/Features/AccountManagement/Presentation/AccountManagementViewModel';
import { FileCacheRepository } from '../Core/FileStorage/FileCacheRepository';
import { FileCacheManager } from '../Core/FileStorage/FileCacheManager';
import { FileTransferService } from '../Core/FileStorage/FileTransferService';
import { OSSRuntimeConfigStore } from '../Projects/Core/OSS/OSSRuntimeConfigStore';
import { OSSSimpleUploadAdapter } from '../Projects/Core/OSS/OSSSimpleUploadAdapter';
import { OSSMultipartUploadAdapter } from '../Projects/Core/OSS/OSSMultipartUploadAdapter';
import { PreferencesFileUploadCheckpointStore } from '../Core/FileStorage/FileUploadCheckpointStore';
import { SelectedMemberIDStore } from '../Projects/Features/MemberContext/Infrastructure/SelectedMemberIDStore';
import { MemberContextStore } from '../Projects/Features/MemberContext/Presentation/MemberContextStore';
import { LoadHomeMedicalOverviewUseCase } from '../Projects/Features/Home/Application/LoadHomeMedicalOverviewUseCase';
import { MemberModuleSetupUseCase } from '../Projects/Features/Home/Application/MemberModuleSetupUseCase';
import { ManageHomeMemberUseCase } from '../Projects/Features/Home/Application/ManageHomeMemberUseCase';
import { HomeViewModel } from '../Projects/Features/Home/Presentation/HomeViewModel';
import { MemberSetupFlowViewModel } from '../Projects/Features/Home/Presentation/Members/MemberSetup/MemberSetupFlowViewModel';
import { MemberSetupFlowMode } from '../Projects/Features/Home/Presentation/Members/MemberSetup/MemberSetupDraft';
import { Member } from '../Projects/Core/Domain/Entities/Member';
import { LoadMembersUseCase } from '../Projects/Features/MemberContext/Application/LoadMembersUseCase';
import { DefaultMembersRepository } from '../Projects/Features/MemberContext/Infrastructure/DefaultMembersRepository';
import { MedicalDocumentUploadAssembly } from '../Projects/Features/MedicalDocumentUpload/Application/MedicalDocumentUploadAssembly';
import { PreferencesMedicalDocumentUploadCheckpointStore } from '../Projects/Features/MedicalDocumentUpload/Application/MedicalDocumentUploadCheckpointStore';
import { MedicalDocumentUploadViewModel } from '../Projects/Features/MedicalDocumentUpload/Presentation/MedicalDocumentUploadViewModel';

/**
 * ???????? + SupportBackend + Logger + ??/??/???? + Auth ???
 * ???????????
 */
export class AppContainer {
  private static instance?: AppContainer;

  readonly environment: BackendEnvironment;
  readonly backend: SupportBackend;
  readonly sessionStore: AppSessionStore;
  readonly routeCoordinator: RouteCoordinator;
  readonly notificationHost: NotificationHost;
  readonly notificationAssembly: NotificationAssembly;
  readonly deviceCredentials: DeviceCredentialStore;
  readonly snapshotStore: SessionSnapshotStore;
  readonly accountRuntime: AccountSessionRuntime;
  readonly authRepository: AuthRepository;
  readonly restoreSession: RestoreSessionUseCase;
  readonly signInWithDevice: SignInWithDeviceUseCase;
  readonly requestPhoneOTP: RequestPhoneOTPUseCase;
  readonly signInWithPhoneOTP: SignInWithPhoneOTPUseCase;
  readonly signOut: SignOutUseCase;
  readonly legalStore: LegalAcceptanceStore;
  readonly lifecycle: AppLifecycleCoordinator;
  readonly preparationRegistry: SignedInSessionPreparationRegistry;
  readonly deviceRegistration: DeviceRegistrationCoordinator;
  readonly bootstrapper: AppBootstrapper;
  readonly accountManagementRepository: AccountManagementRepository;
  readonly appDatabase: AppRelationalDatabase;
  readonly aiConfigRepository: AIConfigRepository;
  readonly aiRuntimeService: AIRuntimeService;
  readonly chatOrchestrator: ChatOrchestrator;
  readonly chatRepository: ChatRepository;
  readonly messageRunActor: MessageRunActor;
  readonly sendChatMessageUseCase: SendChatMessageUseCase;
  readonly createThreadUseCase: CreateThreadUseCase;
  readonly retryFailedMessageUseCase: RetryFailedMessageUseCase;
  readonly chatRemoteAPI: ChatRemoteAPI;
  readonly chatSyncEngine: ChatSyncEngine;
  readonly chatSyncSupervisor: ChatSyncSupervisor;
  readonly structuredRuntimeClient: StructuredRuntimeClient;
  readonly aiRuntimeSnapshotStore: AIRuntimeSnapshotStore;
  readonly aiKeyStore: AIKeyStore;
  readonly localModelFileService: LocalModelFileService;
  readonly ossRuntimeConfigStore: OSSRuntimeConfigStore;
  readonly fileTransferService: FileTransferService;
  readonly chatAttachmentPipeline: ChatAttachmentPipeline;
  readonly chatAttachmentPreprocessor: ChatAttachmentPreprocessor;
  readonly selectedMemberIDStore: SelectedMemberIDStore;
  readonly memberContextStore: MemberContextStore;
  readonly medicalDocumentUploadCheckpointStore: PreferencesMedicalDocumentUploadCheckpointStore;
  private cachedMedicalDocumentUploadVm?: MedicalDocumentUploadViewModel;

  private constructor(
    environment: BackendEnvironment,
    backend: SupportBackend,
    sessionStore: AppSessionStore,
    routeCoordinator: RouteCoordinator,
    notificationHost: NotificationHost,
    notificationAssembly: NotificationAssembly,
    deviceCredentials: DeviceCredentialStore,
    snapshotStore: SessionSnapshotStore,
    accountRuntime: AccountSessionRuntime,
    authRepository: AuthRepository,
    restoreSession: RestoreSessionUseCase,
    signInWithDevice: SignInWithDeviceUseCase,
    requestPhoneOTP: RequestPhoneOTPUseCase,
    signInWithPhoneOTP: SignInWithPhoneOTPUseCase,
    signOut: SignOutUseCase,
    legalStore: LegalAcceptanceStore,
    lifecycle: AppLifecycleCoordinator,
    preparationRegistry: SignedInSessionPreparationRegistry,
    deviceRegistration: DeviceRegistrationCoordinator,
    bootstrapper: AppBootstrapper,
    accountManagementRepository: AccountManagementRepository,
    appDatabase: AppRelationalDatabase,
    aiConfigRepository: AIConfigRepository,
    aiRuntimeService: AIRuntimeService,
    chatOrchestrator: ChatOrchestrator,
    chatRepository: ChatRepository,
    messageRunActor: MessageRunActor,
    sendChatMessageUseCase: SendChatMessageUseCase,
    createThreadUseCase: CreateThreadUseCase,
    retryFailedMessageUseCase: RetryFailedMessageUseCase,
    chatRemoteAPI: ChatRemoteAPI,
    chatSyncEngine: ChatSyncEngine,
    chatSyncSupervisor: ChatSyncSupervisor,
    structuredRuntimeClient: StructuredRuntimeClient,
    aiRuntimeSnapshotStore: AIRuntimeSnapshotStore,
    aiKeyStore: AIKeyStore,
    localModelFileService: LocalModelFileService,
    ossRuntimeConfigStore: OSSRuntimeConfigStore,
    fileTransferService: FileTransferService,
    chatAttachmentPipeline: ChatAttachmentPipeline,
    chatAttachmentPreprocessor: ChatAttachmentPreprocessor,
    selectedMemberIDStore: SelectedMemberIDStore,
    memberContextStore: MemberContextStore,
    medicalDocumentUploadCheckpointStore: PreferencesMedicalDocumentUploadCheckpointStore
  ) {
    this.environment = environment;
    this.backend = backend;
    this.sessionStore = sessionStore;
    this.routeCoordinator = routeCoordinator;
    this.notificationHost = notificationHost;
    this.notificationAssembly = notificationAssembly;
    this.deviceCredentials = deviceCredentials;
    this.snapshotStore = snapshotStore;
    this.accountRuntime = accountRuntime;
    this.authRepository = authRepository;
    this.restoreSession = restoreSession;
    this.signInWithDevice = signInWithDevice;
    this.requestPhoneOTP = requestPhoneOTP;
    this.signInWithPhoneOTP = signInWithPhoneOTP;
    this.signOut = signOut;
    this.legalStore = legalStore;
    this.lifecycle = lifecycle;
    this.preparationRegistry = preparationRegistry;
    this.deviceRegistration = deviceRegistration;
    this.bootstrapper = bootstrapper;
    this.accountManagementRepository = accountManagementRepository;
    this.appDatabase = appDatabase;
    this.aiConfigRepository = aiConfigRepository;
    this.aiRuntimeService = aiRuntimeService;
    this.chatOrchestrator = chatOrchestrator;
    this.chatRepository = chatRepository;
    this.messageRunActor = messageRunActor;
    this.sendChatMessageUseCase = sendChatMessageUseCase;
    this.createThreadUseCase = createThreadUseCase;
    this.retryFailedMessageUseCase = retryFailedMessageUseCase;
    this.chatRemoteAPI = chatRemoteAPI;
    this.chatSyncEngine = chatSyncEngine;
    this.chatSyncSupervisor = chatSyncSupervisor;
    this.structuredRuntimeClient = structuredRuntimeClient;
    this.aiRuntimeSnapshotStore = aiRuntimeSnapshotStore;
    this.aiKeyStore = aiKeyStore;
    this.localModelFileService = localModelFileService;
    this.ossRuntimeConfigStore = ossRuntimeConfigStore;
    this.fileTransferService = fileTransferService;
    this.chatAttachmentPipeline = chatAttachmentPipeline;
    this.chatAttachmentPreprocessor = chatAttachmentPreprocessor;
    this.selectedMemberIDStore = selectedMemberIDStore;
    this.memberContextStore = memberContextStore;
    this.medicalDocumentUploadCheckpointStore = medicalDocumentUploadCheckpointStore;
  }

  /** ?? iOS AppContainer.toolHub?? Orchestrator ??????? */
  get toolHub(): ToolHub {
    return this.chatOrchestrator.hub;
  }

  createAccountManagementViewModel(): AccountManagementViewModel {
    const repo = this.accountManagementRepository;
    return new AccountManagementViewModel(
      new LoadAccountProfileUseCase(repo),
      new LoadAccountIdentitiesUseCase(repo),
      new RequestIdentityVerificationUseCase(repo),
      new VerifyIdentityVerificationUseCase(repo),
      new BindAccountIdentityUseCase(repo),
      new ChangeAccountIdentityUseCase(repo),
      new RequestTargetOTPUseCase(repo),
      new RequestAccountVerificationUseCase(repo),
      new SubmitAccountDeactivationUseCase(repo),
      this.signOut,
      this.sessionStore,
      this.notificationClient
    );
  }

  private cachedAISettingsVm?: AISettingsViewModel;
  private cachedAISettingsAccountId: number = -1;

  createAISettingsViewModel(): AISettingsViewModel {
    const aid = this.accountRuntime.activeAccountId ?? 0;
    if (this.cachedAISettingsVm && this.cachedAISettingsAccountId === aid) {
      return this.cachedAISettingsVm;
    }
    this.cachedAISettingsVm = new AISettingsViewModel(
      this.aiConfigRepository,
      this.backend.aiConfig,
      this.aiKeyStore,
      this.accountRuntime,
      this.notificationClient
    );
    this.cachedAISettingsAccountId = aid;
    return this.cachedAISettingsVm;
  }

  clearAISettingsViewModelCache(): void {
    this.cachedAISettingsVm = undefined;
    this.cachedAISettingsAccountId = -1;
  }

  private cachedHomeVm?: HomeViewModel;
  private cachedHomeAccountId: number = -1;

  createHomeViewModel(): HomeViewModel {
    const aid = this.accountRuntime.activeAccountId ?? 0;
    if (this.cachedHomeVm && this.cachedHomeAccountId === aid) {
      return this.cachedHomeVm;
    }
    this.cachedHomeVm = new HomeViewModel(
      this.sessionStore,
      new LoadHomeMedicalOverviewUseCase(this.backend.medicalQuery, this.selectedMemberIDStore),
      new MemberModuleSetupUseCase(this.backend.medicalQuery),
      new LoadMembersUseCase(new DefaultMembersRepository(this.backend.medicalQuery)),
      this.memberContextStore,
      this.notificationClient
    );
    this.cachedHomeAccountId = aid;
    return this.cachedHomeVm;
  }

  clearHomeViewModelCache(): void {
    this.cachedHomeVm = undefined;
    this.cachedHomeAccountId = -1;
  }

  /** ?? iOS AppContainer ??????? ViewModel ????? */
  createMedicalDocumentUploadViewModel(): MedicalDocumentUploadViewModel {
    if (!this.cachedMedicalDocumentUploadVm) {
      this.cachedMedicalDocumentUploadVm = MedicalDocumentUploadAssembly.makeViewModel(
        this.memberContextStore,
        this.fileTransferService,
        (): number | undefined => this.accountRuntime.activeAccountId,
        (): number => this.sessionStore.generation,
        this.notificationClient,
        this.medicalDocumentUploadCheckpointStore,
        this.localModelFileService.applicationFilesDir(),
        this.aiRuntimeService,
        this.backend.medicalWorkflow,
        this.backend.medicalCombinedCreate
      );
    }
    return this.cachedMedicalDocumentUploadVm;
  }

  clearMedicalDocumentUploadViewModel(): void {
    this.cachedMedicalDocumentUploadVm = undefined;
  }

  createMemberSetupFlowViewModel(mode: MemberSetupFlowMode, maintainMember?: Member): MemberSetupFlowViewModel {
    return new MemberSetupFlowViewModel(
      mode,
      new ManageHomeMemberUseCase(this.backend.medicalMember),
      new MemberModuleSetupUseCase(this.backend.medicalQuery),
      maintainMember
    );
  }

  get notificationClient(): NotificationClient {
    return this.notificationAssembly.client;
  }

  static live(context: common.Context, environment?: BackendEnvironment, transport?: NetworkTransport): AppContainer {
    if (AppContainer.instance) {
      return AppContainer.instance;
    }
    const env = environment ?? BackendEnvironment.current();
    const logConfig = new LoggerConfig();
    logConfig.minLevel = env.diagnosticsEnabled ? LogLevel.DEBUG : LogLevel.INFO;
    Logger.configure(logConfig);
    const netLogger = new NetworkLogger(env.diagnosticsEnabled ? LogLevel.DEBUG : LogLevel.INFO);
    const backend = new SupportBackend(env, context, transport);
    backend.startNetworkMonitor();

    const filesDir = context.filesDir;
    const deviceCredentials = new DeviceCredentialStore(filesDir, netLogger);
    const snapshotStore = new SessionSnapshotStore(filesDir, netLogger);
    const accountRuntime = new AccountSessionRuntime(snapshotStore);
    const authRepository = new DefaultAuthRepository(
      backend.auth,
      backend.otp,
      backend.tokenProvider(),
      deviceCredentials,
      snapshotStore,
      accountRuntime,
      netLogger
    );
    const restoreSession = new RestoreSessionUseCase(authRepository);
    const signInWithDevice = new SignInWithDeviceUseCase(authRepository);
    const requestPhoneOTP = new RequestPhoneOTPUseCase(authRepository);
    const signInWithPhoneOTP = new SignInWithPhoneOTPUseCase(authRepository);
    const signOut = new SignOutUseCase(authRepository);
    const legalStore = new LegalAcceptanceStore(context);

    const preparationRegistry = new SignedInSessionPreparationRegistry();
    const deviceRegistration = new DeviceRegistrationCoordinator(
      backend.device,
      deviceCredentials,
      new SupportSystemInfo(),
      backend.deviceCache
    );
    const writeQueue = new AppRdbWriteQueue();
    const appDatabase = new AppRelationalDatabase(context, writeQueue);
    const aiStore = new AIConfigRdbStore(appDatabase);
    const aiKeyStore = new AIKeyStore(filesDir);
    const aiRuntimeSnapshotStore = new AIRuntimeSnapshotStore();
    const aiResolver = new AIConfigResolver();
    const aiConfigRepository = new AIConfigRepository(
      aiStore,
      aiKeyStore,
      backend.aiConfig,
      aiResolver,
      aiRuntimeSnapshotStore,
      accountRuntime,
      new AISettingsKVAdapter(),
      context
    );
    const aiRuntimeService = new AIRuntimeService(aiRuntimeSnapshotStore, aiKeyStore, accountRuntime);
    const chatRepository = new ChatRepository(appDatabase);
    const messageRunActor = new MessageRunActor(chatRepository);
    const toolHub = new ToolHub();
    toolHub.configureAuditPersistence(async (event) => {
      const accountId = event.accountId > 0 ? event.accountId : accountRuntime.activeAccountId;
      if (accountId !== undefined) {
        await chatRepository.persistAudit(accountId, event.id, event.threadId, event.requestId,
          event.toolName, event.status, event.inputSummary, event.outputSummary, event.memberID, event.createdAt);
      }
    });
    const chatOrchestrator = new ChatOrchestrator(aiRuntimeService, toolHub);
    const localModelFileService = new LocalModelFileService(filesDir);
    const ossRuntimeConfigStore = new OSSRuntimeConfigStore(backend.oss);
    const fileCacheRepository = new FileCacheRepository(appDatabase);
    const fileCacheManager = new FileCacheManager(filesDir, fileCacheRepository);
    const simpleUploadAdapter = new OSSSimpleUploadAdapter();
    const multipartUploadAdapter = new OSSMultipartUploadAdapter();
    const sessionStore = new AppSessionStore();
    const multipartCheckpointStore = new PreferencesFileUploadCheckpointStore(context);
    const fileTransferService = new FileTransferService(
      backend.files,
      ossRuntimeConfigStore,
      simpleUploadAdapter,
      multipartUploadAdapter,
      fileCacheManager,
      (): number | undefined => accountRuntime.activeAccountId,
      (): number => sessionStore.generation,
      multipartCheckpointStore
    );
    const bootstrapper = new AppBootstrapper(
      new AIConfigRepositoryBootstrapGateway(aiConfigRepository),
      ossRuntimeConfigStore,
      fileTransferService
    );

    sessionStore.configure(restoreSession, accountRuntime);

    const lifecycle = new AppLifecycleCoordinator(
      backend,
      sessionStore,
      accountRuntime,
      preparationRegistry,
      deviceRegistration,
      bootstrapper,
      fileTransferService
    );

    const routeCoordinator = new RouteCoordinator(sessionStore, lifecycle);
    routeCoordinator.start();

    const notificationAssembly = new NotificationAssembly(filesDir);
    const selectedMemberIDStore = new SelectedMemberIDStore(context);
    const memberContextStore = new MemberContextStore(selectedMemberIDStore);
    const medicalDocumentUploadCheckpointStore = new PreferencesMedicalDocumentUploadCheckpointStore(context);
    const chatRemoteAPI = new ChatRemoteAPI(backend.configuration);
    const chatAttachmentPipeline = new ChatAttachmentPipeline(
      chatRepository,
      fileTransferService,
      (): number | undefined => accountRuntime.activeAccountId,
      (): number => sessionStore.generation
    );
    const chatAttachmentPreprocessor = new ChatAttachmentPreprocessor(
      fileTransferService,
      (): number | undefined => accountRuntime.activeAccountId,
      (): number => sessionStore.generation,
      new HarmonyVisionOCRAdapter()
    );
    const retryFailedMessageUseCase = new RetryFailedMessageUseCase(chatRepository);
    const chatSyncEngine = new ChatSyncEngine(
      chatRepository,
      chatRemoteAPI,
      accountRuntime,
      backend.tokenProvider(),
      env.apiBaseURL,
      chatAttachmentPipeline
    );
    const chatSyncSupervisor = new ChatSyncSupervisor(chatSyncEngine);
    const createThreadUseCase = new CreateThreadUseCase(
      chatRepository,
      aiConfigRepository,
      memberContextStore
    );
    const sendChatMessageUseCase = new SendChatMessageUseCase(
      chatRepository,
      chatOrchestrator,
      messageRunActor,
      aiConfigRepository,
      createThreadUseCase,
      memberContextStore
    );
    const structuredRuntimeClient = new StructuredRuntimeClient(aiRuntimeService);

    sessionStore.setOnSignedIn((session: UserSession) => {
      lifecycle.onSessionEnteredSignedIn(session);
      void chatSyncSupervisor.startRealtimeSync();
    });

    accountRuntime.setOnAccountDataCleared(async (reason: string) => {
      await chatSyncSupervisor.stopRealtimeSync();
      await notificationAssembly.clearForAccountChange();
      AppContainer.instance?.clearAISettingsViewModelCache();
      AppContainer.instance?.clearHomeViewModelCache();
      AppContainer.instance?.clearMedicalDocumentUploadViewModel();
      const aid = accountRuntime.activeAccountId;
      if (aid !== undefined) {
        try {
          await memberContextStore.clearForAccount(aid);
        } catch (_e) {
          // ?????????/??
        }
        aiRuntimeService.invalidateAccount(aid);
        messageRunActor.bumpGeneration();
        try {
          await chatRepository.deleteAccountData(aid);
        } catch (_e) {
          // ?????????/??
        }
        try {
          await fileTransferService.clearAccount(aid);
        } catch (_e) {
          // ?????????/??
        }
        try {
          await medicalDocumentUploadCheckpointStore.clearForAccount(aid);
        } catch (_e) {
          // ?????????/??
        }
        if (reason === 'signOut') {
          await aiConfigRepository.deleteAccountData(aid);
        }
      } else {
        aiRuntimeSnapshotStore.clear();
        fileTransferService.resetRuntimeCredentials();
      }
    });
    const notificationHost = new NotificationHost();
    notificationHost.bindClient(notificationAssembly.client);

    const accountManagementRepository = new DefaultAccountManagementRepository(backend, deviceCredentials);

    AppContainer.instance = new AppContainer(
      env,
      backend,
      sessionStore,
      routeCoordinator,
      notificationHost,
      notificationAssembly,
      deviceCredentials,
      snapshotStore,
      accountRuntime,
      authRepository,
      restoreSession,
      signInWithDevice,
      requestPhoneOTP,
      signInWithPhoneOTP,
      signOut,
      legalStore,
      lifecycle,
      preparationRegistry,
      deviceRegistration,
      bootstrapper,
      accountManagementRepository,
      appDatabase,
      aiConfigRepository,
      aiRuntimeService,
      chatOrchestrator,
      chatRepository,
      messageRunActor,
      sendChatMessageUseCase,
      createThreadUseCase,
      retryFailedMessageUseCase,
      chatRemoteAPI,
      chatSyncEngine,
      chatSyncSupervisor,
      structuredRuntimeClient,
      aiRuntimeSnapshotStore,
      aiKeyStore,
      localModelFileService,
      ossRuntimeConfigStore,
      fileTransferService,
      chatAttachmentPipeline,
      chatAttachmentPreprocessor,
      selectedMemberIDStore,
      memberContextStore,
      medicalDocumentUploadCheckpointStore
    );
    StartupLogger.appContainerReady();
    // ????? lifecycle ??? satisfied ?????????? restore
    lifecycle.start();
    return AppContainer.instance;
  }

  static shared(): AppContainer | undefined {
    return AppContainer.instance;
  }

  shutdown(): void {
    this.lifecycle.stop();
    this.routeCoordinator.stop();
    this.backend.stopNetworkMonitor();
  }

  /** ???????? */
  static resetForTests(): void {
    if (AppContainer.instance) {
      AppContainer.instance.shutdown();
    }
    AppContainer.instance = undefined;
    Logger.resetForTests();
  }
}
