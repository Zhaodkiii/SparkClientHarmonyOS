/**
 * OSS STS 运行时配置。仅内存持有；禁止写入 Preferences / RDB / 日志。
 * 字段与 iOS AliyunOSSRuntimeConfig / 服务器 STS data 对齐（HOS-FILE-OSS-0005）。
 */
export class OSSRuntimeConfig {
  accessKeyId: string = '';
  accessKeySecret: string = '';
  securityToken: string = '';
  expirationEpochSeconds: number = 0;
  bucketName: string = '';
  region: string = '';
  endpoint: string = '';
  /**
   * Bucket 实际地域（STS bucket_region）；可与 region 相同。
   * 空表示旧服务端未下发，客户端仅用 region+endpoint 做一致性校验。
   */
  bucketRegion: string = '';
  /** 服务端允许的对象前缀；空则使用客户端默认 SparkClient/。 */
  objectKeyPrefix: string = '';
  /** 配置版本摘要，仅诊断。 */
  configVersion: string = '';
  /** 签名版本提示；空视为 v4。 */
  signatureVersion: string = '';
  /** 标准 / custom；自定义域名时建议为 custom。 */
  endpointType: string = '';
  /**
   * 是否允许把 RCP 零时代码上传错误按成功放行并继续后续流程。
   * 默认开启；关闭后，`ossTransientFailure + httpStatus=0 + RCP reason` 仍按失败处理。
   */
  allowZeroStatusBypass: boolean = true;

  /** 与 iOS 一致的必填：AK/SK/bucket/region/endpoint。 */
  isComplete(): boolean {
    return this.accessKeyId.length > 0 &&
      this.accessKeySecret.length > 0 &&
      this.bucketName.length > 0 &&
      this.region.length > 0 &&
      this.endpoint.length > 0;
  }

  /**
   * 在过期前至少保留 thresholdSeconds 秒才视为仍可用。
   */
  isFresh(thresholdSeconds: number = 300): boolean {
    if (this.expirationEpochSeconds <= 0) {
      return true;
    }
    const nowSec = Math.floor(Date.now() / 1000);
    return this.expirationEpochSeconds - nowSec > thresholdSeconds;
  }

  /** STS 模式（有 security_token）还是静态开发凭证。 */
  roleMode(): string {
    return this.securityToken.length > 0 ? 'STS' : 'static';
  }
}
