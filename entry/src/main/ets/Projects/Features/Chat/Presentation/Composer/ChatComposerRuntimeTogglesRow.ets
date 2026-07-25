import { Member } from '../../../../Core/Domain/Entities/Member';
import {
  ChatModelReasoningContext,
  ComposerMenuActionItem,
  ComposerProviderRegistry,
  defaultModelReasoning
} from './Models/ChatComposerDraftModels';
import { ComposerTheme } from './Models/ComposerTheme';
import { util } from '@kit.ArkTS';

enum RuntimeToggleKind {
  TOOLS = 'tools',
  KNOWLEDGE = 'knowledge',
  WEB = 'web',
  REASONING = 'reasoning',
  MEMBER_PROFILE = 'memberProfile'
}

/**
 * 能力开关横条，对标 iOS ChatComposerRuntimeTogglesRow。
 * 通过 @Link 承接页面态，避免尚未落地的 ChatStateStore。
 */
@Component
export struct ChatComposerRuntimeTogglesRow {
  @Prop disabled: boolean = false;
  @Link useTools: boolean;
  @Link useKnowledgeBase: boolean;
  @Link useWebSearch: boolean;
  @Link reasoningEnabled: boolean;
  @Link reasoningEffortTier: number;
  @Prop modelReasoning: ChatModelReasoningContext = defaultModelReasoning();
  @Prop members: Member[] = [];
  @Prop boundMemberID: number = 0;
  @Prop defaultMemberID: number = 0;
  onSetMemberBinding: (memberID: number) => void = (_id: number) => {};

  @State private expandedToggle: string = '';
  private collapseToken: string = '';

  private companyUppercased(): string {
    return (this.modelReasoning.providerCompany ?? '').trim().toUpperCase();
  }

  private showsReasoningDepthMenu(): boolean {
    if (this.companyUppercased().length === 0) {
      return true;
    }
    return ComposerProviderRegistry.showsReasoningDepthMenu(this.modelReasoning.providerCompany);
  }

  private usesHighMaxReasoningEffortMenu(): boolean {
    return ComposerProviderRegistry.usesHighMaxReasoningEffortUI(this.modelReasoning.providerCompany);
  }

  private boundMember(): Member | undefined {
    if (this.boundMemberID <= 0) {
      return undefined;
    }
    return this.members.find((m: Member) => m.id === this.boundMemberID);
  }

  private lastTwoCharacters(text?: string): string {
    if (!text || text.length === 0) {
      return '未知';
    }
    if (text.length <= 2) {
      return text;
    }
    return text.slice(text.length - 2);
  }

  private reasoningEffortMenuTitle(): string {
    if (this.usesHighMaxReasoningEffortMenu()) {
      return this.reasoningEffortTier >= 3 ? '最大' : '高';
    }
    return `档位 ${this.reasoningEffortTier}`;
  }

  private scheduleAutoCollapse(kind: string): void {
    const token = util.generateRandomUUID(true);
    this.collapseToken = token;
    setTimeout(() => {
      if (this.collapseToken === token && this.expandedToggle === kind) {
        this.expandedToggle = '';
      }
    }, 1000);
  }

  private expand(kind: string): void {
    this.expandedToggle = kind;
    this.scheduleAutoCollapse(kind);
  }

