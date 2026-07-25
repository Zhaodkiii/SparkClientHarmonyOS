import { NetworkRequest, NetworkStrategy, QueryItem, RetryConfig } from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { FileStorageDecode } from '../../../../../Core/FileStorage/FileStorageDecode';
import {
  FileBusinessUpdateBody,
  FileRegistrationBody,
  FileDownloadUrlPayload,
  ManagedFileRecord
} from '../../../../../Core/FileStorage/FileStorageModels';

export class FileAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  async list(
    businessType?: string,
    businessId?: string,
    isPublic?: boolean,
    accountScope: string = 'anon'
  ): Promise<ManagedFileRecord[]> {
    const query: QueryItem[] = [];
    if (businessType && businessType.length > 0) {
      query.push(new QueryItem('business_type', businessType));
    }
    if (businessId && businessId.length > 0) {
      query.push(new QueryItem('business_id', businessId));
    }
    if (isPublic !== undefined) {
      query.push(new QueryItem('is_public', isPublic ? '1' : '0'));
    }
    const serial =
      `files.list.${accountScope}.${businessType ?? ''}.${businessId ?? ''}.${isPublic === undefined ? '' : (isPublic ? '1' : '0')}`;
    const op = new CacheableSupportNetworkOperation(
      'File.List',
      'FileAPI',
      new NetworkRequest(
        'GET',
        '/api/v1/files/',
        new NetworkStrategy(true, true, serial, true, 'normal', RetryConfig.defaultConfig(), 120000),
        query
      )
    );
    return this.configuration.executeDecoded(op, (data) => FileStorageDecode.decodeList(data));
  }

  async register(body: FileRegistrationBody): Promise<ManagedFileRecord> {
    const serial = `files.register.${body.file_uuid}`;
    const op = new CacheableSupportNetworkOperation(
      'File.Register',
      'FileAPI',
      new NetworkRequest(
        'POST',
        '/api/v1/files/register/',
        new NetworkStrategy(true, false, serial, false, 'high', RetryConfig.disabled()),
        [],
        {},
        body
      )
    );
    return this.configuration.executeDecoded(op, (data) => FileStorageDecode.decodeRecord(data));
  }

  async updateBusinessBinding(
    fileId: number,
    businessType: string,
    businessId: string
  ): Promise<ManagedFileRecord> {
    const body = new FileBusinessUpdateBody();
    body.file_id = fileId;
    body.business_type = businessType;
    body.business_id = businessId;
    const op = new CacheableSupportNetworkOperation(
      'File.UpdateBinding',
      'FileAPI',
      new NetworkRequest(
        'PATCH',
        '/api/v1/files/business/update/',
        new NetworkStrategy(true, false, `files.bind.${fileId}`, false, 'normal', RetryConfig.disabled()),
        [],
        {},
        body
      )
    );
    return this.configuration.executeDecoded(op, (data) => FileStorageDecode.decodeRecord(data));
  }

  async downloadUrl(fileId: number, expiresSeconds: number = 3600): Promise<FileDownloadUrlPayload> {
    const query: QueryItem[] = [new QueryItem('expires', `${expiresSeconds}`)];
    const op = new CacheableSupportNetworkOperation(
      'File.DownloadURL',
      'FileAPI',
      new NetworkRequest(
        'GET',
        `/api/v1/files/${fileId}/download-url/`,
        new NetworkStrategy(true, false, `files.url.${fileId}`, true, 'high', RetryConfig.defaultConfig()),
        query
      )
    );
    return this.configuration.executeDecoded(op, (data) => FileStorageDecode.decodeDownloadUrl(data));
  }

  async remove(fileId: number): Promise<number> {
    const op = new CacheableSupportNetworkOperation(
      'File.Delete',
      'FileAPI',
      new NetworkRequest(
        'DELETE',
        `/api/v1/files/${fileId}/`,
        new NetworkStrategy(true, false, `files.delete.${fileId}`, false, 'normal', RetryConfig.disabled())
      )
    );
    return this.configuration.executeDecoded(op, (data) => FileStorageDecode.decodeDeleteId(data));
  }
}
