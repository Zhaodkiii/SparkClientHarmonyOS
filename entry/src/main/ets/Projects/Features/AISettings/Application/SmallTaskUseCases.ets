import {
  AIConfigSnapshot,
  LocalModel,
  LocalScenarioBinding,
  LocalSmallTask,
  nowIso
} from '../../../../Core/AI/Domain/AIConfigModels';

export class TaskReferenceHit {
  kind: string = '';
  label: string = '';
}

export class SmallTaskUseCases {
  static isEditable(task: LocalSmallTask): boolean {
    const s = task.source;
    return s !== 'pro' && s !== 'Service';
  }

  static upsert(snapshot: AIConfigSnapshot, task: LocalSmallTask): void {
    if (!task.code || task.code.trim().length === 0) {
      throw new Error('请填写任务 code');
    }
    if (!task.name || task.name.trim().length === 0) {
      throw new Error('请填写任务名称');
    }
    task.code = task.code.trim();
    task.name = task.name.trim();
    task.updatedAt = nowIso();
    if (!task.source || task.source.length === 0) {
      task.source = 'Local';
    }
    let found = false;
    for (let i = 0; i < snapshot.smallTasks.length; i++) {
      if (snapshot.smallTasks[i].code === task.code) {
        if (!SmallTaskUseCases.isEditable(snapshot.smallTasks[i])) {
          throw new Error('不能编辑 Pro 小任务');
        }
        snapshot.smallTasks[i] = task;
        found = true;
        break;
      }
    }
    if (!found) {
      snapshot.smallTasks.push(task);
    }
  }

  static findReferences(snapshot: AIConfigSnapshot, code: string): TaskReferenceHit[] {
    const hits: TaskReferenceHit[] = [];
    for (let i = 0; i < snapshot.scenarioBindings.length; i++) {
      const b: LocalScenarioBinding = snapshot.scenarioBindings[i];
      if (b.relatedTaskCodes && b.relatedTaskCodes.indexOf(code) >= 0) {
        const hit = new TaskReferenceHit();
        hit.kind = 'scenario';
        hit.label = `${b.scenario}/${b.modelId}`;
        hits.push(hit);
      }
    }
    for (let i = 0; i < snapshot.models.length; i++) {
      const m: LocalModel = snapshot.models[i];
      if (m.identity === 'agent' && m.briefDescription && m.briefDescription.indexOf(code) >= 0) {
        // agents may embed codes in brief; primary is bindings
      }
    }
    return hits;
  }

  static delete(snapshot: AIConfigSnapshot, code: string): void {
    const task = SmallTaskUseCases.find(snapshot, code);
    if (!task) {
      return;
    }
    if (!SmallTaskUseCases.isEditable(task)) {
      throw new Error('不能删除 Pro 小任务');
    }
    const refs = SmallTaskUseCases.findReferences(snapshot, code);
    if (refs.length > 0) {
      throw new Error(`该任务被 ${refs.length} 处引用，请先解除关联`);
    }
    snapshot.smallTasks = snapshot.smallTasks.filter((t: LocalSmallTask) => t.code !== code);
  }

  static find(snapshot: AIConfigSnapshot, code: string): LocalSmallTask | undefined {
    for (let i = 0; i < snapshot.smallTasks.length; i++) {
      if (snapshot.smallTasks[i].code === code) {
        return snapshot.smallTasks[i];
      }
    }
    return undefined;
  }

  static createBlank(): LocalSmallTask {
    const t = new LocalSmallTask();
    t.code = `local_${Date.now()}`;
    t.name = '';
    t.prompt = '';
    t.source = 'Local';
    t.isEnabled = true;
    t.updatedAt = nowIso();
    return t;
  }
}
