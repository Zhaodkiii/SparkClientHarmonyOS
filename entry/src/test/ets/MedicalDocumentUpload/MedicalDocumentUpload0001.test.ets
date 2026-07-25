import { describe, it, expect } from '@ohos/hypium';
import { FileTransferError, ManagedFileRecord } from '../../../main/ets/Core/FileStorage/FileStorageModels';
import { MedicalAttachmentInput } from '../../../main/ets/Projects/Features/Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalDocumentUploadEntryFactory } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Application/MedicalDocumentUploadEntryFactory';
import {
  InMemoryMedicalDocumentUploadCheckpointStore,
  MedicalCheckpointFileSnapshot,
  MedicalDocumentUploadCheckpoint
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Application/MedicalDocumentUploadCheckpointStore';
import { MedicalDocumentUploadErrorNormalizer } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentUploadErrors';
import {
  MedicalDocumentUploadEntrySource,
  MedicalUploadLocalFile
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentUploadModels';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';

export default function medicalDocumentUpload0001Test() {
  describe('HOS_MED_UPLOAD_0001', () => {
    it('entry_factory_home_carries_member_and_source', 0, () => {
      const entry = MedicalDocumentUploadEntryFactory.home(42, '张三', MedicalDocumentKind.AUTO);
      expect(entry.source).assertEqual(MedicalDocumentUploadEntrySource.HOME);
      expect(entry.memberId).assertEqual(42);
      expect(entry.memberName).assertEqual('张三');
      expect(entry.preferredKind).assertEqual(MedicalDocumentKind.AUTO);
    });

    it('error_normalizer_maps_registration_pending', 0, () => {
      const err = new FileTransferError(
        'registrationPending',
        'registering',
        '文件登记未完成',
        true
      );
      const stage = MedicalDocumentUploadErrorNormalizer.normalize(err);
      expect(stage.stage).assertEqual('file_register');
      expect(stage.code).assertEqual('medical.upload.file_register_pending');
      expect(stage.recoverable).assertEqual(true);
    });

    it('error_normalizer_maps_ocr_pending', 0, () => {
      const stage = MedicalDocumentUploadErrorNormalizer.normalize(new Error('OCR_PENDING'));
      expect(stage.stage).assertEqual('ocr_pending');
      expect(stage.code).assertEqual('medical.upload.ocr.pending');
      expect(stage.recoverable).assertEqual(true);
    });

    it('checkpoint_store_save_load_and_latest', 0, async () => {
      const store = new InMemoryMedicalDocumentUploadCheckpointStore();
      const snap = new MedicalDocumentUploadCheckpoint();
      snap.uploadSessionId = 'sess_1';
      snap.accountId = 7;
      snap.memberId = 3;
      snap.source = MedicalDocumentUploadEntrySource.HOME;
      snap.stage = 'uploaded';
      snap.updatedAt = '2026-07-24T00:00:00.000Z';
      const file = new MedicalCheckpointFileSnapshot();
      file.localId = 'local_1';
      file.uri = 'file://a.jpg';
      file.displayName = 'a.jpg';
      file.mimeType = 'image/jpeg';
      file.remoteFileId = 99;
      file.fileUuid = 'uuid-a';
      snap.uploadedFiles = [file];
      snap.selectedFiles = [file];
      await store.save(snap);

      const loaded = await store.load('sess_1');
      expect(loaded !== undefined).assertTrue();
      expect(loaded!.uploadedFiles.length).assertEqual(1);
      expect(loaded!.uploadedFiles[0].remoteFileId).assertEqual(99);

      const latest = await store.loadLatest(7, 3);
      expect(latest !== undefined).assertTrue();
      expect(latest!.uploadSessionId).assertEqual('sess_1');

      await store.clear('sess_1');
      const afterClear = await store.load('sess_1');
      expect(afterClear === undefined).assertTrue();
    });

    it('local_file_attachment_roundtrip_preserves_remote', 0, () => {
      const input = new MedicalAttachmentInput();
      input.previewId = 'p1';
      input.sourceUri = 'file://x.pdf';
      input.originalName = 'x.pdf';
      input.mimeType = 'application/pdf';
      const remote = new ManagedFileRecord();
      remote.id = 88;
      remote.fileUuid = 'uuid-x';
      remote.fileSize = 1024;
      remote.fileMd5 = 'md5';
      input.remoteFile = remote;

      const local = MedicalUploadLocalFile.fromAttachment(input);
      expect(local.uploadState).assertEqual('uploaded');
      expect(local.localId).assertEqual('p1');
      const back = local.toAttachment();
      expect(back.remoteFile!.id).assertEqual(88);
      expect(back.originalName).assertEqual('x.pdf');
    });

    it('checkpoint_snapshot_to_attachment_restores_remote_id', 0, () => {
      const snap = new MedicalCheckpointFileSnapshot();
      snap.localId = 'l2';
      snap.uri = 'file://b.png';
      snap.displayName = 'b.png';
      snap.mimeType = 'image/png';
      snap.remoteFileId = 77;
      snap.fileUuid = 'uuid-b';
      const attachment = snap.toAttachment();
      expect(attachment.previewId).assertEqual('l2');
      expect(attachment.remoteFile!.id).assertEqual(77);
      expect(attachment.remoteFile!.businessType).assertEqual('medical_document_upload_source');
    });
  });
}
