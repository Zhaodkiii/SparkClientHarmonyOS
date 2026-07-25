import { ChatBlockKind, ChatMessage, ChatMessageBlock, ChatThread } from '../Domain/ChatModels';

/** 线程列表投影：UI 不直接拼接数据库字段。 */
export class ChatThreadListItem {
  id: string = '';
  title: string = '新对话';
  preview: string = '暂无消息';
  updatedAt: string = '';
  isPinned: boolean = false;
  iconName: string = '💬';
  iconColor: string = '#DCEBFF';
  static from(thread: ChatThread, latest?: ChatMessage): ChatThreadListItem {
    const item = new ChatThreadListItem();
    item.id = thread.clientId; item.title = thread.title || '新对话'; item.updatedAt = thread.updatedAt;
    item.isPinned = thread.isPinned; item.iconName = thread.iconName || '💬'; item.iconColor = thread.iconColorName || '#DCEBFF';
    item.preview = latest ? ChatMessagePreview.text(latest) : '开始一段新的健康对话';
    return item;
  }
}

export class ChatMessagePreview {
  static text(message: ChatMessage): string {
    if (message.text.trim().length > 0) return message.text.trim();
    if (message.attachmentsJson !== '[]') return '附件消息';
    for (let i = 0; i < message.blocks.length; i++) {
      if (message.blocks[i].text.trim().length > 0) return message.blocks[i].text.trim();
    }
    return message.deliveryStatus === 'sending' ? '正在生成…' : '已发送消息';
  }
}

export class ChatMessageUIState {
  isDeleted: boolean = false;
  translatedText: string = '';
  translating: boolean = false;
  reasoningExpanded: boolean = false;
  savedCardIDs: string[] = [];
}

export class ChatBlockPresentation {
  block: ChatMessageBlock;
  title: string;
  accent: string;
  constructor(block: ChatMessageBlock, title: string, accent: string) {
    this.block = block; this.title = title; this.accent = accent;
  }
  static from(block: ChatMessageBlock): ChatBlockPresentation {
    let title = '智能内容';
    switch (block.kind) {
      case 'deepThought': title = '思考过程'; break;
      case 'tool': title = '工具调用'; break;
      case 'toolPresentation': title = '工具结果'; break;
      case 'imageGallery': title = '图片'; break;
      case 'fileAttachments': title = '附件'; break;
      case 'knowledgeCards': title = '知识卡片'; break;
      case 'healthCards': title = '健康数据'; break;
      case 'structuredHealthCards': title = '健康卡片'; break;
      case 'sleepVisualization': title = '睡眠'; break;
      case 'nutritionCards': title = '营养分析'; break;
      case 'workoutVisualization': title = '运动分析'; break;
      case 'captureCard': title = '采集信息'; break;
      case 'smallTaskCard': title = '小任务'; break;
      case 'taskCards': title = '任务'; break;
      case 'healthResourceReference': title = '健康资料'; break;
      case 'medicalRiskNotice': title = '风险提示'; break;
      case 'medicalDisclaimerCard': title = '医疗免责声明'; break;
      case 'assistantStatusCard': title = '状态'; break;
      case 'text': title = ''; break;
      default: title = '智能内容';
    }
    const accent = block.status === 'failed' ? '#D14343' : block.status === 'pending' || block.status === 'streaming' ? '#B7791F' : '#3973B9';
    return new ChatBlockPresentation(block, title, accent);
  }
}
