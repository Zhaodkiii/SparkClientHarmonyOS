import { AIConfigSchema } from '../AI/Infrastructure/AIConfigSchema';
import { FileCacheSchema } from '../FileStorage/FileCacheSchema';
import { ChatSchema } from '../../Projects/Features/Chat/Infrastructure/ChatSchema';
import { KnowledgeSchema } from '../../Projects/Features/Knowledge/Infrastructure/KnowledgeSchema';

/**
 * 应用库统一 schema 注册表。
 * 全新项目固定 version=1；禁止增量 migration / 历史版本分支。
 * 新表用 CREATE IF NOT EXISTS 幂等加入。
 */
export class AppDatabaseSchema {
  static readonly APP_SCHEMA_VERSION: number = 3;

  static ddlStatements(): string[] {
    const out: string[] = [];
    const ai = AIConfigSchema.ddlStatements();
    for (let i = 0; i < ai.length; i++) {
      out.push(ai[i]);
    }
    const files = FileCacheSchema.ddlStatements();
    for (let i = 0; i < files.length; i++) {
      out.push(files[i]);
    }
    const chat = ChatSchema.ddlStatements();
    for (let i = 0; i < chat.length; i++) {
      out.push(chat[i]);
    }
    const knowledge = KnowledgeSchema.ddlStatements();
    for (let i = 0; i < knowledge.length; i++) {
      out.push(knowledge[i]);
    }
    return out;
  }

  static ensureColumnStatements(): string[] {
    const out: string[] = [];
    const files = FileCacheSchema.ensureColumnStatements();
    for (let i = 0; i < files.length; i++) {
      out.push(files[i]);
    }
    const chat = ChatSchema.ensureColumnStatements();
    for (let i = 0; i < chat.length; i++) {
      out.push(chat[i]);
    }
    const knowledge = KnowledgeSchema.ensureColumnStatements();
    for (let i = 0; i < knowledge.length; i++) {
      out.push(knowledge[i]);
    }
    return out;
  }
}
