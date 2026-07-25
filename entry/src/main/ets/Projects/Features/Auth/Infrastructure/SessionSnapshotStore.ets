import { fileIo as fs } from '@kit.CoreFileKit';
import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { NetworkLogger } from '../../../../Foundation/Logging/NetworkLogger';

/**
 * 持久化 UserSession 元数据（不含 Token / deviceSecret）。
 * 使用应用私有目录明文 JSON；损坏或缺失返回 undefined。
 */
export class SessionSnapshotStore {
  private readonly path: string;
  private readonly logger: NetworkLogger;

  constructor(filesDir: string, logger?: NetworkLogger) {
    this.logger = logger ?? new NetworkLogger();
    const dir = `${filesDir}/session`;
    SessionSnapshotStore.ensureDir(dir);
    this.path = `${dir}/user_session.json`;
  }

  async save(session: UserSession): Promise<void> {
    const json = JSON.stringify(session.toPlain());
    const file = fs.openSync(this.path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, json);
    } finally {
      fs.closeSync(file);
    }
  }

  async load(): Promise<UserSession | undefined> {
    try {
      if (!fs.accessSync(this.path)) {
        return undefined;
      }
    } catch (_e) {
      return undefined;
    }
    try {
      const file = fs.openSync(this.path, fs.OpenMode.READ_ONLY);
      let content = '';
      try {
        const stat = fs.statSync(this.path);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        content = SessionSnapshotStore.abToString(buf);
      } finally {
        fs.closeSync(file);
      }
      if (!content || content.length === 0) {
        return undefined;
      }
      const obj = JSON.parse(content) as Record<string, Object | string | number | boolean | undefined>;
      return UserSession.fromPlain(obj);
    } catch (e) {
      this.logger.warn(`SessionSnapshotStore load failed: ${e}`);
      return undefined;
    }
  }

  async clear(): Promise<void> {
    try {
      if (fs.accessSync(this.path)) {
        fs.unlinkSync(this.path);
      }
    } catch (_e) {
      // ignore
    }
  }

  private static ensureDir(dir: string): void {
    try {
      fs.mkdirSync(dir, true);
    } catch (_e) {
      // may already exist
    }
  }

  private static abToString(buf: ArrayBuffer): string {
    const bytes = new Uint8Array(buf);
    let s = '';
    for (let i = 0; i < bytes.length; i++) {
      s += String.fromCharCode(bytes[i]);
    }
    return s;
  }
}
