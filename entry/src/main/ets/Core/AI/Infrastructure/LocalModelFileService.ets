import { fileIo as fs } from '@kit.CoreFileKit';
import { nowIso } from '../Domain/AIConfigModels';

export class LocalModelFileState {
  modelId: string = '';
  path: string = '';
  sizeBytes: number = 0;
  sha256: string = '';
  downloadState: string = 'missing';
  errorCode?: string;
}

/**
 * 本地模型文件元数据服务（无下载引擎；支持路径校验与删除约定）。
 */
export class LocalModelFileService {
  private readonly rootDir: string;

  constructor(filesDir: string) {
    this.rootDir = `${filesDir}/ai-models`;
    LocalModelFileService.ensureDir(this.rootDir);
  }

  /** 应用 filesDir（rootDir 去掉 /ai-models）。供 OCR PDF 沙箱缓存等复用。 */
  applicationFilesDir(): string {
    const suffix = '/ai-models';
    if (this.rootDir.endsWith(suffix)) {
      return this.rootDir.substring(0, this.rootDir.length - suffix.length);
    }
    return this.rootDir;
  }

  modelDir(accountId: number, modelId: string): string {
    const safe = modelId.replace(/[^A-Za-z0-9._-]/g, '_');
    return `${this.rootDir}/${accountId}/${safe}`;
  }

  async markMissing(accountId: number, modelId: string): Promise<LocalModelFileState> {
    const state = new LocalModelFileState();
    state.modelId = modelId;
    state.path = this.modelDir(accountId, modelId);
    state.downloadState = 'missing';
    return state;
  }

  async validateReadyFile(accountId: number, modelId: string, fileName: string): Promise<LocalModelFileState> {
    const state = new LocalModelFileState();
    state.modelId = modelId;
    const dir = this.modelDir(accountId, modelId);
    LocalModelFileService.ensureDir(dir);
    const safeName = fileName.replace(/[^A-Za-z0-9._-]/g, '_');
    if (!safeName.toLowerCase().endsWith('.gguf')) {
      state.downloadState = 'failed';
      state.errorCode = 'invalidExtension';
      return state;
    }
    const path = `${dir}/${safeName}`;
    state.path = path;
    try {
      if (!fs.accessSync(path)) {
        state.downloadState = 'missing';
        return state;
      }
      const stat = fs.statSync(path);
      state.sizeBytes = stat.size;
      state.sha256 = ''; // 真机可补 hash
      state.downloadState = 'ready';
      return state;
    } catch (_e) {
      state.downloadState = 'failed';
      state.errorCode = 'ioError';
      return state;
    }
  }

  async deleteModelFiles(accountId: number, modelId: string): Promise<void> {
    const dir = this.modelDir(accountId, modelId);
    try {
      if (fs.accessSync(dir)) {
        const files = fs.listFileSync(dir);
        for (let i = 0; i < files.length; i++) {
          try {
            fs.unlinkSync(`${dir}/${files[i]}`);
          } catch (_e) {
            // ignore
          }
        }
      }
    } catch (_e) {
      // ignore
    }
  }

  private static ensureDir(dir: string): void {
    try {
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
    } catch (_e) {
      try {
        fs.mkdirSync(dir, true);
      } catch (__e) {
        // ignore
      }
    }
  }
}
