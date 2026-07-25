/**
 * 余弦相似度（用于查询向量与切块向量的对齐打分）；对齐 iOS KnowledgeEmbeddingSimilarity.swift。
 * 鸿蒙侧无 Accelerate/vDSP 等价 API，改用等价的纯数值实现。
 */
export class KnowledgeEmbeddingSimilarity {
  static cosine(a: number[], b: number[]): number {
    if (a.length !== b.length || a.length === 0) {
      return 0;
    }

    let dot = 0;
    let sumSqA = 0;
    let sumSqB = 0;
    for (let i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      sumSqA += a[i] * a[i];
      sumSqB += b[i] * b[i];
    }

    const denom = Math.sqrt(sumSqA) * Math.sqrt(sumSqB);
    if (denom <= 0) {
      return 0;
    }
    return dot / denom;
  }
}
