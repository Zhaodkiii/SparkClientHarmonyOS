/**
 * @aliyun/oss Harmony SDK 唯一版本与准入事实源（HOS-FILE-OSS-0007）。
 * 禁止业务层散落硬编码版本号；升级必须同步本文件与真机回归矩阵。
 *
 * 依赖来源：entry/oh-package.json5 → OHPM registry @aliyun/oss@2.0.0-beta.1
 * 构建解析：dep_info / CompileArkTS 归一化路径 @aliyun/oss/...&2.0.0-beta.1
 * 不再依赖 entry/third_party/aliyun-oss 历史 Vendor 目录。
 */
export class OSSVendorSdkMeta {
  static readonly PACKAGE_NAME: string = '@aliyun/oss';
  /** 与 vendor oh-package.json5 / 构建产物一致。 */
  static readonly VERSION: string = '2.0.0-beta.1';
  /** 官方 / Vendor 声明的包入口。 */
  static readonly ENTRY_PATH: string = 'src/main/harmony/index';
  /** 工程依赖声明（相对 entry/）。 */
  static readonly DEPENDENCY_SOURCE: string = 'ohpm:@aliyun/oss@2.0.0-beta.1';
  /** 官方最低 API。 */
  static readonly COMPATIBLE_API_MIN: number = 12;
  /**
   * 公测版不得视为已生产准入。产品/发布流程显式放行前保持 false。
   * false ≠ 禁止上传调试；仅表示稳定性未达标。
   */
  static readonly PRODUCTION_ADMITTED: boolean = false;
  static readonly RELEASE_PHASE: string = 'public-preview-beta';

  static toLogDetail(): string {
    return `sdkPkg=${OSSVendorSdkMeta.PACKAGE_NAME};sdkVer=${OSSVendorSdkMeta.VERSION};` +
      `sdkEntry=${OSSVendorSdkMeta.ENTRY_PATH};sdkSource=vendor-ohpm-file;` +
      `sdkApiMin=${OSSVendorSdkMeta.COMPATIBLE_API_MIN};` +
      `sdkProductionAdmitted=${OSSVendorSdkMeta.PRODUCTION_ADMITTED};` +
      `sdkPhase=${OSSVendorSdkMeta.RELEASE_PHASE}`;
  }

  /** 生产上传策略日志用：明确 beta 风险。 */
  static productionGateDetail(): string {
    return OSSVendorSdkMeta.PRODUCTION_ADMITTED
      ? 'productionGate=admitted'
      : 'productionGate=beta-not-admitted';
  }
}
