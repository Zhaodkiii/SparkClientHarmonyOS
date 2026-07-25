import { common } from '@kit.AbilityKit';
import { BackendEnvironment } from '../../App/BackendEnvironment';
import { NetworkLogger, LogLevel } from '../../Foundation/Logging/NetworkLogger';
import { SecureTokenStore } from '../../Foundation/Security/SecureTokenStore';
import { NetworkPathMonitor } from '../../Foundation/NetworkPathMonitor';
import { SupportNetworkTransport, NetworkTransport } from '../../Projects/Core/Networking/SupportNetworkTransport';
import { SupportNetworkEngine } from '../../Projects/Core/Networking/SupportNetworkEngine';
import { SupportBackendConfiguration } from '../../Projects/Core/Networking/SupportBackendConfiguration';
import { AuthTokenProvider } from '../../Projects/Core/Networking/AuthTokenProvider';
import { DeviceCache } from '../../Projects/Core/Networking/Caching/DeviceCache';
import { ETagStore } from '../../Projects/Core/Networking/ETagStore';
import { AuthAPI } from '../../Projects/Core/Networking/API/Auth/AuthAPI';
import { OTPAPI } from '../../Projects/Core/Networking/API/Auth/OTPAPI';
import { AIConfigAPI } from '../../Projects/Core/Networking/API/AI/AIConfigAPI';
import { AccountIdentityAPI } from '../../Projects/Core/Networking/API/Account/AccountIdentityAPI';
import { DeactivationAPI } from '../../Projects/Core/Networking/API/Account/DeactivationAPI';
import { SupportOCRAPI } from './SupportAPIs';
import { FileAPI } from '../../Projects/Core/Networking/API/File/FileAPI';
import { OSSAPI } from '../../Projects/Core/Networking/API/OSS/OSSAPI';
import { DeviceAPI } from '../../Projects/Core/Networking/API/Device/DeviceAPI';
import { SessionInvalidation } from '../../Projects/Core/Networking/SessionInvalidation';
import { SparkMedicalQueryAPI } from '../../Projects/Core/Networking/API/Medical/MedicalQueryAPI';
import { SparkMedicalWorkflowAPI } from '../../Projects/Core/Networking/API/Medical/MedicalWorkflowAPI';
import { SparkMedicalMemberAPI } from '../../Projects/Core/Networking/API/Medical/MedicalMemberAPI';
import { SparkMedicalMemberInviteAPI } from '../../Projects/Core/Networking/API/Medical/MedicalMemberAPI+Invite';
import { SparkMedicalMemberShareAPI } from '../../Projects/Core/Networking/API/Medical/MedicalMemberAPI+Share';
import { SparkMedicalShareAPI } from '../../Projects/Core/Networking/API/Medical/MedicalShareAPI';
import { SparkCombinedMedicalCreateAPI } from '../../Projects/Core/Networking/API/Medical/CombinedMedicalCreateAPI';
import { SparkMedicalExamArchiveAPI } from '../../Projects/Core/Networking/API/Medical/MedicalExamArchiveAPI';

/**
 * 唯一应用级网络组合根。页面不得自行 new Transport。
 */
export class SupportBackend {
  readonly environment: BackendEnvironment;
  readonly configuration: SupportBackendConfiguration;
  readonly engine: SupportNetworkEngine;
  readonly deviceCache: DeviceCache;
  readonly networkPathMonitor: NetworkPathMonitor;
  readonly auth: AuthAPI;
  readonly otp: OTPAPI;
  readonly device: DeviceAPI;
  readonly files: FileAPI;
  readonly oss: OSSAPI;
  readonly ocr: SupportOCRAPI;
  readonly aiConfig: AIConfigAPI;
  readonly accountIdentity: AccountIdentityAPI;
  readonly deactivation: DeactivationAPI;
  readonly medicalQuery: SparkMedicalQueryAPI;
  readonly medicalWorkflow: SparkMedicalWorkflowAPI;
  readonly medicalMember: SparkMedicalMemberAPI;
  readonly medicalInvite: SparkMedicalMemberInviteAPI;
  readonly medicalMemberShare: SparkMedicalMemberShareAPI;
  readonly medicalShare: SparkMedicalShareAPI;
  readonly medicalCombinedCreate: SparkCombinedMedicalCreateAPI;
  readonly medicalExamArchive: SparkMedicalExamArchiveAPI;

  constructor(
    environment: BackendEnvironment,
    context: common.Context,
    transportOverride?: NetworkTransport
  ) {
    this.environment = environment;
    const logger = new NetworkLogger(environment.diagnosticsEnabled ? LogLevel.DEBUG : LogLevel.INFO);
    const deviceCache = new DeviceCache(context, logger);
    const tokenStore = new SecureTokenStore(context.filesDir, logger);
    const transport = transportOverride ?? new SupportNetworkTransport(logger);
    const authProvider = new AuthTokenProvider(transport, environment.apiBaseURL, tokenStore, logger);
    const etagStore = new ETagStore(context.filesDir, logger);
    const engine = new SupportNetworkEngine(
      environment.apiBaseURL,
      transport,
      authProvider,
      etagStore,
      deviceCache,
      logger,
      undefined,
      undefined,
      environment.defaultTimeoutMs
    );
    const configuration = new SupportBackendConfiguration(engine, deviceCache, undefined, logger);
    this.deviceCache = deviceCache;
    this.engine = engine;
    this.configuration = configuration;
    this.networkPathMonitor = new NetworkPathMonitor(logger);
    this.auth = new AuthAPI(configuration);
    this.otp = new OTPAPI(configuration);
    this.device = new DeviceAPI(configuration);
    this.files = new FileAPI(configuration);
    this.oss = new OSSAPI(configuration);
    this.ocr = new SupportOCRAPI(configuration);
    this.aiConfig = new AIConfigAPI(configuration);
    this.accountIdentity = new AccountIdentityAPI(configuration);
    this.deactivation = new DeactivationAPI(configuration);
    // 共享单一 Workflow 实例，避免 Query/Member 各自再 new
    this.medicalWorkflow = new SparkMedicalWorkflowAPI(configuration);
    this.medicalQuery = new SparkMedicalQueryAPI(configuration, this.medicalWorkflow);
    this.medicalMember = new SparkMedicalMemberAPI(configuration, this.medicalWorkflow);
    this.medicalInvite = new SparkMedicalMemberInviteAPI(configuration);
    this.medicalMemberShare = new SparkMedicalMemberShareAPI(configuration);
    this.medicalShare = new SparkMedicalShareAPI(configuration);
    this.medicalCombinedCreate = new SparkCombinedMedicalCreateAPI(configuration);
    this.medicalExamArchive = new SparkMedicalExamArchiveAPI(configuration);

    SessionInvalidation.subscribe((_source: string) => {
      authProvider.clearTokens().catch(() => {
        // ignore
      });
      etagStore.clearAccount(deviceCache.getAccountScope());
      deviceCache.clearAllNonSensitive().catch(() => {
        // ignore
      });
    });

    logger.info(`SupportBackend initialized env=${environment.kind} base=${environment.apiBaseURL}`);
  }

  tokenProvider(): AuthTokenProvider {
    return this.engine.tokenProvider();
  }

  startNetworkMonitor(): void {
    this.networkPathMonitor.start();
  }

  stopNetworkMonitor(): void {
    this.networkPathMonitor.stop();
  }
}
