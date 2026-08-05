const FREQ_CODES: Record<string, string> = {
  daily: 'DAILY',
  weekly: 'WEEKLY',
  monthly: 'MONTHLY',
  yearly: 'YEARLY',
};

/// Builds a simple RRULE string (FREQ/INTERVAL/BYDAY/UNTIL) from the
/// assistant tool's flat repeat params — matching the subset of the format
/// the client's RecurrenceRule.decode() understands (see
/// client/lib/utils/recurrence.dart). Recurrence expansion always happens
/// client-side, so the backend never needs to interpret this string itself.
export function buildRrule(params: {
  repeat?: string;
  repeatInterval?: number;
  repeatWeekdays?: string[];
  repeatUntil?: string;
}): string | undefined {
  if (!params.repeat || params.repeat === 'none') return undefined;
  const freq = FREQ_CODES[params.repeat];
  if (!freq) return undefined;

  const parts = [`FREQ=${freq}`];
  if (params.repeatInterval && params.repeatInterval > 1) {
    parts.push(`INTERVAL=${params.repeatInterval}`);
  }
  if (freq === 'WEEKLY' && params.repeatWeekdays?.length) {
    parts.push(`BYDAY=${params.repeatWeekdays.join(',')}`);
  }
  if (params.repeatUntil) {
    const d = new Date(`${params.repeatUntil}T00:00:00Z`);
    const pad = (n: number) => n.toString().padStart(2, '0');
    parts.push(`UNTIL=${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}T235959Z`);
  }
  return parts.join(';');
}
