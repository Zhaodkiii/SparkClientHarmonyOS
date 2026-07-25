import { describe, it, expect } from '@ohos/hypium';
import { FileStorageDecode } from '../../../main/ets/Core/FileStorage/FileStorageDecode';
import { FileHashUtil } from '../../../main/ets/Core/FileStorage/FileHashUtil';
import { OSSRuntimeConfig } from '../../../main/ets/Projects/Core/OSS/OSSRuntimeConfig';
import {
  FileTransferError,
  parseFileTransferPhase,
  parseFileCacheState
} from '../../../main/ets/Core/FileStorage/FileStorageModels';

export default function fileStorageDecodeTest() {
  describe('FileStorageDecode', () => {
    it('decodes_managed_file_snake_case', 0, () => {
      const data = {
        'id': 12,
        'file_uuid': 'abc-uuid',
        'file_path': 'SparkClient/20260721/abc/a.pdf',
        'original_name': 'a.pdf',
        'file_size': 100,
        'mime_type': 'application/pdf',
        'file_md5': 'AABB',
        'is_public': false,
        'business_type': 'chat_attachment',
        'business_id': 'draft-1',
        'object_key': 'SparkClient/20260721/abc/a.pdf',
        'storage_type': 'oss',
        'created_at': '2026-07-21T00:00:00Z'
      };
      const r = FileStorageDecode.decodeRecord(data);
      expect(r.id).assertEqual(12);
      expect(r.fileUuid).assertEqual('abc-uuid');
      expect(r.fileMd5).assertEqual('aabb');
      expect(r.businessType).assertEqual('chat_attachment');
      expect(r.objectKey).assertEqual('SparkClient/20260721/abc/a.pdf');
    });

    it('assert_register_matches_and_rejects_mismatch', 0, () => {
      const ok = FileStorageDecode.decodeRecord({
        'id': 1,
        'file_uuid': 'u1',
        'object_key': 'k1',
        'original_name': 'n',
        'file_size': 1,
        'mime_type': 'a',
        'file_md5': '',
        'is_public': false,
        'business_type': 't',
        'business_id': '',
        'storage_type': 'oss',
        'created_at': '',
        'file_path': 'k1'
      });
      expect(FileStorageDecode.assertRegisterMatches(ok, 'u1', 'k1')).assertTrue();
      expect(FileStorageDecode.assertRegisterMatches(ok, 'u2', 'k1')).assertFalse();
    });

    it('decodes_download_url', 0, () => {
      const p = FileStorageDecode.decodeDownloadUrl({ 'url': 'https://example.com/x' });
      expect(p.url).assertEqual('https://example.com/x');
    });

    it('sanitize_and_object_key', 0, () => {
      expect(FileHashUtil.sanitizeFileName('../a/b:c.pdf')).assertEqual('__a_b_c.pdf');
      expect(FileHashUtil.sanitizeFileName('')).assertEqual('unnamed_file');
      const key = FileHashUtil.makeObjectKey('uuid-1', 'a.pdf', Date.UTC(2026, 6, 21));
      expect(key).assertEqual('SparkClient/20260721/uuid-1/a.pdf');
      expect(FileHashUtil.mimeTypeForName('x.PNG')).assertEqual('image/png');
    });

    it('sts_freshness_and_phase_parse', 0, () => {
      const cfg = new OSSRuntimeConfig();
      cfg.accessKeyId = 'a';
      cfg.accessKeySecret = 'b';
      cfg.bucketName = 'bucket';
      cfg.region = 'oss-cn-hangzhou';
      cfg.endpoint = 'https://oss-cn-hangzhou.aliyuncs.com';
      cfg.expirationEpochSeconds = Math.floor(Date.now() / 1000) + 600;
      expect(cfg.isComplete()).assertTrue();
      expect(cfg.isFresh(300)).assertTrue();
      cfg.expirationEpochSeconds = Math.floor(Date.now() / 1000) + 10;
      expect(cfg.isFresh(300)).assertFalse();
      expect(parseFileTransferPhase('uploading')).assertEqual('uploading');
      expect(parseFileTransferPhase('downloading')).assertEqual('downloading');
      expect(parseFileTransferPhase('weird')).assertEqual('failed');
      expect(parseFileCacheState('ready')).assertEqual('ready');
      expect(parseFileCacheState('pending_delete')).assertEqual('pending_delete');
      expect(parseFileCacheState('uploaded_unregistered')).assertEqual('uploaded_unregistered');
      expect(parseFileCacheState('nope')).assertEqual('failed');
    });

    it('transfer_error_codes_and_retryable', 0, () => {
      const pending = new FileTransferError(
        'registrationPending',
        'uploadedUnregistered',
        '已上传，等待保存',
        true
      );
      expect(pending.code).assertEqual('registrationPending');
      expect(pending.retryable).assertTrue();
      const gen = new FileTransferError('generationMismatch', 'downloading', '会话已变更', false);
      expect(gen.code).assertEqual('generationMismatch');
      expect(gen.retryable).assertFalse();
      const del = new FileTransferError('networkUnavailable', 'preparing', '网络不可用', true);
      expect(del.retryable).assertTrue();
    });

    it('register_body_includes_object_key', 0, () => {
      const body = FileStorageDecode.toRegisterBody(
        'uuid-x',
        'a.pdf',
        12,
        'application/pdf',
        'SparkClient/20260721/uuid-x/a.pdf',
        'chat_attachment',
        'draft-1',
        false,
        'abcd'
      );
      expect(body.file_uuid).assertEqual('uuid-x');
      expect(body.object_key).assertEqual('SparkClient/20260721/uuid-x/a.pdf');
      expect(body.file_path).assertEqual('SparkClient/20260721/uuid-x/a.pdf');
      expect(body.business_type).assertEqual('chat_attachment');
      expect(body.file_md5).assertEqual('abcd');
    });
  });
}
