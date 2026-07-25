/**
 * 国家/地区区号；首期无旗帜，仅名称 + dialCode。
 */
export class PhoneRegion {
  code: string;
  dialCode: string;
  nameZh: string;
  nameEn: string;
  maxLength: number;

  constructor(code: string, dialCode: string, nameZh: string, nameEn: string, maxLength: number = 15) {
    this.code = code;
    this.dialCode = dialCode;
    this.nameZh = nameZh;
    this.nameEn = nameEn;
    this.maxLength = maxLength;
  }

  displayLabel(useZh: boolean = true): string {
    const name = useZh ? this.nameZh : this.nameEn;
    return `${name} +${this.dialCode}`;
  }

  /** E.164 风格：+{dial}{localDigits} */
  toE164(localDigits: string): string {
    const digits = localDigits.replace(/[^\d]/g, '');
    return `+${this.dialCode}${digits}`;
  }

  static china(): PhoneRegion {
    return new PhoneRegion('CN', '86', '中国', 'China', 11);
  }

  static commonRegions(): PhoneRegion[] {
    return [
      new PhoneRegion('CN', '86', '中国', 'China', 11),
      new PhoneRegion('HK', '852', '中国香港', 'Hong Kong', 8),
      new PhoneRegion('TW', '886', '中国台湾', 'Taiwan', 9),
      new PhoneRegion('JP', '81', '日本', 'Japan', 11),
      new PhoneRegion('KR', '82', '韩国', 'South Korea', 11),
      new PhoneRegion('MO', '853', '中国澳门', 'Macao', 8),
      new PhoneRegion('SG', '65', '新加坡', 'Singapore', 8),
      new PhoneRegion('MY', '60', '马来西亚', 'Malaysia', 10),
      new PhoneRegion('TH', '66', '泰国', 'Thailand', 9),
      new PhoneRegion('ID', '62', '印度尼西亚', 'Indonesia', 12),
      new PhoneRegion('PH', '63', '菲律宾', 'Philippines', 10),
      new PhoneRegion('VN', '84', '越南', 'Vietnam', 10)
    ];
  }

  static isPhoneReady(localDigits: string, minLen: number = 6): boolean {
    const digits = localDigits.replace(/[^\d]/g, '');
    return digits.length >= minLen;
  }
}
