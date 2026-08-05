// Ollama's /api/chat tool-calling uses the same JSON-schema function format
// as OpenAI's. These are the actions the assistant can take on the user's
// calendar; execution (assistant.service.ts) always goes through the same
// EventsService the REST API uses, so ownership/editor-role checks apply
// exactly as they do everywhere else in the app.

const DATE_TIME_FIELDS = {
  day: {
    type: 'string',
    description: "Date in YYYY-MM-DD, in the user's local time.",
  },
  startTime: {
    type: 'string',
    description:
      '24-hour HH:mm local time. Omit for an all-day item or one with no specific time.',
  },
  endTime: {
    type: 'string',
    description:
      '24-hour HH:mm local time. Defaults to one hour after startTime.',
  },
  isAllDay: { type: 'boolean' },
  repeat: {
    type: 'string',
    enum: ['none', 'daily', 'weekly', 'monthly', 'yearly'],
    description:
      'How the event repeats. "none" (or omitted) means it does not repeat.',
  },
  repeatInterval: {
    type: 'integer',
    description: 'e.g. 2 with weekly repeat = every 2 weeks. Defaults to 1.',
  },
  repeatWeekdays: {
    type: 'array',
    items: { type: 'string', enum: ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'] },
    description: 'Only used with weekly repeat.',
  },
  repeatUntil: {
    type: 'string',
    description: 'YYYY-MM-DD the repeat stops on. Omit for no end date.',
  },
  reminderMinutesBefore: {
    type: 'array',
    items: { type: 'integer' },
    description:
      'Minutes before start to remind, e.g. [10, 1440] for 10 minutes and 1 day before.',
  },
} as const;

export const ASSISTANT_TOOLS = [
  {
    type: 'function',
    function: {
      name: 'find_events',
      description:
        "Search the user's calendar. Always call this before update_event or delete_event to get an event's real id " +
        "— never guess one. Also use it to answer questions about what's on the calendar.",
      parameters: {
        type: 'object',
        properties: {
          titleContains: {
            type: 'string',
            description:
              'Case-insensitive substring to match against titles. Omit to match any title.',
          },
          dateFrom: {
            type: 'string',
            description: 'YYYY-MM-DD, inclusive start of range.',
          },
          dateTo: {
            type: 'string',
            description: 'YYYY-MM-DD, inclusive end of range.',
          },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_event',
      description:
        'Create a new event or task on the calendar. If a very similar event already exists, this call fails with ' +
        'an error telling you its id instead of creating anything — that means you should call update_event on ' +
        "that id instead. Only pass confirmNotDuplicate: true if you've seen that error and are sure this is " +
        'genuinely a separate, new event, not the same one. If the given time overlaps an existing timed event, ' +
        'this call also fails instead of double-booking silently — tell the user about the conflict and only ' +
        'retry with confirmOverlap: true once they say they want it anyway.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          description: { type: 'string' },
          location: { type: 'string' },
          confirmNotDuplicate: {
            type: 'boolean',
            description:
              'Only set true after a prior create_event call for this same title was rejected as a possible duplicate, and you have confirmed it is really a different event.',
          },
          confirmOverlap: {
            type: 'boolean',
            description:
              'Only set true after a prior call was rejected for overlapping an existing event, and the user has confirmed they want to schedule it anyway despite the conflict.',
          },
          ...DATE_TIME_FIELDS,
        },
        required: ['title'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'update_event',
      description:
        'Change fields on an existing event. Call find_events first to get its id. Only pass fields that should ' +
        'change. If a new day/startTime overlaps an existing timed event, this call fails instead of ' +
        'double-booking silently — tell the user about the conflict and only retry with confirmOverlap: true ' +
        'once they say they want it anyway.',
      parameters: {
        type: 'object',
        properties: {
          eventId: { type: 'string' },
          title: { type: 'string' },
          description: { type: 'string' },
          location: { type: 'string' },
          confirmOverlap: {
            type: 'boolean',
            description:
              'Only set true after a prior call was rejected for overlapping an existing event, and the user has confirmed they want to schedule it anyway despite the conflict.',
          },
          ...DATE_TIME_FIELDS,
        },
        required: ['eventId'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'delete_event',
      description:
        'Delete an event entirely. Call find_events first to get its id. Call this tool as soon as you know which ' +
        'event(s) to delete — the app itself always shows the user a confirmation dialog before anything is ' +
        'actually deleted, so do NOT ask the user to confirm in your own text reply first; that just makes them ' +
        'confirm twice. If several events match (e.g. "delete every event about bowling"), call this once per ' +
        'matching event — they will all be shown together in the one confirmation dialog.',
      parameters: {
        type: 'object',
        properties: { eventId: { type: 'string' } },
        required: ['eventId'],
      },
    },
  },
] as const;

export const DESTRUCTIVE_TOOLS = new Set(['delete_event']);
