/**
 * Harmony Vendor OSS Client 初始化参数归一化。
 *
 * 官方要求（SigV4）：公有云 region 使用 `oss-cn-hangzhou` 形式；默认配置不传 endpoint。
 * HOS-FILE-OSS-0004：region / endpoint / bucketRegion 冲突时禁止静默错配；
 * 标准公有云在校验一致后仍显式使用服务器下发的 endpoint，避免 HarmonyOS/RCP
 * 通过 region 自动推导出不可验证的实际连接目标。
 *
 * 参考：https://help.aliyun.com/zh/oss/developer-reference/configure-client-using-harmony-sdk
 */
export type OSSActualEndpointMode = 'derived' | 'explicit' | 'custom';

export class OSSClientInitParams {
  /** 传给 Vendor Client 的签名/推导 region（公有云为 oss-cn-*）。 */
  region: string = '';
  /** 仅自定义域名或金融/政务等特殊 endpoint 时非空。 */
  endpoint: string = '';
  cname: boolean = false;
  secure: boolean = true;
  signatureMode: string = 'v4';

  /** 配置侧原始 region 别名（归一化前）。 */
  configuredRegionAlias: string = '';
  /** 归一化后的签名 region 别名。 */
  normalizedRegionAlias: string = '';
  /** STS/配置中的 endpoint 别名（原始）。 */
  configuredEndpointAlias: string = '';
  /** 实际将使用的推导/显式 endpoint 别名。 */
  derivedEndpointAlias: string = '';
  /** bucketRegion 别名；无则 empty。 */
  bucketRegionAlias: string = '';
  /** 与 normalizedRegionAlias 相同（SigV4 scope）。 */
  signatureRegionAlias: string = '';
  actualEndpointMode: OSSActualEndpointMode = 'derived';
  regionEndpointConsistent: boolean = true;
  /** 是否对 STS 原始 region 做了 oss- 前缀补齐。 */
  regionNormalized: boolean = false;
  /** 是否省略了标准公有云 endpoint。 */
  endpointOmitted: boolean = false;
  /**
   * 非空表示不得发 PUT：endpointConfig / missingRegion 等。
   * Adapter 映射为 ossConfigurationInvalid。
   */
  configurationIssue: string = '';

  /** 兼容旧日志字段；等于 normalizedRegionAlias。 */
  regionAlias: string = '';
  /** 兼容旧日志字段；优先 configuredEndpointAlias。 */
  endpointAlias: string = '';
}

