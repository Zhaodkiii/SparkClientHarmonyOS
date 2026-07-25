import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AppRdbWriteQueue } from './AppRdbWriteQueue';
import { AppDatabaseSchema } from './AppDatabaseSchema';
import { Logger } from '../../Foundation/Logging/Logger';
import { LogModule } from '../../Foundation/Logging/LogModule';
import { LogFields } from '../../Foundation/Logging/LogEvent';
import { ErrorLogger } from '../../Foundation/Logging/ErrorLogger';

const APP_DB_NAME: string = 'spark_client.db';

/**
 * 应用共用关系库。进程内单例；表按模块前缀分区（ai_* / file_*）。
 * 全新项目：打开时确保 DDL 存在并将 user_version 钉死为 1，不做增量升级。
 */
export class AppRelationalDatabase {
  private readonly context: common.Context;
  private readonly writeQueue: AppRdbWriteQueue;
  private store?: relationalStore.RdbStore;
  private openPromise?: Promise<relationalStore.RdbStore>;

  constructor(context: common.Context, writeQueue?: AppRdbWriteQueue) {
    this.context = context;
    this.writeQueue = writeQueue ?? new AppRdbWriteQueue();
  }

  get queue(): AppRdbWriteQueue {
    return this.writeQueue;
  }

  async open(): Promise<relationalStore.RdbStore> {
    if (this.store) {
      return this.store;
    }
    if (this.openPromise) {
      return this.openPromise;
    }
    this.openPromise = this.openInternal();
    try {
      this.store = await this.openPromise;
      return this.store;
    } finally {
      this.openPromise = undefined;
    }
  }

  private async openInternal(): Promise<relationalStore.RdbStore> {
    const config: relationalStore.StoreConfig = {
      name: APP_DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S3,
      encrypt: true
    };
    try {
      const db = await relationalStore.getRdbStore(this.context, config);
      await this.ensureSchema(db);
      Logger.info('app_rdb.opened spark_client.db', LogModule.DATABASE);
      return db;
    } catch (err) {
      ErrorLogger.log('app_rdb.open_failed', LogModule.DATABASE, err as Object);
      throw new Error(ErrorLogger.summarize(err as Object));
    }
  }

  private async ensureSchema(db: relationalStore.RdbStore): Promise<void> {
    await this.writeQueue.enqueue(async () => {
      let version = 0;
      try {
        const rs = await db.querySql('PRAGMA user_version', []);
        try {
          if (rs.goToFirstRow()) {
            version = rs.getLong(rs.getColumnIndex('user_version'));
          }
        } finally {
          rs.close();
        }
      } catch (_e) {
        version = 0;
      }
      const statements = AppDatabaseSchema.ddlStatements();
      for (let i = 0; i < statements.length; i++) {
        await db.executeSql(statements[i]);
      }
      const alters = AppDatabaseSchema.ensureColumnStatements();
      for (let i = 0; i < alters.length; i++) {
        try {
          await db.executeSql(alters[i]);
        } catch (_e) {
          // 列已存在时忽略
        }
      }
      if (version !== AppDatabaseSchema.APP_SCHEMA_VERSION) {
        await db.executeSql(`PRAGMA user_version = ${AppDatabaseSchema.APP_SCHEMA_VERSION}`);
        const fields = new LogFields();
        fields.detail = `schema ready version=${AppDatabaseSchema.APP_SCHEMA_VERSION}`;
        Logger.info('app.rdb.schema_ready', LogModule.DATABASE, fields);
      }
    });
  }

  async close(): Promise<void> {
    if (this.store) {
      try {
        this.store = undefined;
      } catch (_e) {
        // ignore
      }
    }
  }
}