  build() {
    Scroll() {
      Row({ space: 6 }) {
        this.memberProfileToggle()
        this.toolToggle()
        this.knowledgeToggle()
        this.webToggle()
        this.reasoningControls()
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .height(40)
  }

  @Builder
  private reasoningControls() {
    if (!this.modelReasoning.supportsReasoning) {
      // empty
    } else if (!this.modelReasoning.reasoningControllable) {
      this.reasoningBuiltinChip()
    } else {
      this.thinkingToggle()
    }
  }

  @Builder
  private reasoningBuiltinChip() {
    Row({ space: 4 }) {
      Text('♨').fontSize(16).fontColor(ComposerTheme.systemPurple)
      Text('内置深度思考')
        .fontSize(11)
        .fontColor(ComposerTheme.systemPurple)
        .margin({ right: 8 })
    }
    .height(32)
    .padding({ left: 8, right: 4 })
    .backgroundColor(ComposerTheme.withOpacity(ComposerTheme.systemPurple, 0.1))
    .borderRadius(20)
  }

  @Builder
  private toolToggle() {
    Row({ space: 0 }) {
      Text('⚒')
        .fontSize(18)
        .fontColor(this.useTools ? ComposerTheme.systemBrown : ComposerTheme.gray)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
        .scale({
          x: this.expandedToggle === RuntimeToggleKind.TOOLS ? 0.86 : 1,
          y: this.expandedToggle === RuntimeToggleKind.TOOLS ? 0.86 : 1
        })
      if (this.expandedToggle === RuntimeToggleKind.TOOLS) {
        Text('工具')
          .fontSize(11)
          .fontColor(this.useTools ? ComposerTheme.systemBrown : ComposerTheme.gray)
          .margin({ right: 10 })
      }
    }
    .height(32)
    .backgroundColor(this.useTools ? ComposerTheme.withOpacity(ComposerTheme.systemBrown, 0.12) : Color.Transparent)
    .borderRadius(20)
    .border({
      width: 1,
      color: this.useTools ? ComposerTheme.withOpacity(ComposerTheme.systemBrown, 0.12) : Color.Transparent
    })
    .opacity(this.disabled ? 0.5 : 1)
    .onClick(() => {
      if (this.disabled) {
        return;
      }
      this.useTools = !this.useTools;
      this.expand(RuntimeToggleKind.TOOLS);
    })
    .animation({ duration: 300, curve: Curve.Friction })
  }

  @Builder
  private knowledgeToggle() {
    Row({ space: 0 }) {
      Text('◉')
        .fontSize(18)
        .fontColor(this.useKnowledgeBase ? ComposerTheme.accent : ComposerTheme.gray)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
      if (this.expandedToggle === RuntimeToggleKind.KNOWLEDGE) {
        Text('知识库')
          .fontSize(11)
          .fontColor(this.useKnowledgeBase ? ComposerTheme.accent : ComposerTheme.gray)
          .margin({ right: 10 })
      }
    }
    .height(32)
    .backgroundColor(this.useKnowledgeBase ? ComposerTheme.withOpacity(ComposerTheme.accent, 0.12) : Color.Transparent)
    .borderRadius(20)
    .opacity(this.disabled ? 0.5 : 1)
    .onClick(() => {
      if (this.disabled) {
        return;
      }
      this.useKnowledgeBase = !this.useKnowledgeBase;
      this.expand(RuntimeToggleKind.KNOWLEDGE);
    })
    .animation({ duration: 300, curve: Curve.Friction })
  }

  @Builder
  private webToggle() {
    Row({ space: 0 }) {
      Text('◎')
        .fontSize(18)
        .fontColor(this.useWebSearch ? ComposerTheme.systemTeal : ComposerTheme.gray)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
      if (this.expandedToggle === RuntimeToggleKind.WEB) {
        Text('联网')
          .fontSize(11)
          .fontColor(this.useWebSearch ? ComposerTheme.systemTeal : ComposerTheme.gray)
          .margin({ right: 10 })
      }
    }
    .height(32)
    .backgroundColor(this.useWebSearch ? ComposerTheme.withOpacity(ComposerTheme.systemTeal, 0.12) : Color.Transparent)
    .borderRadius(20)
    .opacity(this.disabled ? 0.5 : 1)
    .onClick(() => {
      if (this.disabled) {
        return;
      }
      this.useWebSearch = !this.useWebSearch;
      this.expand(RuntimeToggleKind.WEB);
    })
    .animation({ duration: 300, curve: Curve.Friction })
  }

  @Builder
  private thinkingToggle() {
    Row({ space: 0 }) {
      Text('♨')
        .fontSize(18)
        .fontColor(this.reasoningEnabled ? ComposerTheme.systemPurple : ComposerTheme.gray)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
        .scale({
          x: this.expandedToggle === RuntimeToggleKind.REASONING ? 0.86 : 1,
          y: this.expandedToggle === RuntimeToggleKind.REASONING ? 0.86 : 1
        })
      if (this.expandedToggle === RuntimeToggleKind.REASONING) {
        Text('深度思考')
          .fontSize(11)
          .fontColor(this.reasoningEnabled ? ComposerTheme.systemPurple : ComposerTheme.gray)
          .margin({ right: 4 })
      }
      if (this.reasoningEnabled && this.showsReasoningDepthMenu()) {
        Text(`▾ ${this.reasoningEffortMenuTitle()}`)
          .fontSize(11)
          .fontColor(ComposerTheme.systemPurple)
          .margin({ right: 8 })
          .bindMenu(this.reasoningEffortMenuItems())
      }
    }
    .height(32)
    .backgroundColor(this.reasoningEnabled ? ComposerTheme.withOpacity(ComposerTheme.systemPurple, 0.12) : Color.Transparent)
    .borderRadius(20)
    .border({
      width: 1,
      color: this.reasoningEnabled ? ComposerTheme.withOpacity(ComposerTheme.systemPurple, 0.12) : Color.Transparent
    })
    .opacity(this.disabled ? 0.5 : 1)
    .onClick(() => {
      if (this.disabled) {
        return;
      }
      this.reasoningEnabled = !this.reasoningEnabled;
      this.expand(RuntimeToggleKind.REASONING);
    })
    .animation({ duration: 300, curve: Curve.Friction })
  }

  private reasoningEffortMenuItems(): ComposerMenuActionItem[] {
    if (this.usesHighMaxReasoningEffortMenu()) {
      const high: ComposerMenuActionItem = new ComposerMenuActionItem('高', () => {
        this.reasoningEffortTier = 2;
      });
      const max: ComposerMenuActionItem = new ComposerMenuActionItem('最大', () => {
        this.reasoningEffortTier = 3;
      });
      const items: ComposerMenuActionItem[] = [];
      items.push(high);
      items.push(max);
      return items;
    }
    const tier1: ComposerMenuActionItem = new ComposerMenuActionItem('档位 1', () => {
      this.reasoningEffortTier = 1;
    });
    const tier2: ComposerMenuActionItem = new ComposerMenuActionItem('档位 2', () => {
      this.reasoningEffortTier = 2;
    });
    const tier3: ComposerMenuActionItem = new ComposerMenuActionItem('档位 3', () => {
      this.reasoningEffortTier = 3;
    });
    const items: ComposerMenuActionItem[] = [];
    items.push(tier1);
    items.push(tier2);
    items.push(tier3);
    return items;
  }

  @Builder
  private memberProfileToggle() {
    Row({ space: 0 }) {
      Text('☺')
        .fontSize(18)
        .fontColor(this.boundMemberID > 0 ? ComposerTheme.systemGreen : ComposerTheme.gray)
        .width(30)
        .height(30)
        .textAlign(TextAlign.Center)
      if (this.expandedToggle === RuntimeToggleKind.MEMBER_PROFILE) {
        Text('成员档案')
          .fontSize(11)
          .fontColor(this.boundMemberID > 0 ? ComposerTheme.systemGreen : ComposerTheme.gray)
          .margin({ right: this.boundMemberID <= 0 ? 10 : 4 })
      }
      if (this.boundMemberID > 0 || this.expandedToggle === RuntimeToggleKind.MEMBER_PROFILE) {
        Text(`▾ ${this.lastTwoCharacters(this.boundMember()?.name)}`)
          .fontSize(11)
          .fontColor(ComposerTheme.systemGreen)
          .maxLines(1)
          .margin({ right: 8 })
          .bindMenu(this.memberSelectionMenuItems())
      }
    }
    .height(32)
    .backgroundColor(this.boundMemberID > 0 ? ComposerTheme.withOpacity(ComposerTheme.systemGreen, 0.12) : Color.Transparent)
    .borderRadius(20)
    .opacity(this.disabled ? 0.5 : 1)
    .onClick(() => {
      if (this.disabled) {
        return;
      }
      const next = this.boundMemberID <= 0 ? this.defaultMemberID : 0;
      this.onSetMemberBinding(next);
      this.expand(RuntimeToggleKind.MEMBER_PROFILE);
    })
    .animation({ duration: 300, curve: Curve.Friction })
  }

  private memberSelectionMenuItems(): ComposerMenuActionItem[] {
    const items: ComposerMenuActionItem[] = [];
    items.push(new ComposerMenuActionItem('不绑定', () => {
      this.onSetMemberBinding(0);
    }));
    for (let i = 0; i < this.members.length; i++) {
      const member = this.members[i];
      const memberId = member.id;
      items.push(new ComposerMenuActionItem(member.name, () => {
        this.onSetMemberBinding(memberId);
      }));
    }
    return items;
  }
}
