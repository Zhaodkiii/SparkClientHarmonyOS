import { normalizeProviderId } from './AIConfigModels';

/** 本地 GGUF Provider 稳定 ID */
export const LOCAL_PROVIDER_ID: string = 'local:device';

export const LOCAL_COMPANY: string = 'LOCAL';

export function isLocalProviderId(providerId: string): boolean {
  return providerId === LOCAL_PROVIDER_ID;
}

export function isLocalCompany(company: string): boolean {
  return normalizeProviderId(company) === LOCAL_COMPANY;
}