export class OSSClientConfigNormalizer {
  /**
   * @param rawRegion STS region（常为 cn-*）
   * @param rawEndpoint STS endpoint
   * @param rawBucketRegion 可选；若提供则作为权威 Bucket 地域
   */
  static normalize(
    rawRegion: string,
    rawEndpoint: string,
    rawBucketRegion: string = ''
  ): OSSClientInitParams {
    const out = new OSSClientInitParams();
    const regionIn = rawRegion.trim();
    const endpointIn = rawEndpoint.trim();
    const bucketRegionIn = rawBucketRegion.trim();

    const configuredRegionOss = regionIn.length > 0
      ? OSSClientConfigNormalizer.toOssRegionId(regionIn)
      : '';
    const bucketRegionOss = bucketRegionIn.length > 0
      ? OSSClientConfigNormalizer.toOssRegionId(bucketRegionIn)
      : '';
    const host = OSSClientConfigNormalizer.hostOf(endpointIn);
    const endpointRegionOss = OSSClientConfigNormalizer.regionFromStandardHost(host);

    out.configuredRegionAlias = OSSClientConfigNormalizer.alias(
      configuredRegionOss.length > 0 ? configuredRegionOss : regionIn,
      24
    );
    out.configuredEndpointAlias = host.length > 0
      ? OSSClientConfigNormalizer.endpointAliasOf(host)
      : 'empty';
    out.bucketRegionAlias = bucketRegionOss.length > 0
      ? OSSClientConfigNormalizer.alias(bucketRegionOss, 24)
      : 'empty';

    // —— 权威地域选择 ——
    let authoritative = '';
    if (bucketRegionOss.length > 0) {
      authoritative = bucketRegionOss;
    } else if (configuredRegionOss.length > 0) {
      authoritative = configuredRegionOss;
    } else if (endpointRegionOss.length > 0) {
      authoritative = endpointRegionOss;
    }

    if (authoritative.length === 0) {
      out.configurationIssue = 'missingRegion';
      out.regionEndpointConsistent = false;
      out.normalizedRegionAlias = 'empty';
      out.derivedEndpointAlias = 'empty';
      out.signatureRegionAlias = 'empty';
      out.regionAlias = 'empty';
      out.endpointAlias = out.configuredEndpointAlias;
      out.actualEndpointMode = 'derived';
      return out;
    }

    // 冲突检测：标准 endpoint 地域 / 配置 region / bucketRegion 两两不一致 → 阻断
    const conflict = OSSClientConfigNormalizer.hasRegionConflict(
      configuredRegionOss,
      endpointRegionOss,
      bucketRegionOss
    );
    if (conflict) {
      out.configurationIssue = 'endpointConfig';
      out.regionEndpointConsistent = false;
      out.region = authoritative;
      out.normalizedRegionAlias = OSSClientConfigNormalizer.alias(authoritative, 24);
      out.signatureRegionAlias = out.normalizedRegionAlias;
      out.regionAlias = out.normalizedRegionAlias;
      out.derivedEndpointAlias = endpointRegionOss.length > 0
        ? OSSClientConfigNormalizer.alias(endpointRegionOss, 24)
        : out.configuredEndpointAlias;
      out.endpointAlias = out.configuredEndpointAlias;
      out.actualEndpointMode = 'derived';
      out.endpoint = '';
      out.endpointOmitted = true;
      out.regionNormalized = configuredRegionOss.length > 0 &&
        configuredRegionOss !== regionIn.toLowerCase();
      return out;
    }

    out.regionEndpointConsistent = true;
    out.configurationIssue = '';
    out.region = authoritative;
    out.normalizedRegionAlias = OSSClientConfigNormalizer.alias(authoritative, 24);
    out.signatureRegionAlias = out.normalizedRegionAlias;
    out.regionAlias = out.normalizedRegionAlias;
    out.endpointAlias = out.configuredEndpointAlias;
    out.regionNormalized = configuredRegionOss.length > 0 &&
      (configuredRegionOss !== regionIn.toLowerCase() ||
        (bucketRegionOss.length > 0 && bucketRegionOss !== configuredRegionOss));

    if (host.length === 0) {
      out.endpoint = '';
      out.cname = false;
      out.endpointOmitted = true;
      out.secure = true;
      out.actualEndpointMode = 'derived';
      out.derivedEndpointAlias = out.normalizedRegionAlias;
      out.endpointAlias = 'derived';
      return out;
    }

    if (OSSClientConfigNormalizer.isCustomDomain(host)) {
      out.endpoint = endpointIn.indexOf('://') >= 0 ? endpointIn : `https://${host}`;
      out.cname = true;
      out.endpointOmitted = false;
      out.secure = out.endpoint.indexOf('http://') !== 0;
      out.actualEndpointMode = 'custom';
      out.derivedEndpointAlias = 'custom';
      return out;
    }

    if (OSSClientConfigNormalizer.isSpecialAliyunEndpoint(host)) {
      // 金融云/政务云/内网：官方示例保留 region 原文并显式传 endpoint。
      const specialRegion = regionIn.length > 0 ? regionIn.toLowerCase() : authoritative;
      out.region = specialRegion;
      out.regionNormalized = false;
      out.normalizedRegionAlias = OSSClientConfigNormalizer.alias(specialRegion, 24);
      out.signatureRegionAlias = out.normalizedRegionAlias;
      out.regionAlias = out.normalizedRegionAlias;
      out.endpoint = endpointIn.indexOf('://') >= 0 ? endpointIn : `https://${host}`;
      out.cname = false;
      out.endpointOmitted = false;
      out.secure = out.endpoint.indexOf('http://') !== 0;
      out.actualEndpointMode = 'explicit';
      out.derivedEndpointAlias = 'aliyun-special';
      return out;
    }

    // 标准公有云：校验通过后保留服务器 endpoint，显式传给官方 SDK。
    // 仅 endpoint 为空时才走 SDK 的 region 自动推导路径。
    out.endpoint = endpointIn.indexOf('://') >= 0 ? endpointIn : `https://${host}`;
    out.cname = false;
    out.endpointOmitted = false;
    out.secure = out.endpoint.indexOf('http://') !== 0;
    out.actualEndpointMode = 'explicit';
    out.derivedEndpointAlias = out.normalizedRegionAlias;
    return out;
  }

