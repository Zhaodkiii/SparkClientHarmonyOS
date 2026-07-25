import { fileIo as fs } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

/**
 * 从用户选择的文件导入纯文本；对齐 iOS ImportKnowledgeFromFileUseCase。
 * 支持 plain / md；PDF 文本抽取在鸿蒙侧尚无 PDFKit 等价物，明确报错提示。
 */
export class ImportKnowledgeFromFileUseCase {
  async execute(fileUri: string): Promise<string> {
    const uri = fileUri.trim();
    if (uri.length === 0) {
      throw new KnowledgeImportError('readFailed', '读取文件失败：空路径');
    }
    const ext = ImportKnowledgeFromFileUseCase.pathExtension(uri);
    switch (ext) {
      case 'txt':
      case 'text':
      case 'md':
      case 'markdown':
        return ImportKnowledgeFromFileUseCase.readPlainText(uri);
      case 'pdf':
        throw new KnowledgeImportError(
          'unsupportedType',
          '暂不支持 PDF 文本抽取（鸿蒙侧尚未接入 PDF 解析库）。可改用 txt/md，或先 OCR 图片导入。'
        );
      default:
        if (ext.length === 0) {
          return ImportKnowledgeFromFileUseCase.readPlainText(uri);
        }
        throw new KnowledgeImportError('unsupportedType', `暂不支持的文件类型：${ext}`);
    }
  }

  private static pathExtension(uri: string): string {
    const clean = uri.split('?')[0];
    const slash = clean.lastIndexOf('/');
    const name = slash >= 0 ? clean.substring(slash + 1) : clean;
    let decoded = name;
    try {
      decoded = decodeURIComponent(name);
    } catch (_e) {
      decoded = name;
    }
    const dot = decoded.lastIndexOf('.');
    if (dot < 0 || dot === decoded.length - 1) {
      return '';
    }
    return decoded.substring(dot + 1).toLowerCase();
  }

  private static readPlainText(uri: string): string {
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      try {
        const stat = fs.statSync(uri);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
        const text = decoder.decodeToString(new Uint8Array(buf));
        if (text === undefined || text === null) {
          throw new KnowledgeImportError('readFailed', '读取文件失败：无法按 UTF-8 解码');
        }
        return text;
      } finally {
        fs.closeSync(file);
      }
    } catch (err) {
      if (err instanceof KnowledgeImportError) {
        throw err;
      }
      const reason = err instanceof Error ? err.message : `${err}`;
      throw new KnowledgeImportError('readFailed', `读取文件失败：${reason}`);
    }
  }
}

/**
 * 拉取网页 HTML 并转为可读纯文本；对齐 iOS ImportKnowledgeFromWebUseCase。
 * 鸿蒙无 NSAttributedString HTML 解析，使用轻量标签剥离近似等价。
 */
export class ImportKnowledgeFromWebUseCase {
  async execute(urlString: string): Promise<string> {
    const trimmed = urlString.trim();
    if (trimmed.length === 0 ||
      !(trimmed.startsWith('http://') || trimmed.startsWith('https://'))) {
      throw new KnowledgeImportError('invalidURL', '无效的网址。');
    }

    const httpRequest = http.createHttp();
    try {
      const result = await httpRequest.request(trimmed, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 30000
      });
      const code = result.responseCode;
      if (code < 200 || code >= 300) {
        throw new KnowledgeImportError('httpFailed', `网页请求失败（${code}）。`);
      }
      const body = `${result.result ?? ''}`;
      if (body.trim().length === 0) {
        throw new KnowledgeImportError('emptyBody', '页面内容为空。');
      }
      return ImportKnowledgeFromWebUseCase.htmlToPlainText(body);
    } finally {
      httpRequest.destroy();
    }
  }

  private static htmlToPlainText(html: string): string {
    let text = html;
    // 去掉 script / style 块
    text = text.replace(/<script[\s\S]*?<\/script>/gi, ' ');
    text = text.replace(/<style[\s\S]*?<\/style>/gi, ' ');
    // 块级标签换成换行
    text = text.replace(/<\/?(p|div|br|li|h[1-6]|tr|section|article)[^>]*>/gi, '\n');
    // 其余标签去掉
    text = text.replace(/<[^>]+>/g, ' ');
    // 常见实体
    text = text
      .replace(/&nbsp;/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'")
      .replace(/\u00a0/g, ' ');
    // 压缩空白
    text = text
      .replace(/[ \t]+\n/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .replace(/[ \t]{2,}/g, ' ')
      .trim();
    if (text.length === 0) {
      throw new KnowledgeImportError('emptyBody', '页面内容为空。');
    }
    return text;
  }
}

export class KnowledgeImportError extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}
