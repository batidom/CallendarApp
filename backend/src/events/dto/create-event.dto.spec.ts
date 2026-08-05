import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CreateEventDto } from './create-event.dto';

async function errorsFor(payload: Record<string, unknown>) {
  const dto = plainToInstance(CreateEventDto, payload);
  return validate(dto);
}

describe('CreateEventDto', () => {
  it('accepts a minimal valid event', async () => {
    const errors = await errorsFor({ title: 'Standup' });
    expect(errors).toHaveLength(0);
  });

  it('accepts a fully populated event', async () => {
    const errors = await errorsFor({
      id: '11111111-1111-4111-8111-111111111111',
      title: 'Team sync',
      description: 'Weekly planning',
      location: 'Conference Room B',
      startTime: '2026-08-10T09:00:00.000Z',
      endTime: '2026-08-10T09:30:00.000Z',
      isAllDay: false,
      rrule: 'FREQ=WEEKLY',
      reminders: [0, 10, 1440],
      backlogOrder: 3,
    });
    expect(errors).toHaveLength(0);
  });

  it('rejects a missing title', async () => {
    const errors = await errorsFor({});
    expect(errors.some((e) => e.property === 'title')).toBe(true);
  });

  it('rejects a title over 255 characters', async () => {
    const errors = await errorsFor({ title: 'x'.repeat(256) });
    expect(errors.some((e) => e.property === 'title')).toBe(true);
  });

  it('rejects a non-UUID id', async () => {
    const errors = await errorsFor({ title: 'Standup', id: 'not-a-uuid' });
    expect(errors.some((e) => e.property === 'id')).toBe(true);
  });

  it('rejects malformed date strings', async () => {
    const errors = await errorsFor({ title: 'Standup', startTime: 'tomorrow' });
    expect(errors.some((e) => e.property === 'startTime')).toBe(true);
  });

  it('rejects negative reminder offsets', async () => {
    const errors = await errorsFor({ title: 'Standup', reminders: [-5] });
    expect(errors.some((e) => e.property === 'reminders')).toBe(true);
  });

  it('rejects more than 20 reminders', async () => {
    const errors = await errorsFor({
      title: 'Standup',
      reminders: Array(21).fill(0),
    });
    expect(errors.some((e) => e.property === 'reminders')).toBe(true);
  });

  it('rejects a negative backlogOrder', async () => {
    const errors = await errorsFor({ title: 'Standup', backlogOrder: -1 });
    expect(errors.some((e) => e.property === 'backlogOrder')).toBe(true);
  });
});
