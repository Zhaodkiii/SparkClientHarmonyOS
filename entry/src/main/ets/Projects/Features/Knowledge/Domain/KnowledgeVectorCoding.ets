/**
 * `number[]`（Float32 向量）与 RDB `BLOB` 列互转；对齐 iOS KnowledgeVectorCoding.swift。
 * 供 knowledge_chunk.vector_data 使用。
 */
export class KnowledgeVectorCoding {
  static encode(vector: number[]): Uint8Array {
    const floats = new Float32Array(vector);
    return new Uint8Array(floats.buffer);
  }

  static decode(data: Uint8Array): number[] | undefined {
    const floatSize = 4;
    if (data.length < floatSize || data.length % floatSize !== 0) {
      return undefined;
    }
    const count = data.length / floatSize;
    // Uint8Array 可能是更大 ArrayBuffer 的切片，需按 byteOffset/length 精确取用。
    const floats = new Float32Array(data.buffer, data.byteOffset, count);
    return Array.from(floats);
  }
}
