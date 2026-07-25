/**
 * 亲属关系目录。与 iOS MemberRelationshipCatalog 对齐。
 */
export class MemberRelationshipOption {
  code: string = '';
  title: string = '';
  inferredGender?: string;

  constructor(code: string, title: string, inferredGender?: string) {
    this.code = code;
    this.title = title;
    this.inferredGender = inferredGender;
  }
}

export class MemberRelationshipCatalog {
  static readonly DEFAULT_CODE: string = 'self';
  static readonly UNSET_GENDER: string = '';

  static readonly ROWS: string[][] = [
    ['father', 'mother', 'husband', 'wife'],
    ['son', 'daughter', 'older_brother', 'younger_brother'],
    ['older_sister', 'younger_sister', 'grandfather', 'grandmother'],
    ['maternal_grandfather', 'maternal_grandmother', 'self', 'other']
  ];

  static isSelectableGender(gender: string): boolean {
    const g = gender.toLowerCase();
    return g === 'male' || g === 'female';
  }

  static option(code: string): MemberRelationshipOption {
    switch (code) {
      case 'father':
        return new MemberRelationshipOption(code, '父亲', 'male');
      case 'mother':
        return new MemberRelationshipOption(code, '母亲', 'female');
      case 'husband':
        return new MemberRelationshipOption(code, '丈夫', 'male');
      case 'wife':
        return new MemberRelationshipOption(code, '妻子', 'female');
      case 'son':
        return new MemberRelationshipOption(code, '儿子', 'male');
      case 'daughter':
        return new MemberRelationshipOption(code, '女儿', 'female');
      case 'older_brother':
        return new MemberRelationshipOption(code, '哥哥', 'male');
      case 'younger_brother':
        return new MemberRelationshipOption(code, '弟弟', 'male');
      case 'older_sister':
        return new MemberRelationshipOption(code, '姐姐', 'female');
      case 'younger_sister':
        return new MemberRelationshipOption(code, '妹妹', 'female');
      case 'grandfather':
        return new MemberRelationshipOption(code, '爷爷', 'male');
      case 'grandmother':
        return new MemberRelationshipOption(code, '奶奶', 'female');
      case 'maternal_grandfather':
        return new MemberRelationshipOption(code, '外公', 'male');
      case 'maternal_grandmother':
        return new MemberRelationshipOption(code, '外婆', 'female');
      case 'self':
        return new MemberRelationshipOption(code, '本人', undefined);
      default:
        return new MemberRelationshipOption('other', '其他', undefined);
    }
  }

  static compatibleCode(from: string): string {
    const normalized = from.trim().toLowerCase();
    switch (normalized) {
      case '本人':
        return 'self';
      case '爸爸':
        return 'father';
      case '妈妈':
        return 'mother';
      case '老公':
        return 'husband';
      case '老婆':
        return 'wife';
      case '儿子':
        return 'son';
      case '女儿':
        return 'daughter';
      case '哥哥':
        return 'older_brother';
      case '弟弟':
        return 'younger_brother';
      case '姐姐':
        return 'older_sister';
      case '妹妹':
        return 'younger_sister';
      case '爷爷':
        return 'grandfather';
      case '奶奶':
        return 'grandmother';
      case '外公':
        return 'maternal_grandfather';
      case '外婆':
        return 'maternal_grandmother';
      case 'self':
      case 'father':
      case 'mother':
      case 'husband':
      case 'wife':
      case 'son':
      case 'daughter':
      case 'older_brother':
      case 'younger_brother':
      case 'older_sister':
      case 'younger_sister':
      case 'grandfather':
      case 'grandmother':
      case 'maternal_grandfather':
      case 'maternal_grandmother':
      case 'other':
        return normalized;
      default:
        return 'other';
    }
  }

  static displayTitle(relationship: string): string {
    return MemberRelationshipCatalog.option(MemberRelationshipCatalog.compatibleCode(relationship)).title;
  }

  static flatCodes(): string[] {
    const out: string[] = [];
    for (let r = 0; r < MemberRelationshipCatalog.ROWS.length; r++) {
      const row = MemberRelationshipCatalog.ROWS[r];
      for (let c = 0; c < row.length; c++) {
        out.push(row[c]);
      }
    }
    return out;
  }
}
