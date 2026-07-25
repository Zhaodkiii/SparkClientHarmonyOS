/**
 * Markdown 正文按标题层级切块，并对超长块再切分；对齐 iOS KnowledgeChunking.swift。
 * 供嵌入管线批量请求使用（BuildKnowledgeEmbeddingsUseCase）。
 */
export class KnowledgeChunking {
  /** 返回可供嵌入 API 批量请求的文本块。 */
  static chunksForEmbedding(content: string): string[] {
    const lines = content.split(/\r\n|\r|\n/);
    let chunks: string[] = [];
    let currentChunk = '';
    let currentLevel1: string | undefined;
    let currentLevel2: string | undefined;

    for (const line of lines) {
      const trimmedLine = line.trim();
      if (trimmedLine.startsWith('#')) {
        const level = KnowledgeChunking.headerLevel(trimmedLine);
        if (level === 1) {
          if (currentChunk.length > 0) {
            chunks.push(currentChunk.trim());
          }
          currentLevel1 = trimmedLine;
          currentLevel2 = undefined;
          currentChunk = trimmedLine;
          continue;
        } else if (level === 2) {
          if (currentChunk.length > 0) {
            chunks.push(currentChunk.trim());
          }
          currentLevel2 = trimmedLine;
          currentChunk = currentLevel1 ? `${currentLevel1}\n${trimmedLine}` : trimmedLine;
          continue;
        } else if (level === 3) {
          if (currentChunk.length > 0) {
            chunks.push(currentChunk.trim());
          }
          let headerContext = '';
          if (currentLevel1) {
            headerContext += `${currentLevel1}\n`;
          }
          if (currentLevel2) {
            headerContext += `${currentLevel2}\n`;
          }
          headerContext += trimmedLine;
          currentChunk = headerContext;
          continue;
        }
      }
      if (currentChunk.length === 0) {
        currentChunk = trimmedLine;
      } else {
        currentChunk += `\n${trimmedLine}`;
      }
    }
    if (currentChunk.length > 0) {
      chunks.push(currentChunk.trim());
    }

    // 过滤只有标题、没有正文的空块（一二级标题专属规则，三级标题不受此过滤影响）。
    const bodyChunksCount = chunks.filter((c: string): boolean => KnowledgeChunking.chunkHasBody(c)).length;
    if (bodyChunksCount > 0) {
      chunks = chunks.filter((chunk: string): boolean => {
        const linesInChunk = chunk.split('\n');
        const firstLine = linesInChunk.length > 0 ? linesInChunk[0] : undefined;
        if (firstLine && firstLine.trim().startsWith('#')) {
          const level = KnowledgeChunking.headerLevel(firstLine);
          if ((level === 1 || level === 2) && !KnowledgeChunking.chunkHasBody(chunk)) {
            return false;
          }
        }
        return true;
      });
    }

    // 超长块（>1000 字）再按行切分，保留标题上下文，片段间保留约 200 字重叠。
    const maxChunkLength = 1000;
    const overlapMinLength = 200;
    const refinedChunks: string[] = [];

    for (const chunk of chunks) {
      if (chunk.length <= maxChunkLength) {
        refinedChunks.push(chunk);
        continue;
      }

      const allLines = chunk.split('\n');
      const headerLines: string[] = [];
      const bodyLines: string[] = [];
      let reachedBody = false;
      for (const line of allLines) {
        const trimmed = line.trim();
        if (!reachedBody && trimmed.startsWith('#')) {
          headerLines.push(line);
        } else {
          reachedBody = true;
          bodyLines.push(line);
        }
      }
      const headerText = headerLines.join('\n');

      const segments: string[] = [];
      let currentSegmentLines: string[] = [];
      let currentLength = 0;

      const flushSegment = (): void => {
        if (currentSegmentLines.length > 0) {
          const segmentBody = currentSegmentLines.join('\n');
          const segment = headerText.length === 0 ? segmentBody : `${headerText}\n${segmentBody}`;
          segments.push(segment.trim());
        }
      };

      let idx = 0;
      while (idx < bodyLines.length) {
        const line = bodyLines[idx];
        const lineLen = line.length + 1;
        if (currentLength + lineLen <= maxChunkLength) {
          currentSegmentLines.push(line);
          currentLength += lineLen;
          idx += 1;
        } else {
          flushSegment();
          const overlapLines: string[] = [];
          let overlapLength = 0;
          for (let i = currentSegmentLines.length - 1; i >= 0; i--) {
            const overlapLine = currentSegmentLines[i];
            overlapLines.unshift(overlapLine);
            overlapLength += overlapLine.length + 1;
            if (overlapLength >= overlapMinLength) {
              break;
            }
          }
          currentSegmentLines = overlapLines;
          currentLength = 0;
          for (const l of currentSegmentLines) {
            currentLength += l.length + 1;
          }
        }
      }
      flushSegment();
      for (const segment of segments) {
        refinedChunks.push(segment);
      }
    }

    return refinedChunks.filter((c: string): boolean => c.length > 0);
  }

  private static headerLevel(line: string): number {
    let count = 0;
    for (let i = 0; i < line.length; i++) {
      if (line.charAt(i) === '#') {
        count += 1;
      } else {
        break;
      }
    }
    return count;
  }

  private static chunkHasBody(chunk: string): boolean {
    const chunkLines = chunk.split('\n');
    const firstLine = chunkLines.length > 0 ? chunkLines[0] : undefined;
    if (firstLine && firstLine.trim().startsWith('#')) {
      const level = KnowledgeChunking.headerLevel(firstLine);
      let startIndex = 1;
      if (level === 1 && chunkLines.length > 1 && chunkLines[1].trim().startsWith('#')) {
        startIndex = 2;
      }
      for (let i = startIndex; i < chunkLines.length; i++) {
        const line = chunkLines[i].trim();
        if (line.length > 0 && !line.startsWith('#')) {
          return true;
        }
      }
      return false;
    }
    return true;
  }
}
