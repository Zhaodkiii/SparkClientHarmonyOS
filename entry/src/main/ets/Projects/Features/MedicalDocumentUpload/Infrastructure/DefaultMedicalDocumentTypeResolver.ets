import { AIRuntimeCancellationToken } from '../../../../Core/AI/Runtime/AIRuntimeCancellation';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import {
  MedicalDocumentTypeResolutionFactory,
  MedicalDocumentTypeResolving
} from '../Domain/MedicalDocumentTypeResolverProtocol';
import { MedicalDocumentTypeResolution } from '../Domain/MedicalDocumentTypedModels';
import { LocalMedicalDocumentTypeResolver } from './LocalMedicalDocumentTypeResolver';
import { MedicalDocumentTypeAIClient } from './MedicalDocumentTypeAIClient';

/**
 * 默认类型判定：manual → localRules → AI → ai_fallback_default。
 * 对齐 iOS DefaultMedicalDocumentTypeResolver。
 */
export class DefaultMedicalDocumentTypeResolver implements MedicalDocumentTypeResolving {
  private readonly localResolver: LocalMedicalDocumentTypeResolver;
  private readonly aiClient?: MedicalDocumentTypeAIClient;

  constructor(
    localResolver: LocalMedicalDocumentTypeResolver = new LocalMedicalDocumentTypeResolver(),
    aiClient?: MedicalDocumentTypeAIClient
  ) {
    this.localResolver = localResolver;
    this.aiClient = aiClient;
  }

  async resolve(
    selectedKind: MedicalDocumentKind,
    mergedOCRText: string,
    cancellationToken?: AIRuntimeCancellationToken
  ): Promise<MedicalDocumentTypeResolution> {
    if (selectedKind !== MedicalDocumentKind.AUTO) {
      this.log('manual', selectedKind);
      return MedicalDocumentTypeResolutionFactory.manual(selectedKind);
    }

    const trimmed = mergedOCRText.trim();
    if (trimmed.length === 0) {
      throw new Error('OCR 文本为空，无法识别类型');
    }

    const local = this.localResolver.resolveAutoOnly(trimmed);
    if (local !== undefined) {
      this.log('localRules', local.kind);
      return local;
    }

    cancellationToken?.checkCancellation();
    if (this.aiClient !== undefined) {
      const ai = await this.aiClient.recognize(trimmed, cancellationToken);
      if (ai !== undefined) {
        this.log('ai', ai.kind);
        return ai;
      }
    }

    this.log('ai_fallback_default', MedicalDocumentKind.MEDICAL_REPORT);
    return MedicalDocumentTypeResolutionFactory.aiFallbackDefault();
  }

  private log(source: string, kind: MedicalDocumentKind): void {
    const fields = new LogFields();
    fields.operation = 'medical_document_type_default';
    fields.detail = `source=${source};kind=${kind}`;
    Logger.info('medical.upload.type.resolved', LogModule.HOME, fields);
  }
}
