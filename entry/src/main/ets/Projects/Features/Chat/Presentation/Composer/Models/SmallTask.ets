import { LocalSmallTask } from '../../../../../../Core/AI/Domain/AIConfigModels';

export enum TaskSource {
  LOCAL = 'Local',
  SERVICE = 'Service'
}

export interface SmallTaskParams {
  id: number;
  name: string;
  code: string;
  brief: string;
  prompt: string;
  icon: string;
  toolList: string[];
  source: TaskSource;
}

export interface SmallTaskLocalParams {
  id: number;
  name: string;
  brief: string;
  prompt: string;
  icon: string;
  toolList: string[];
}

/** 对标 iOS SmallTask，供 ContextTaskBar 使用。 */
export class SmallTask {
  id: number = 0;
  name: string = '';
  code: string = '';
  brief: string = '';
  prompt: string = '';
  icon: string = '';
  toolList: string[] = [];
  source: TaskSource = TaskSource.LOCAL;

  static fromParams(params: SmallTaskParams): SmallTask {
    const task = new SmallTask();
    task.id = params.id;
    task.name = params.name;
    task.code = params.code;
    task.brief = params.brief;
    task.prompt = params.prompt;
    task.icon = params.icon;
    task.toolList = params.toolList;
    task.source = params.source;
    return task;
  }

  static createLocalTask(params: SmallTaskLocalParams): SmallTask {
    const full: SmallTaskParams = {
      id: params.id,
      name: params.name,
      code: `Local_${params.id}`,
      brief: params.brief,
      prompt: params.prompt,
      icon: params.icon,
      toolList: params.toolList,
      source: TaskSource.LOCAL
    };
    return SmallTask.fromParams(full);
  }

  static fromLocal(task: LocalSmallTask, index: number): SmallTask {
    const source = task.source === 'Service' ? TaskSource.SERVICE : TaskSource.LOCAL;
    const full: SmallTaskParams = {
      id: index + 1,
      name: task.name,
      code: task.code.length > 0 ? task.code : `Local_${index + 1}`,
      brief: task.brief ?? '',
      prompt: task.prompt,
      icon: task.icon ?? '',
      toolList: task.toolList.slice(),
      source: source
    };
    return SmallTask.fromParams(full);
  }

  /** 回写 LocalSmallTask，供 ChatSystemPromptResolver.resolveWithTask 使用。 */
  toLocalSmallTask(): LocalSmallTask {
    const local = new LocalSmallTask();
    local.code = this.code;
    local.name = this.name;
    local.brief = this.brief;
    local.prompt = this.prompt;
    local.icon = this.icon;
    local.toolList = this.toolList.slice();
    local.source = this.source === TaskSource.SERVICE ? 'Service' : 'Local';
    local.isEnabled = true;
    return local;
  }

  /** 无配置时的默认快捷任务，对齐旧版硬编码提示。 */
  static defaultLocalTasks(): SmallTask[] {
    const first: SmallTaskLocalParams = {
      id: 1,
      name: '今日健康总结',
      brief: '汇总今日健康要点',
      prompt: '今日健康总结',
      icon: '',
      toolList: []
    };
    const second: SmallTaskLocalParams = {
      id: 2,
      name: '睡眠恢复分析',
      brief: '分析睡眠与恢复',
      prompt: '睡眠恢复分析',
      icon: '',
      toolList: []
    };
    const third: SmallTaskLocalParams = {
      id: 3,
      name: '饮食营养评估',
      brief: '评估饮食营养',
      prompt: '饮食营养评估',
      icon: '',
      toolList: []
    };
    const fourth: SmallTaskLocalParams = {
      id: 4,
      name: '运动表现分析',
      brief: '分析运动表现',
      prompt: '运动表现分析',
      icon: '',
      toolList: []
    };
    return [
      SmallTask.createLocalTask(first),
      SmallTask.createLocalTask(second),
      SmallTask.createLocalTask(third),
      SmallTask.createLocalTask(fourth)
    ];
  }
}
