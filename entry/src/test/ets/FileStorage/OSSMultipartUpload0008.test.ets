import { describe, it, expect } from '@ohos/hypium';
import { FileUploadMode } from '../../../main/ets/Core/FileStorage/FileUploadMode';
import {
  InMemoryFileUploadCheckpointStore
} from '../../../main/ets/Core/FileStorage/FileUploadCheckpointStore';
import { MultipartUploadCheckpoint, MultipartPartRecord } from '../../../main/ets/Core/FileStorage/MultipartUploadModels';
import { FileTransferErrorLocalizer } from '../../../main/ets/Core/FileStorage/FileTransferErrorLocalizer';
import { FileTransferError } from '../../../main/ets/Core/FileStorage/FileStorageModels';
import { OSSDiagnosticFingerprint } from '../../../main/ets/Projects/Core/OSS/OSSDiagnosticFingerprint';
import { OSSSimpleUploadAdapter } from '../../../main/ets/Projects/Core/OSS/OSSSimpleUploadAdapter';

export default function ossMultipartUpload0008Test() {
  describe('OSS_HOS_FILE_OSS_0008_0009', () => {
    it('mode_select_simple_under_8mb', 0, () => {
      const sel = FileUploadMode.select(7 * 1024 * 1024);
      expect(sel.mode).assertEqual('simple');
      expect(sel.totalParts).assertEqual(0);
    });

    it('mode_select_multipart_over_8mb', 0, () => {
      const sel = FileUploadMode.select(9 * 1024 * 1024);
      expect(sel.mode).assertEqual('multipart');
      expect(sel.partSize).assertEqual(FileUploadMode.PART_SIZE_BYTES);
      expect(sel.totalParts).assertEqual(2);
      expect(FileUploadMode.toLogDetail(sel).indexOf('mode=multipart') >= 0).assertTrue();
    });

    it('part_offset_length_last_shard_smaller', 0, () => {
      const size = 12 * 1024 * 1024;
      const partSize = 5 * 1024 * 1024;
      expect(FileUploadMode.computeTotalParts(size, partSize)).assertEqual(3);
      expect(FileUploadMode.partOffset(3, partSize)).assertEqual(10 * 1024 * 1024);
      expect(FileUploadMode.partLength(size, 3, partSize)).assertEqual(2 * 1024 * 1024);
    });

    it('checkpoint_store_roundtrip_without_secrets_in_hash', 0, async () => {
      const store = new InMemoryFileUploadCheckpointStore();
      const cp = new MultipartUploadCheckpoint();
      cp.fileUuid = 'uuid-1';
      cp.accountId = 42;
      cp.uploadId = 'UPLOAD-ID-SECRET';
      cp.uploadIdHash = OSSDiagnosticFingerprint.uploadIdHash(cp.uploadId);
      cp.objectKey = 'SparkClient/20260724/uuid-1/a.pdf';
      cp.fileSize = 9 * 1024 * 1024;
      cp.fileMd5 = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      cp.partSize = FileUploadMode.PART_SIZE_BYTES;
      cp.totalParts = 2;
      cp.status = 'uploading';
      const part = new MultipartPartRecord();
      part.partNumber = 1;
      part.etag = 'etag-raw';
      part.etagHash = OSSDiagnosticFingerprint.etagHash(part.etag);
      part.status = 'succeeded';
      cp.parts.push(part);
      await store.save(cp);
      const loaded = await store.load('uuid-1', 42);
      expect(loaded !== undefined).assertTrue();
      expect(loaded!.uploadId).assertEqual('UPLOAD-ID-SECRET');
      expect(loaded!.uploadIdHash.length).assertEqual(16);
      expect(loaded!.uploadIdHash.indexOf('UPLOAD') < 0).assertTrue();
      await store.remove('uuid-1', 42);
      const gone = await store.load('uuid-1', 42);
      expect(gone === undefined).assertTrue();
    });

    it('production_policy_only_simple_multipart_v1', 0, () => {
      const simple = FileUploadMode.select(1024);
      const multipart = FileUploadMode.select(9 * 1024 * 1024);
      expect(FileUploadMode.toLogDetail(simple).indexOf('mode=simple;policy=simple-v1') === 0).assertTrue();
      expect(FileUploadMode.toLogDetail(multipart).indexOf('policy=multipart-v1') >= 0).assertTrue();
      expect(OSSSimpleUploadAdapter.POLICY_VERSION).assertEqual('simple-v1');
      // 医疗上传禁止 appendObject；生产仅 simple/multipart。
      expect(simple.mode === 'simple' || simple.mode === 'multipart').assertTrue();
    });

    it('multipart_complete_failed_localizer_retry', 0, () => {
      const err = new FileTransferError(
        'multipartCompleteFailed',
        'uploading',
        '文件正在整理，请稍后重试。',
        true
      );
      const p = FileTransferErrorLocalizer.present(err);
      expect(p.message.indexOf('整理') >= 0).assertTrue();
      expect(p.primaryAction).assertEqual('retryUpload');
    });

    it('multipart_checkpoint_invalid_forces_reselect', 0, () => {
      const err = new FileTransferError(
        'multipartCheckpointInvalid',
        'uploading',
        '文件已变化，请重新选择。',
        false
      );
      const p = FileTransferErrorLocalizer.present(err);
      expect(p.primaryAction).assertEqual('reselectFile');
      expect(p.retryable).assertEqual(false);
    });
  });
}
