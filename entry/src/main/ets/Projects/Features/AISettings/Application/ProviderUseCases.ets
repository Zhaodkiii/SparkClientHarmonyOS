import {
  AIConfigSnapshot,
  LocalModel,
  LocalProvider,
  nowIso,
  normalizeProviderId
} from '../../../../Core/AI/Domain/AIConfigModels';
import { isLocalCompany, isLocalProviderId } from '../../../../Core/AI/Domain/AILocalProviderIds';

export class ProviderUseCases {
  static upsert(snapshot: AIConfigSnapshot, provider: LocalProvider): void {
    const id = provider.id || normalizeProviderId(provider.company || provider.name);
    provider.id = id;
    provider.updatedAt = nowIso();
    let found = false;
    for (let i = 0; i < snapshot.providers.length; i++) {
      if (snapshot.providers[i].id === id) {
        snapshot.providers[i] = provider;
        found = true;
        break;
      }
    }
    if (!found) {
      provider.position = snapshot.providers.length;
      if (!provider.source || provider.source.length === 0) {
        provider.source = 'localUser';
      }
      snapshot.providers.push(provider);
    }
  }

  static setEnabled(snapshot: AIConfigSnapshot, providerId: string, enabled: boolean): void {
    for (let i = 0; i < snapshot.providers.length; i++) {
      if (snapshot.providers[i].id === providerId) {
        snapshot.providers[i].isEnabled = enabled;
        snapshot.providers[i].updatedAt = nowIso();
      }
    }
  }

  static setRequestUrl(snapshot: AIConfigSnapshot, providerId: string, url: string): void {
    for (let i = 0; i < snapshot.providers.length; i++) {
      if (snapshot.providers[i].id === providerId) {
        snapshot.providers[i].requestUrl = url;
        snapshot.providers[i].updatedAt = nowIso();
      }
    }
  }

  static delete(snapshot: AIConfigSnapshot, providerId: string): void {
    const p = ProviderUseCases.find(snapshot, providerId);
    if (p && p.source === 'pro') {
      throw new Error('不能删除 Pro Provider');
    }
    if (p && (p.kind === 'local' || isLocalProviderId(p.id) || isLocalCompany(p.company))) {
      throw new Error('不能从模型密钥页删除本地模型 Provider');
    }
    snapshot.providers = snapshot.providers.filter((x: LocalProvider) => x.id !== providerId);
    snapshot.models = snapshot.models.filter((m: LocalModel) => m.providerId !== providerId);
  }

  static find(snapshot: AIConfigSnapshot, providerId: string): LocalProvider | undefined {
    for (let i = 0; i < snapshot.providers.length; i++) {
      if (snapshot.providers[i].id === providerId) {
        return snapshot.providers[i];
      }
    }
    return undefined;
  }

  static createCustom(company: string, name: string, requestUrl: string, idSuffix?: string): LocalProvider {
    const c = company.trim();
    const n = name.trim();
    const u = requestUrl.trim();
    if (c.length === 0 || c.length > 64) {
      throw new Error('厂商名称长度需为 1-64');
    }
    if (n.length === 0 || n.length > 64) {
      throw new Error('显示名称长度需为 1-64');
    }
    if (u.length === 0) {
      throw new Error('请填写 requestUrl');
    }
    if (u.indexOf('https://') !== 0 && u.indexOf('http://') !== 0) {
      throw new Error('URL 必须以 http:// 或 https:// 开头');
    }
    const suffix = (idSuffix && idSuffix.length > 0) ? idSuffix : `${Date.now()}`;
    const p = new LocalProvider();
    p.id = `custom:${normalizeProviderId(c)}_${suffix}`;
    p.company = c;
    p.name = n;
    p.kind = 'api';
    p.requestUrl = u;
    p.isEnabled = true;
    p.source = 'custom';
    p.updatedAt = nowIso();
    return p;
  }
}