  static hasRegionConflict(
    configuredRegionOss: string,
    endpointRegionOss: string,
    bucketRegionOss: string
  ): boolean {
    const parts: string[] = [];
    if (configuredRegionOss.length > 0) {
      parts.push(configuredRegionOss);
    }
    if (endpointRegionOss.length > 0) {
      parts.push(endpointRegionOss);
    }
    if (bucketRegionOss.length > 0) {
      parts.push(bucketRegionOss);
    }
    if (parts.length < 2) {
      return false;
    }
    const first = parts[0];
    for (let i = 1; i < parts.length; i++) {
      if (parts[i] !== first) {
        return true;
      }
    }
    return false;
  }

  /**
   * 公有云 STS 常返回 cn-hangzhou；Harmony SDK 要求 oss-cn-hangzhou。
   * 金融/政务等特殊 region 保持官方示例原样。
   */
  static toOssRegionId(region: string): string {
    const r = region.trim().toLowerCase();
    if (r.length === 0) {
      return r;
    }
    if (r.indexOf('oss-') === 0) {
      return r;
    }
    if (r.indexOf('finance') >= 0 || r.indexOf('gov') >= 0) {
      return r;
    }
    return `oss-${r}`;
  }

  /** oss-cn-beijing.aliyuncs.com → oss-cn-beijing */
  static regionFromStandardHost(host: string): string {
    if (!OSSClientConfigNormalizer.isStandardPublicEndpoint(host)) {
      return '';
    }
    const dot = host.indexOf('.');
    if (dot <= 0) {
      return '';
    }
    return host.substring(0, dot).toLowerCase();
  }

  static hostOf(endpoint: string): string {
    let host = endpoint.trim();
    if (host.indexOf('https://') === 0) {
      host = host.substring('https://'.length);
    } else if (host.indexOf('http://') === 0) {
      host = host.substring('http://'.length);
    }
    const slash = host.indexOf('/');
    if (slash >= 0) {
      host = host.substring(0, slash);
    }
    return host.toLowerCase();
  }

  static isCustomDomain(host: string): boolean {
    return host.length > 0 && host.indexOf('.aliyuncs.com') < 0;
  }

  static isSpecialAliyunEndpoint(host: string): boolean {
    if (host.indexOf('.aliyuncs.com') < 0) {
      return false;
    }
    return host.indexOf('-internal') >= 0 ||
      host.indexOf('finance') >= 0 ||
      host.indexOf('gov') >= 0 ||
      host.indexOf('hzjbp') >= 0;
  }

  static isStandardPublicEndpoint(host: string): boolean {
    return host.indexOf('.aliyuncs.com') >= 0 && !OSSClientConfigNormalizer.isSpecialAliyunEndpoint(host);
  }

  static toLogDetail(init: OSSClientInitParams): string {
    return `configuredRegionAlias=${init.configuredRegionAlias};` +
      `normalizedRegionAlias=${init.normalizedRegionAlias};` +
      `configuredEndpointAlias=${init.configuredEndpointAlias};` +
      `derivedEndpointAlias=${init.derivedEndpointAlias};` +
      `actualEndpointMode=${init.actualEndpointMode};` +
      `signatureMode=${init.signatureMode};` +
      `signatureRegionAlias=${init.signatureRegionAlias};` +
      `bucketRegionAlias=${init.bucketRegionAlias};` +
      `regionEndpointConsistent=${init.regionEndpointConsistent};` +
      `regionNormalized=${init.regionNormalized};endpointOmitted=${init.endpointOmitted}` +
      (init.configurationIssue.length > 0 ? `;configurationIssue=${init.configurationIssue}` : '');
  }

  private static endpointAliasOf(host: string): string {
    if (OSSClientConfigNormalizer.isCustomDomain(host)) {
      return 'custom';
    }
    if (OSSClientConfigNormalizer.isSpecialAliyunEndpoint(host)) {
      return 'aliyun-special';
    }
    const dot = host.indexOf('.');
    if (dot > 0) {
      return OSSClientConfigNormalizer.alias(host.substring(0, dot), 32);
    }
    return 'aliyun';
  }

  private static alias(value: string, max: number): string {
    if (value.length === 0) {
      return 'empty';
    }
    if (value.length <= max) {
      return value;
    }
    return `${value.substring(0, max)}…`;
  }
}
