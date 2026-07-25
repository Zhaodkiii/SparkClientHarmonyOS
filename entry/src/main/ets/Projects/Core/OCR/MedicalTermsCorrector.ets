/**
 * 医学术语保守纠错，对齐 iOS SparkMedicalTermsCorrector。
 * 只修明显 OCR 误读，不做句子改写。
 */
export class MedicalTermsCorrector {
  private static readonly sharedInstance: MedicalTermsCorrector = new MedicalTermsCorrector();

  static shared(): MedicalTermsCorrector {
    return MedicalTermsCorrector.sharedInstance;
  }

  private readonly terms: string[] = [
    'MRI', 'MRA', 'T1WI', 'T2WI', 'FLAIR', 'DWI', 'ADC', 'SWI', 'TOF-MRA',
    'CT', 'CTA', 'HRCT', 'PET-CT', '血常规', '尿常规', '肝功能', '肾功能', '甲状腺功能',
    'AFP', 'CEA', 'CA199', 'CA125', 'mmol/L', 'mg/dL', 'U/L', 'mmHg'
  ];

  private readonly patternPairs: Array<[string, string]> = [
    ['FLA[1Il]R', 'FLAIR'],
    ['T[0O]F', 'TOF'],
    ['T[1Il][一-]?W[1Il]', 'T1WI'],
    ['T[2Z][一-]?W[1Il]', 'T2WI'],
    ['DW[1Il]', 'DWI'],
    ['MR[1Il]', 'MRI']
  ];

  correct(text: string): string {
    let output = text;
    for (let i = 0; i < this.patternPairs.length; i++) {
      const pair = this.patternPairs[i];
      try {
        const regex = new RegExp(pair[0], 'gi');
        output = output.replace(regex, pair[1]);
      } catch (_e) {
        // 忽略非法 pattern，保守跳过。
      }
    }
    output = this.normalizeWhitespace(output);
    return this.fuzzyFix(output);
  }

  private fuzzyFix(text: string): string {
    let output = text;
    for (let i = 0; i < this.terms.length; i++) {
      const term = this.terms[i];
      // 仅对纯 ASCII 医学缩写做 I/O/A 混淆替换；中文词保持精确匹配。
      if (!/^[A-Za-z0-9\/\-]+$/.test(term)) {
        continue;
      }
      let pattern = '';
      for (let c = 0; c < term.length; c++) {
        const ch = term.charAt(c);
        if (ch === 'I') {
          pattern += '[IiLl1]';
        } else if (ch === 'O') {
          pattern += '[Oo0]';
        } else if (ch === 'A') {
          pattern += '[Aa4]';
        } else if (ch === '/') {
          pattern += '\\/';
        } else if (ch === '-') {
          pattern += '\\-';
        } else {
          pattern += ch;
        }
      }
      try {
        const regex = new RegExp(pattern, 'gi');
        output = output.replace(regex, term);
      } catch (_e) {
        // skip
      }
    }
    return output;
  }

  private normalizeWhitespace(text: string): string {
    const lines = text.split('\n');
    const cleaned: string[] = [];
    for (let i = 0; i < lines.length; i++) {
      cleaned.push(lines[i].replace(/[ \t]+$/g, '').replace(/^[ \t]+/g, ''));
    }
    return cleaned.join('\n').replace(/ {2,}/g, ' ');
  }
}
