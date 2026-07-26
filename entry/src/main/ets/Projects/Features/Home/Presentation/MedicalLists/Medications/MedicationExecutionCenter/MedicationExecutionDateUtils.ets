export function medicationStartOfDay(date: Date): Date {
  const d = new Date(date.getTime());
  d.setHours(0, 0, 0, 0);
  return d;
}

export function medicationIsSameDay(a: Date, b: Date): boolean {
  return medicationStartOfDay(a).getTime() === medicationStartOfDay(b).getTime();
}

export function medicationAddDays(date: Date, offset: number): Date {
  const d = new Date(date.getTime());
  d.setDate(d.getDate() + offset);
  return medicationStartOfDay(d);
}

export function medicationParseDate(value: string | undefined): Date | undefined {
  if (value === undefined || value.trim().length === 0) {
    return undefined;
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return undefined;
  }
  return parsed;
}

export function medicationEncodeISO8601(date: Date): string {
  return date.toISOString();
}
