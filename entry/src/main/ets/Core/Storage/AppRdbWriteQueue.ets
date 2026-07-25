/**
 * 全库单写队列：ArkData RDB 同一时间仅允许一个写连接。
 * AI / 对话 / 知识库共用，禁止各模块自建写队列。
 */
export class AppRdbWriteQueue {
  private tail: Promise<void> = Promise.resolve();

  enqueue<T>(task: () => Promise<T>): Promise<T> {
    const run = this.tail.then(task, task);
    this.tail = run.then(() => {
      return;
    }, () => {
      return;
    });
    return run;
  }
}
