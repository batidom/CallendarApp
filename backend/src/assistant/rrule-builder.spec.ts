import { buildRrule } from './rrule-builder';

describe('buildRrule', () => {
  it('returns undefined when there is no repeat', () => {
    expect(buildRrule({})).toBeUndefined();
    expect(buildRrule({ repeat: 'none' })).toBeUndefined();
  });

  it('returns undefined for an unrecognized frequency', () => {
    expect(buildRrule({ repeat: 'fortnightly' })).toBeUndefined();
  });

  it('builds a plain daily rule', () => {
    expect(buildRrule({ repeat: 'daily' })).toBe('FREQ=DAILY');
  });

  it('includes INTERVAL only when greater than 1', () => {
    expect(buildRrule({ repeat: 'daily', repeatInterval: 1 })).toBe(
      'FREQ=DAILY',
    );
    expect(buildRrule({ repeat: 'daily', repeatInterval: 3 })).toBe(
      'FREQ=DAILY;INTERVAL=3',
    );
  });

  it('includes BYDAY only for weekly rules', () => {
    expect(
      buildRrule({ repeat: 'weekly', repeatWeekdays: ['MO', 'WE', 'FR'] }),
    ).toBe('FREQ=WEEKLY;BYDAY=MO,WE,FR');
    // BYDAY is meaningless for non-weekly frequencies, so it's dropped even if supplied.
    expect(buildRrule({ repeat: 'daily', repeatWeekdays: ['MO'] })).toBe(
      'FREQ=DAILY',
    );
  });

  it('encodes UNTIL as an end-of-day UTC timestamp', () => {
    expect(buildRrule({ repeat: 'monthly', repeatUntil: '2026-12-31' })).toBe(
      'FREQ=MONTHLY;UNTIL=20261231T235959Z',
    );
  });

  it('combines interval, weekdays, and until together in order', () => {
    expect(
      buildRrule({
        repeat: 'weekly',
        repeatInterval: 2,
        repeatWeekdays: ['TU', 'TH'],
        repeatUntil: '2027-01-15',
      }),
    ).toBe('FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH;UNTIL=20270115T235959Z');
  });

  it('pads single-digit months and days in UNTIL', () => {
    expect(buildRrule({ repeat: 'yearly', repeatUntil: '2026-03-05' })).toBe(
      'FREQ=YEARLY;UNTIL=20260305T235959Z',
    );
  });
});
