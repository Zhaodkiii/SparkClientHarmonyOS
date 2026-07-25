import { describe, it, expect } from '@ohos/hypium';
import { AIPromptKeywords } from '../../../main/ets/Core/AI/Runtime/AIPromptKeywords';
import { AIPromptL10n } from '../../../main/ets/Core/AI/Runtime/AIPromptL10n';
import { ChatSystemPromptResolver } from '../../../main/ets/Core/AI/Runtime/ChatSystemPromptResolver';
import { LocalSmallTask } from '../../../main/ets/Core/AI/Domain/AIConfigModels';
import { ToolPreviewPrompt } from '../../../main/ets/Projects/Features/Chat/Presentation/ToolInteraction/Models/ToolPreviewPrompt';
import { ToolInteractionCoordinator } from '../../../main/ets/Projects/Features/Chat/Presentation/ToolInteraction/ToolInteractionCoordinator';
import { ToolInteractionSnapshot } from '../../../main/ets/Projects/Features/Chat/Presentation/ToolInteraction/ToolInteractionSnapshot';

export default function promptRuntimeAlignTest() {
  describe('PromptRuntimeAlign_HOS_0002', () => {
    it('ai_prompt_keywords_contains_and_setting', 0, () => {
      const base = 'line1\n{{CURRENT_DATE}}\nline2';
      expect(AIPromptKeywords.contains(AIPromptKeywords.currentDate, base)).assertTrue();
      const removed = AIPromptKeywords.setting(AIPromptKeywords.currentDate, false, base);
      expect(AIPromptKeywords.contains(AIPromptKeywords.currentDate, removed)).assertFalse();
      const added = AIPromptKeywords.setting(AIPromptKeywords.currentDate, true, removed);
      expect(AIPromptKeywords.contains(AIPromptKeywords.currentDate, added)).assertTrue();
      const deduped = AIPromptKeywords.setting(
        AIPromptKeywords.currentDate,
        true,
        `${AIPromptKeywords.currentDate}\nfoo\n${AIPromptKeywords.currentDate}`
      );
      const parts = deduped.split('\n').filter((l: string) => l === AIPromptKeywords.currentDate);
      expect(parts.length === 1).assertTrue();
    });

    it('prompts_strings_parser_and_format', 0, () => {
      const sample =
        '"ai.prompt.chat.system" = "你好\\n{{CURRENT_DATE}}";\n' +
        '"ai.prompt.context.line" = "- [%@] %@：%@";\n';
      const table = AIPromptL10n.parseStringsFile(sample);
      expect(table.get('ai.prompt.chat.system') === '你好\n{{CURRENT_DATE}}').assertTrue();
      const formatted = AIPromptL10n.format(table.get('ai.prompt.context.line') as string, [
        '2026-01-01', '标题', '摘要'
      ]);
      expect(formatted === '- [2026-01-01] 标题：摘要').assertTrue();
      const missing = new AIPromptL10n('en').prompt('ai.prompt.__missing__', 'FALLBACK');
      expect(missing === 'FALLBACK').assertTrue();
      const toolMissing = new AIPromptL10n('en').tool('tool.summary.__missing__');
      expect(toolMissing === 'tool.summary.__missing__').assertTrue();
    });

    it('chat_system_prompt_priority_small_task_and_date', 0, () => {
      const resolver = new ChatSystemPromptResolver('DEFAULT');
      expect(resolver.resolve('SESSION', 'AGENT', undefined) === 'AGENT').assertTrue();
      expect(resolver.resolve('SESSION', undefined, undefined) === 'SESSION').assertTrue();
      expect(resolver.resolve(undefined, undefined, undefined) === 'DEFAULT').assertTrue();

      const task = new LocalSmallTask();
      task.code = 't1';
      task.name = '今日总结';
      task.brief = '简介';
      task.prompt = '请总结今日健康';
      task.toolList = ['fetch_step_details', 'query_weather'];
      const withTask = resolver.resolveWithTask('SESSION', 'AGENT', task);
      expect(withTask.indexOf('【小任务】') >= 0).assertTrue();
      expect(withTask.indexOf('今日总结') >= 0).assertTrue();
      expect(withTask.indexOf('【任务简介】') >= 0).assertTrue();
      expect(withTask.indexOf('【任务设定 / Prompt】') >= 0).assertTrue();
      expect(withTask.indexOf('fetch_step_details, query_weather') >= 0).assertTrue();
      expect(withTask.indexOf('AGENT') < 0).assertTrue();

      const withDate = resolver.resolve(`今天是 ${AIPromptKeywords.currentDate}`, undefined, undefined);
      expect(withDate.indexOf(AIPromptKeywords.currentDate) < 0).assertTrue();
      const hasZh = withDate.indexOf('当前日期：') >= 0;
      const hasEn = withDate.indexOf('Current date:') >= 0;
      expect(hasZh || hasEn).assertTrue();
    });

    it('tool_preview_display_text_sorted', 0, () => {
      const args: Record<string, string> = {};
      args['z'] = '3';
      args['a'] = '1';
      args['m'] = '  ';
      const text = ToolPreviewPrompt.displayText(args);
      expect(text.indexOf('a: 1') === 0).assertTrue();
      expect(text.indexOf('m\n') >= 0 || text.endsWith('m')).assertTrue();
      expect(text.indexOf('z: 3') >= 0).assertTrue();
    });

    it('tool_interaction_coordinator_present_dismiss', 0, () => {
      const coord = new ToolInteractionCoordinator();
      let last: ToolInteractionSnapshot | undefined = undefined;
      let cleared = false;
      coord.setOnChanged((s?: ToolInteractionSnapshot) => {
        last = s;
        if (s === undefined) {
          cleared = true;
        }
      });
      const preview = ToolPreviewPrompt.create('debug_echo', 'out', 't1', 'm1', ['b1']);
      coord.present(ToolInteractionSnapshot.toolPreview(preview));
      expect(coord.current() !== undefined).assertTrue();
      expect(last !== undefined && last.kind === 'toolPreview').assertTrue();
      coord.dismiss();
      expect(coord.current() === undefined).assertTrue();
      expect(cleared).assertTrue();
    });
  });
}
