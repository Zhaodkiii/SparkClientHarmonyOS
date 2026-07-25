import { MemberContextStore } from '../../MemberContext/Presentation/MemberContextStore';

/** 从 MemberContextStore 生成聊天可用的成员摘要（空则返回 ''）。 */
export class MemberContextSummaryBuilder {
  static build(store: MemberContextStore | undefined): string {
    if (!store) {
      return '';
    }
    const ctx = store.context;
    const selected = ctx.selectedMemberID;
    if (selected === undefined) {
      return '';
    }
    for (let i = 0; i < ctx.members.length; i++) {
      const m = ctx.members[i];
      if (m.id === selected) {
        const name = m.name.length > 0 ? m.name : `成员#${m.id}`;
        return `当前成员：${name}（id=${m.id}）`;
      }
    }
    return `当前成员 id=${selected}`;
  }

  static selectedMemberId(store: MemberContextStore | undefined): number | undefined {
    return store?.context.selectedMemberID;
  }
}
