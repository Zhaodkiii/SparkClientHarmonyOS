import { relationalStore } from '@kit.ArkData';
import { AppRelationalDatabase } from '../Storage/AppRelationalDatabase';
import {
  FileCacheRecord,
  FileCacheState,
  parseFileCacheState
} from './FileStorageModels';
import { FileCacheSchema } from './FileCacheSchema';

/**
 * file_cache_record CRUD；写操作走 AppRdbWriteQueue。
 */
export class FileCacheRepository {
  private readonly database: AppRelationalDatabase;

  constructor(database: AppRelationalDatabase) {
    this.database = database;
  }

  async upsert(record: FileCacheRecord): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      const now = Date.now();
      const created = record.createdAt > 0 ? record.createdAt : now;
      const updated = record.updatedAt > 0 ? record.updatedAt : now;
      const accessed = record.lastAccessedAt > 0 ? record.lastAccessedAt : now;
      await db.executeSql(
        `INSERT OR REPLACE INTO ${FileCacheSchema.T_FILE_CACHE}
         (account_id_hash, file_id, file_uuid, local_path, original_name, file_size, file_md5,
          object_key, state, mime_type, business_type, business_id, is_public,
          last_accessed_at, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          record.accountIdHash,
          record.fileId,
          record.fileUuid.toLowerCase(),
          record.localPath,
          record.originalName,
          record.fileSize,
          record.fileMd5.length > 0 ? record.fileMd5 : null,
          record.objectKey.length > 0 ? record.objectKey : null,
          record.state,
          record.mimeType.length > 0 ? record.mimeType : null,
          record.businessType.length > 0 ? record.businessType : null,
          record.businessId.length > 0 ? record.businessId : null,
          record.isPublic ? 1 : 0,
          accessed,
          created,
          updated
        ]
      );
    });
  }

  async find(accountIdHash: string, fileUuid: string): Promise<FileCacheRecord | undefined> {
    const db = await this.database.open();
    const rs = await db.querySql(
      `SELECT * FROM ${FileCacheSchema.T_FILE_CACHE}
       WHERE account_id_hash = ? AND file_uuid = ?`,
      [accountIdHash, fileUuid.toLowerCase()]
    );
    try {
      if (!rs.goToFirstRow()) {
        return undefined;
      }
      return FileCacheRepository.readRow(rs);
    } finally {
      rs.close();
    }
  }

  async findByFileId(accountIdHash: string, fileId: number): Promise<FileCacheRecord | undefined> {
    const db = await this.database.open();
    const rs = await db.querySql(
      `SELECT * FROM ${FileCacheSchema.T_FILE_CACHE}
       WHERE account_id_hash = ? AND file_id = ? LIMIT 1`,
      [accountIdHash, fileId]
    );
    try {
      if (!rs.goToFirstRow()) {
        return undefined;
      }
      return FileCacheRepository.readRow(rs);
    } finally {
      rs.close();
    }
  }

  async listByState(accountIdHash: string, state: FileCacheState): Promise<FileCacheRecord[]> {
    const db = await this.database.open();
    const rs = await db.querySql(
      `SELECT * FROM ${FileCacheSchema.T_FILE_CACHE}
       WHERE account_id_hash = ? AND state = ?`,
      [accountIdHash, state]
    );
    const out: FileCacheRecord[] = [];
    try {
      if (rs.goToFirstRow()) {
        do {
          out.push(FileCacheRepository.readRow(rs));
        } while (rs.goToNextRow());
      }
    } finally {
      rs.close();
    }
    return out;
  }

  async markState(accountIdHash: string, fileUuid: string, state: FileCacheState): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(
        `UPDATE ${FileCacheSchema.T_FILE_CACHE}
         SET state = ?, updated_at = ?
         WHERE account_id_hash = ? AND file_uuid = ?`,
        [state, Date.now(), accountIdHash, fileUuid.toLowerCase()]
      );
    });
  }

  async touchAccess(accountIdHash: string, fileUuid: string): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      const now = Date.now();
      await db.executeSql(
        `UPDATE ${FileCacheSchema.T_FILE_CACHE}
         SET last_accessed_at = ?, updated_at = ?
         WHERE account_id_hash = ? AND file_uuid = ?`,
        [now, now, accountIdHash, fileUuid.toLowerCase()]
      );
    });
  }

  async delete(accountIdHash: string, fileUuid: string): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(
        `DELETE FROM ${FileCacheSchema.T_FILE_CACHE}
         WHERE account_id_hash = ? AND file_uuid = ?`,
        [accountIdHash, fileUuid.toLowerCase()]
      );
    });
  }

  async deleteByAccount(accountIdHash: string): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(
        `DELETE FROM ${FileCacheSchema.T_FILE_CACHE} WHERE account_id_hash = ?`,
        [accountIdHash]
      );
    });
  }

  async listByAccount(accountIdHash: string): Promise<FileCacheRecord[]> {
    const db = await this.database.open();
    const rs = await db.querySql(
      `SELECT * FROM ${FileCacheSchema.T_FILE_CACHE} WHERE account_id_hash = ?`,
      [accountIdHash]
    );
    const out: FileCacheRecord[] = [];
    try {
      if (rs.goToFirstRow()) {
        do {
          out.push(FileCacheRepository.readRow(rs));
        } while (rs.goToNextRow());
      }
    } finally {
      rs.close();
    }
    return out;
  }

  private static readRow(rs: relationalStore.ResultSet): FileCacheRecord {
    const r = new FileCacheRecord();
    r.accountIdHash = FileCacheRepository.str(rs, 'account_id_hash');
    r.fileId = FileCacheRepository.long(rs, 'file_id');
    r.fileUuid = FileCacheRepository.str(rs, 'file_uuid');
    r.localPath = FileCacheRepository.str(rs, 'local_path');
    r.originalName = FileCacheRepository.str(rs, 'original_name');
    r.fileSize = FileCacheRepository.long(rs, 'file_size');
    r.fileMd5 = FileCacheRepository.optStr(rs, 'file_md5');
    r.objectKey = FileCacheRepository.optStr(rs, 'object_key');
    r.state = parseFileCacheState(FileCacheRepository.str(rs, 'state'));
    r.mimeType = FileCacheRepository.optStr(rs, 'mime_type');
    if (r.mimeType.length === 0) {
      r.mimeType = 'application/octet-stream';
    }
    r.businessType = FileCacheRepository.optStr(rs, 'business_type');
    r.businessId = FileCacheRepository.optStr(rs, 'business_id');
    r.isPublic = FileCacheRepository.long(rs, 'is_public') === 1;
    r.lastAccessedAt = FileCacheRepository.long(rs, 'last_accessed_at');
    r.createdAt = FileCacheRepository.long(rs, 'created_at');
    r.updatedAt = FileCacheRepository.long(rs, 'updated_at');
    return r;
  }

  private static str(rs: relationalStore.ResultSet, col: string): string {
    try {
      const idx = rs.getColumnIndex(col);
      if (rs.isColumnNull(idx)) {
        return '';
      }
      return rs.getString(idx);
    } catch (_e) {
      return '';
    }
  }

  private static optStr(rs: relationalStore.ResultSet, col: string): string {
    return FileCacheRepository.str(rs, col);
  }

  private static long(rs: relationalStore.ResultSet, col: string): number {
    try {
      const idx = rs.getColumnIndex(col);
      if (rs.isColumnNull(idx)) {
        return 0;
      }
      return rs.getLong(idx);
    } catch (_e) {
      return 0;
    }
  }
}
