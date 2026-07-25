import { AIRuntimeCancellationToken } from '../../../../Core/AI/Runtime/AIRuntimeCancellation';
import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import { MedicalDocumentTypeResolving } from '../Domain/MedicalDocumentTypeResolverProtocol';
import { MedicalDocumentTypeResolution } from '../Domain/MedicalDocumentTypedModels';
import { DefaultMedicalDocumentTypeResolver } from '../Infrastructure/DefaultMedicalDocumentTypeResolver';

/**
 * 类型识别用例：manual → localRules → AI → ai_fallback_default。
 */
export class ResolveMedicalDocumentTypeUseCase {
  private readonly resolver: MedicalDocumentTypeResolving;

  constructor(resolver: MedicalDocumentTypeResolving = new DefaultMedicalDocumentTypeResolver()) {
    this.resolver = resolver;
  }

  async execute(
    selectedKind: MedicalDocumentKind,
    mergedOCRText: string,
    cancellationToken?: AIRuntimeCancellationToken
  ): Promise<MedicalDocumentTypeResolution> {
    return await this.resolver.resolve(selectedKind, mergedOCRText, cancellationToken);
  }
}
