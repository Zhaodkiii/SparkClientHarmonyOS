/** 对齐 iOS HealthResourceToolCandidateDTO（工具候选确认用）。 */
export class HealthResourceToolCandidateDTO {
  resourceType: string = '';
  resourceId: number = 0;
  memberId: number = 0;
  title: string = '';
  occurredAt?: string;
  institution?: string;
  matchedFields: string[] = [];
  matchReason: string = '';
  confidence: number = 0;
}

/** 对齐 iOS HealthResourceToolCandidatePrompt。 */
export class HealthResourceToolCandidatePrompt {
  id: string = '';
  threadID: string = '';
  candidates: HealthResourceToolCandidateDTO[] = [];
  maxSelectable: number = 1;

  static create(
    threadID: string,
    candidates: HealthResourceToolCandidateDTO[],
    maxSelectable: number
  ): HealthResourceToolCandidatePrompt {
    const p = new HealthResourceToolCandidatePrompt();
    p.id = `${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    p.threadID = threadID;
    p.candidates = candidates;
    p.maxSelectable = Math.max(1, maxSelectable);
    return p;
  }
}
