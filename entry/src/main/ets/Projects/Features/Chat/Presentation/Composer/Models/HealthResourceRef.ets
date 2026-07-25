export interface HealthResourceIdentity {
  resourceType: string;
  resourceID: number;
  memberID: number;
  cacheKey: string;
}

export function makeHealthResourceIdentity(
  resourceType: string,
  resourceID: number,
  memberID: number
): HealthResourceIdentity {
  const identity: HealthResourceIdentity = {
    resourceType: resourceType,
    resourceID: resourceID,
    memberID: memberID,
    cacheKey: `${resourceType}:${resourceID}:${memberID}`
  };
  return identity;
}

export interface ChatHealthResourceReferencePayload {
  identity: HealthResourceIdentity;
  refIndex: number;
}

/** 对标 iOS HealthResourceRef：Composer 待发送的健康资料引用。 */
export class HealthResourceRef {
  identity: HealthResourceIdentity;
  displayTitle: string;
  displaySubtitle: string;
  typeBadge?: string;

  constructor(
    identity: HealthResourceIdentity,
    displayTitle: string,
    displaySubtitle: string,
    typeBadge?: string
  ) {
    this.identity = identity;
    this.displayTitle = displayTitle;
    this.displaySubtitle = displaySubtitle;
    this.typeBadge = typeBadge;
  }

  static fromRaw(
    resourceType: string,
    resourceID: number,
    memberID: number,
    displayTitle: string,
    displaySubtitle: string,
    typeBadge?: string
  ): HealthResourceRef {
    return new HealthResourceRef(
      makeHealthResourceIdentity(resourceType, resourceID, memberID),
      displayTitle,
      displaySubtitle,
      typeBadge
    );
  }

  get id(): string {
    return this.identity.cacheKey;
  }

  get resourceType(): string {
    return this.identity.resourceType;
  }

  get resourceID(): number {
    return this.identity.resourceID;
  }

  get memberID(): number {
    return this.identity.memberID;
  }

  toMessagePayload(refIndex: number): ChatHealthResourceReferencePayload {
    const payload: ChatHealthResourceReferencePayload = {
      identity: this.identity,
      refIndex: refIndex
    };
    return payload;
  }
}
