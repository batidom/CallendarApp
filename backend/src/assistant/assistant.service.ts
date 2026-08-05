import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EventsService } from '../events/events.service';
import { AssistantChatDto } from './dto/assistant-chat.dto';
import { ASSISTANT_TOOLS } from './assistant-tools';
import { OllamaClient, OllamaMessage } from './ollama-client';
import { buildRrule } from './rrule-builder';

const MAX_TOOL_ROUNDS = 5;

export interface AssistantPendingDelete {
  eventId: string;
  title: string;
  when: string;
}

export interface AssistantChatResult {
  reply: string;
  // Plural because "delete every event with X in the title" is a completely
  // normal request — each one still needs its own confirmation (the client
  // shows them all together with a single Confirm), rather than only the
  // first match getting a chance to be deleted and the rest silently
  // dropped.
  pendingDeletes: AssistantPendingDelete[];
  actionsPerformed: string[];
}

interface EventToolResult {
  id: string;
  title: string;
  day: string | null;
  startTime: string | null;
  endTime: string | null;
  // Confirmed by direct testing: given only the raw UTC startTime/endTime,
  // the model would sometimes get confused between what it was told
  // ("10:00 local") and what the tool result showed back ("08:00Z"), and
  // fabricate a second, imaginary conflicting event to explain the
  // "mismatch" rather than recognize it as the same event in a different
  // timezone representation — even though the write itself was correct and
  // the only one that happened. These pre-converted fields exist so the
  // model never has to do that conversion (or mis-do it) itself.
  startLocal: string | null;
  endLocal: string | null;
}

interface EventMutationReceipt {
  kind: 'created' | 'updated';
  event: EventToolResult;
}

@Injectable()
export class AssistantService {
  private readonly logger = new Logger(AssistantService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly eventsService: EventsService,
    private readonly ollama: OllamaClient,
  ) {}

  async chat(userId: string, dto: AssistantChatDto): Promise<AssistantChatResult> {
    const language = dto.language === 'pl' ? 'pl' : 'en';
    const messages: OllamaMessage[] = [
      { role: 'system', content: this.buildSystemPrompt(dto.clientNowLocal, language) },
      ...dto.messages,
    ];
    const actionsPerformed: string[] = [];
    // The model's own prose about what it did has repeatedly proven
    // unreliable (it can claim success on a call that errored, or one that
    // never actually ran due to a leaked/malformed tool call) — so every
    // successful create/update is recorded here and appended to the final
    // reply as a receipt built straight from what the database actually
    // did, not from what the model says it did. Keyed by event id and not
    // just appended: the model sometimes doesn't recognize its own
    // successful update_event call and repeats it several times in one
    // turn, which without dedup showed the same "✅ Updated" line 3-4 times
    // over — this keeps only the final state per event actually touched.
    const mutationsByEventId = new Map<string, EventMutationReceipt>();
    // Every delete_event call is collected here rather than acted on
    // immediately — "delete every event with X in the title" can easily
    // match more than one, and each still needs its own confirmation, so
    // the conversation keeps going (with a placeholder tool result) until
    // the model's done, then all of them go back to the client together.
    const pendingDeletes: AssistantPendingDelete[] = [];
    // Seen in practice (confirmed by direct testing): after a tool call
    // already succeeded, the model sometimes calls the exact same tool with
    // the exact same arguments again anyway — one, two, even three more
    // times in the same turn — instead of moving on to its final reply. The
    // system prompt already tells it not to; it doesn't reliably listen.
    // Each repeat adds another tool result to the context for the model to
    // reconcile in its final prose, which is what produces the rambling,
    // self-contradictory replies ("is it done? do you want me to also...")
    // users have actually seen. Tracking exact repeats here and refusing to
    // re-run them turns that into a hard stop instead of a suggestion.
    const calledThisTurn = new Set<string>();

    for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
      const reply = await this.getCleanReply(messages);

      if (!reply.tool_calls?.length) {
        const finalReply = this.containsUnexpectedScript(reply.content)
          ? this.buildRetryExhaustedMessage(language)
          : this.stripFakeReceiptLines(reply.content);
        if (this.containsUnexpectedScript(reply.content)) {
          this.logger.warn(`Assistant reply still corrupted after retries for user ${userId}`);
        }
        return {
          reply: this.appendReceipt(finalReply, [...mutationsByEventId.values()], language, dto.utcOffsetMinutes),
          pendingDeletes,
          actionsPerformed,
        };
      }

      messages.push(reply);

      for (const call of reply.tool_calls) {
        const args = this.parseArgs(call.function.arguments);
        const name = call.function.name;

        const callKey = `${name}:${JSON.stringify(args)}`;
        if (calledThisTurn.has(callKey)) {
          messages.push({
            role: 'tool',
            content: JSON.stringify({
              error:
                'You already made this exact call earlier in this turn. Do not call it again — give your final plain-text reply to the user now.',
            }),
          });
          continue;
        }
        calledThisTurn.add(callKey);

        // Narrower than the exact-repeat check above: confirmed by direct
        // testing that the model can also call update_event on the *same*
        // event more than once in a turn with genuinely different
        // arguments each time (e.g. 18:00, then reconsidering to 19:00,
        // then back), which the exact-match key above won't catch since
        // the args differ. There's never a legitimate reason to split one
        // event's changes across multiple update_event calls in the same
        // turn — every field it supports can be set in one call — so once
        // an event has been successfully updated this turn, any further
        // update_event targeting it is refused outright rather than risk
        // the model flip-flopping the same event's time back and forth.
        if (name === 'update_event' && mutationsByEventId.has(args.eventId)) {
          messages.push({
            role: 'tool',
            content: JSON.stringify({
              error:
                'This event was already updated earlier in this turn. Do not update it again — give your final plain-text reply to the user now, describing the change that was already made.',
            }),
          });
          continue;
        }

        if (name === 'delete_event') {
          const pending = await this.resolvePendingDelete(userId, args);
          if ('error' in pending) {
            messages.push({ role: 'tool', content: JSON.stringify({ error: pending.error }) });
            continue;
          }
          pendingDeletes.push(pending);
          messages.push({
            role: 'tool',
            content: JSON.stringify({ status: 'awaiting_user_confirmation', event: pending }),
          });
          continue;
        }

        const result = await this.executeTool(userId, name, args, dto.utcOffsetMinutes);
        actionsPerformed.push(name);
        messages.push({ role: 'tool', content: JSON.stringify(result) });

        if ((name === 'create_event' || name === 'update_event') && !('error' in (result as object))) {
          const event = result as EventToolResult;
          const kind = name === 'create_event' ? 'created' : 'updated';
          // A later redundant update_event on the same event should still
          // report "updated" with its latest field values, but if the
          // event was created earlier in this same turn, keep showing it
          // as "created" — that's the more useful thing for the user to
          // see, and it's still accurate.
          const existingKind = mutationsByEventId.get(event.id)?.kind;
          mutationsByEventId.set(event.id, { kind: existingKind ?? kind, event });
        }
      }
    }

    this.logger.warn(`Assistant chat hit the ${MAX_TOOL_ROUNDS}-round tool cap for user ${userId}`);
    const mutations = [...mutationsByEventId.values()];
    // The model hitting the round cap doesn't mean nothing happened — it
    // often means the opposite (it kept re-verifying or repeating a call
    // that already succeeded). Claiming total failure when the receipt
    // below shows a real change is exactly the "suspicious, contradictory
    // output" users have reported, so the message has to match which case
    // this actually is.
    const capMessage =
      mutations.length > 0
        ? language === 'pl'
          ? 'Gotowe — chociaż zajęło mi to kilka prób, poniższa zmiana została zapisana.'
          : "Done — it took a few tries, but the change below was saved."
        : language === 'pl'
          ? 'Przepraszam, nie udało mi się tego dokończyć — spróbuj sformułować to inaczej lub podzielić na mniejsze kroki.'
          : "Sorry, I couldn't finish that — could you try rephrasing or breaking it into smaller steps?";
    return {
      reply: this.appendReceipt(capMessage, mutations, language, dto.utcOffsetMinutes),
      pendingDeletes,
      actionsPerformed,
    };
  }

  // Runs a raw speech-to-text transcript through one quick, non-tool Ollama
  // pass to fix ASR disfluencies (dropped/garbled connecting words, missing
  // punctuation) before it's shown to the user as the voice command they're
  // about to send — e.g. "Ustaw dzisiaj się spotkanie" -> "Ustaw dzisiejsze
  // spotkanie". Deliberately conservative: isSafeTranscriptCleanup rejects
  // the result (falling back to the raw transcript) if it looks like the
  // model added/removed any digits or otherwise rewrote rather than just
  // repaired the sentence — a cleanup pass that itself hallucinates a
  // number is worse than leaving the original ASR noise for the user to
  // see and correct themselves.
  async cleanTranscript(rawText: string, language: 'en' | 'pl'): Promise<string> {
    const trimmed = rawText.trim();
    if (!trimmed) return trimmed;

    const instruction =
      language === 'pl'
        ? 'Otrzymujesz surowy tekst z rozpoznawania mowy (może zawierać błędy) — to polecenie głosowe do aplikacji kalendarza. ' +
          'Popraw WYŁĄCZNIE oczywiste błędy rozpoznawania mowy: złą odmianę słów, pomylone spójniki/przyimki, brakującą interpunkcję. ' +
          'NIE zmieniaj, nie dodawaj i nie usuwaj żadnych liczb, godzin, dat ani imion — przepisz je dokładnie tak, jak są, nawet jeśli wyglądają na niekompletne. ' +
          'Nie dodawaj żadnych nowych informacji i nie odpowiadaj na treść — wypisz wyłącznie poprawioną wersję tego samego zdania, bez cudzysłowów i bez komentarza. ' +
          'Jeśli tekst jest już poprawny, przepisz go bez zmian.'
        : 'You receive raw speech-to-text output (it may contain recognition errors) — this is a voice command for a calendar app. ' +
          'Fix ONLY obvious speech-recognition mistakes: wrong word forms, mixed-up connecting words, missing punctuation. ' +
          'Do NOT change, add, or remove any numbers, times, dates, or names — copy those exactly as given, even if they look incomplete. ' +
          'Do not add new information and do not respond to the text — output only the corrected version of the same sentence, no quotes, no commentary. ' +
          'If the text is already fine, repeat it unchanged.';

    try {
      const reply = await this.ollama.chat(
        [
          { role: 'system', content: instruction },
          { role: 'user', content: trimmed },
        ],
        [],
      );
      const cleaned = reply.content?.trim();
      if (!cleaned || !this.isSafeTranscriptCleanup(trimmed, cleaned)) return trimmed;
      return cleaned;
    } catch (error) {
      this.logger.warn(
        `Transcript cleanup failed, using raw transcript: ${error instanceof Error ? error.message : error}`,
      );
      return trimmed;
    }
  }

  private isSafeTranscriptCleanup(original: string, cleaned: string): boolean {
    const lengthRatio = cleaned.length / Math.max(original.length, 1);
    if (lengthRatio < 0.5 || lengthRatio > 1.6) return false;
    const digitsOf = (s: string) => (s.match(/\d+/g) ?? []).join(',');
    if (digitsOf(original) !== digitsOf(cleaned)) return false;
    if (this.containsUnexpectedScript(cleaned)) return false;
    if (!this.properNounsPreserved(original, cleaned)) return false;
    return true;
  }

  // Confirmed by direct testing: despite being told not to, the cleanup
  // model will sometimes "correct" a name it doesn't recognize into a
  // different, more common one (e.g. "Werą" -> "Weroniką") rather than
  // leaving it as-is — invisible to the length/digit checks above since the
  // result is still a normal-looking sentence. Every capitalized word in the
  // original (a proper noun, in practice almost always a person's name) must
  // still be present in the cleaned text, allowing only a 1-character
  // difference (diacritics restored, a dropped letter) — anything further
  // means the "fix" replaced the name rather than repairing it, and the
  // whole cleanup is discarded in favor of the raw transcript.
  private properNounsPreserved(original: string, cleaned: string): boolean {
    const names = this.extractCapitalizedWords(original);
    if (names.length === 0) return true;
    const cleanedTokens = this.extractCapitalizedWords(cleaned).map((w) => this.toAsciiLower(w));
    return names.every((name) => {
      const target = this.toAsciiLower(name);
      return cleanedTokens.some((token) => this.levenshteinDistance(target, token) <= 1);
    });
  }

  private extractCapitalizedWords(text: string): string[] {
    return (text.match(/\p{Lu}\p{L}*/gu) ?? []).filter((w) => w.length >= 3);
  }

  private toAsciiLower(word: string): string {
    return word
      .toLowerCase()
      .replace(/[ąćęłńóśźż]/g, (c) => AssistantService.DIACRITICS[c] ?? c);
  }

  private levenshteinDistance(a: string, b: string): number {
    const rows = a.length + 1;
    const cols = b.length + 1;
    const dp: number[][] = Array.from({ length: rows }, () => new Array(cols).fill(0));
    for (let i = 0; i < rows; i++) dp[i][0] = i;
    for (let j = 0; j < cols; j++) dp[0][j] = j;
    for (let i = 1; i < rows; i++) {
      for (let j = 1; j < cols; j++) {
        dp[i][j] =
          a[i - 1] === b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + Math.min(dp[i - 1][j - 1], dp[i - 1][j], dp[i][j - 1]);
      }
    }
    return dp[a.length][b.length];
  }

  async confirmDelete(userId: string, eventId: string): Promise<{ title: string }> {
    const event = await this.prisma.event.findUnique({ where: { id: eventId } });
    await this.eventsService.remove(userId, eventId);
    return { title: event?.title ?? 'Event' };
  }

  // Gets one turn out of the model, recovering from the two corruption modes
  // observed in practice (worse in non-English conversations): a tool call
  // leaked as plain text instead of going through Ollama's structured
  // channel, or the reply drifting into stray non-Latin script (Chinese/
  // Cyrillic) mid-sentence. A leaked tool call is always recoverable
  // outright; script corruption just gets regenerated a couple of times
  // before giving up, since there's nothing to parse out of it.
  private async getCleanReply(messages: OllamaMessage[]): Promise<OllamaMessage> {
    const MAX_REGENERATIONS = 2;
    let reply = await this.ollama.chat(messages, ASSISTANT_TOOLS);

    for (let attempt = 0; attempt < MAX_REGENERATIONS; attempt++) {
      if (reply.tool_calls?.length) return reply;

      const recovered = this.extractLeakedToolCall(reply.content);
      if (recovered) {
        return { ...reply, tool_calls: [{ function: recovered }], content: '' };
      }

      if (!this.containsUnexpectedScript(reply.content)) return reply;

      reply = await this.ollama.chat(messages, ASSISTANT_TOOLS);
    }

    return reply;
  }

  // CJK Unified Ideographs, Hiragana/Katakana, and Cyrillic — none belong in
  // an English or Polish reply (the app's only two languages), so their
  // presence means generation derailed partway through, not a legitimate
  // word choice. U+FFFD is the replacement character produced when bytes
  // don't decode as valid UTF-8 at all — confirmed by direct testing to
  // show up mid-word in mangled Polish diacritics (e.g. "został" coming
  // back corrupted); it can never be an intentional character either.
  private containsUnexpectedScript(text: string): boolean {
    return /[一-鿿぀-ヿЀ-ӿ�]/.test(text);
  }

  // The "✅ Created/Updated: ..." receipt format only exists so the user has
  // one line per turn they can trust regardless of what the model claims —
  // but once that format has appeared once in the conversation history, the
  // model can and does imitate it verbatim in its own free-text reply
  // (confirmed by direct testing), fabricating a receipt for a mutation
  // that never happened. Stripping any line starting with the receipt's own
  // marker from the model's own content means that marker can only ever
  // reach the user via appendReceipt, built from a real mutation.
  private stripFakeReceiptLines(text: string): string {
    return text
      .split('\n')
      .filter((line) => !line.trimStart().startsWith('✅'))
      .join('\n')
      .trim();
  }

  private buildRetryExhaustedMessage(language: 'en' | 'pl'): string {
    return language === 'pl'
      ? 'Przepraszam, mam teraz problem z wygenerowaniem czytelnej odpowiedzi. Spróbuj zapytać jeszcze raz, może innymi słowami.'
      : "Sorry, I'm having trouble forming a clean response right now — could you try asking again, maybe rephrased?";
  }

  // Appends one fact-checked line per successful create/update, built
  // directly from what was actually written to the database — the model's
  // own prose above it is still shown (it's better at natural phrasing and
  // combining multiple things in one turn), but this line is what you
  // should actually trust actually happened.
  private appendReceipt(
    reply: string,
    mutations: EventMutationReceipt[],
    language: 'en' | 'pl',
    utcOffsetMinutes: number,
  ): string {
    if (mutations.length === 0) return reply;
    const lines = mutations.map((m) => this.formatMutationReceipt(m, language, utcOffsetMinutes));
    return [reply, ...lines].filter((s) => s.trim().length > 0).join('\n');
  }

  private formatMutationReceipt(
    mutation: EventMutationReceipt,
    language: 'en' | 'pl',
    utcOffsetMinutes: number,
  ): string {
    const { kind, event } = mutation;
    const when = this.formatEventWhen(event, language, utcOffsetMinutes);
    if (language === 'pl') {
      const verb = kind === 'created' ? 'Utworzono' : 'Zaktualizowano';
      return `✅ ${verb}: „${event.title}”${when ? ` — ${when}` : ''}`;
    }
    const verb = kind === 'created' ? 'Created' : 'Updated';
    return `✅ ${verb}: "${event.title}"${when ? ` — ${when}` : ''}`;
  }

  // toLocaleDateString/toLocaleTimeString always use the server's own
  // timezone unless told otherwise — the trick used throughout this file
  // (shift the instant by the user's own offset, then read its UTC
  // components back as if they were local) sidesteps needing an IANA
  // timezone database just to display "the user's local time" correctly.
  private formatEventWhen(event: EventToolResult, language: 'en' | 'pl', utcOffsetMinutes: number): string | null {
    const locale = language === 'pl' ? 'pl-PL' : 'en-US';

    // A timed event's stored "day" is a UTC calendar-day slice, which can
    // disagree with the user's actual local day near midnight — deriving
    // both the day and time from the same shifted instant keeps them
    // consistent. A loose/backlog item's assignedDate has no time
    // component to shift, so it's used as-is.
    if (event.startTime) {
      const shifted = new Date(new Date(event.startTime).getTime() + utcOffsetMinutes * 60000);
      const day = shifted.toLocaleDateString(locale, { timeZone: 'UTC', year: 'numeric', month: 'short', day: 'numeric' });
      const time = shifted.toLocaleTimeString(locale, { timeZone: 'UTC', hour: '2-digit', minute: '2-digit' });
      return `${day}, ${time}`;
    }

    if (!event.day) return null;
    return new Date(`${event.day}T00:00:00Z`).toLocaleDateString(locale, {
      timeZone: 'UTC',
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }

  private static readonly TOOL_NAMES = ASSISTANT_TOOLS.map((t) => t.function.name).join('|');
  private static readonly LEAKED_TOOL_CALL_PATTERN = new RegExp(
    `"name"\\s*:\\s*"(${AssistantService.TOOL_NAMES})"\\s*,\\s*"arguments"\\s*:\\s*(\\{[^{}]*\\})`,
  );

  private extractLeakedToolCall(content: string): { name: string; arguments: Record<string, unknown> } | null {
    const match = content.match(AssistantService.LEAKED_TOOL_CALL_PATTERN);
    if (!match) return null;
    try {
      return { name: match[1], arguments: JSON.parse(match[2]) };
    } catch {
      return null;
    }
  }

  private parseArgs(raw: Record<string, unknown> | string): Record<string, any> {
    if (typeof raw === 'string') {
      try {
        return JSON.parse(raw);
      } catch {
        return {};
      }
    }
    return raw;
  }

  private async executeTool(
    userId: string,
    name: string,
    args: Record<string, any>,
    utcOffsetMinutes: number,
  ): Promise<unknown> {
    try {
      switch (name) {
        case 'find_events':
          return await this.findEvents(userId, args, utcOffsetMinutes);
        case 'create_event':
          return await this.createEvent(userId, args, utcOffsetMinutes);
        case 'update_event':
          return await this.updateEvent(userId, args, utcOffsetMinutes);
        default:
          return { error: `Unknown tool "${name}"` };
      }
    } catch (error) {
      this.logger.error(`Tool ${name} failed: ${error instanceof Error ? error.stack : error}`);
      return { error: error instanceof Error ? error.message : 'Something went wrong' };
    }
  }

  private async findEvents(
    userId: string,
    args: { titleContains?: string; dateFrom?: string; dateTo?: string },
    utcOffsetMinutes: number,
  ) {
    const titleFilter = args.titleContains
      ? { title: { contains: args.titleContains, mode: 'insensitive' as const } }
      : {};

    let events = await this.queryEvents(userId, titleFilter, args.dateFrom, args.dateTo);
    let dateFilterDropped = false;

    // A local LLM doing its own date arithmetic ("a month ago", "next
    // quarter") is unreliable and can easily hand back a range that's too
    // narrow or just off — rather than trust it got that right, fall back
    // to searching by title alone (or everything, if there's no title
    // either) before reporting nothing was found.
    if (events.length === 0 && (args.dateFrom || args.dateTo)) {
      events = await this.queryEvents(userId, titleFilter, undefined, undefined);
      dateFilterDropped = true;
    }

    const results = events.map((e) => ({
      id: e.id,
      title: e.title,
      day: e.assignedDate?.toISOString().slice(0, 10) ?? e.startTime?.toISOString().slice(0, 10) ?? null,
      startTime: e.startTime?.toISOString() ?? null,
      endTime: e.endTime?.toISOString() ?? null,
      startLocal: e.startTime ? this.localDateTimeString(e.startTime, utcOffsetMinutes) : null,
      endLocal: e.endTime ? this.localDateTimeString(e.endTime, utcOffsetMinutes) : null,
      location: e.location,
      isRecurring: !!e.rrule,
    }));

    return dateFilterDropped
      ? {
          note: 'No matches in that date range, so this instead searches across all dates — check the "day"/"startTime" of each result rather than assuming the range you asked for.',
          events: results,
        }
      : { events: results };
  }

  private async queryEvents(
    userId: string,
    titleFilter: Record<string, unknown>,
    dateFrom: string | undefined,
    dateTo: string | undefined,
  ) {
    const where: Record<string, unknown> = { userId, ...titleFilter };
    if (dateFrom || dateTo) {
      const from = dateFrom ? new Date(`${dateFrom}T00:00:00Z`) : new Date('1970-01-01');
      const to = dateTo ? new Date(`${dateTo}T23:59:59Z`) : new Date('2100-01-01');
      where.OR = [
        { startTime: { gte: from, lte: to } },
        { assignedDate: { gte: from, lte: to } },
      ];
    }

    // Most-recently-created first (rather than by date) so a broadened,
    // unfiltered search still surfaces plausibly-relevant recent events
    // ahead of years-old ones when there are more than fit in one page.
    return this.prisma.event.findMany({ where, orderBy: { createdAt: 'desc' }, take: 40 });
  }

  private async createEvent(
    userId: string,
    args: Record<string, any>,
    utcOffsetMinutes: number,
  ): Promise<EventToolResult> {
    if (!args.confirmNotDuplicate) {
      const existing = await this.findPossibleDuplicate(userId, args.title, utcOffsetMinutes);
      if (existing) {
        const when = this.formatEventWhen(existing, 'en', utcOffsetMinutes);
        // Thrown (not returned) so it goes through executeTool's existing
        // try/catch and comes back as a plain {error} the model already
        // knows how to act on — same contract as the isValidEventId guard
        // below. A prose instruction not to duplicate events already exists
        // in the system prompt and was not enough on its own (seen in
        // practice: a mis-transcribed voice command — "Werią" heard for
        // "Werą" — meant a title search for the existing event's real
        // spelling came back empty, and the model created a second event
        // rather than finding and updating the first). This check doesn't
        // depend on the model having searched with the right spelling at
        // all; it compares against every recent title itself.
        throw new Error(
          `A very similar event already exists: "${existing.title}" (id "${existing.id}"${when ? `, ${when}` : ', unscheduled'}). ` +
            `If this is the same event, call update_event with eventId "${existing.id}" instead of creating a new one. ` +
            `If it's genuinely a separate, different event, call create_event again with confirmNotDuplicate: true.`,
        );
      }
    }
    const schedule = this.resolveSchedule(args, utcOffsetMinutes);
    if (schedule.startTime && schedule.endTime && !args.confirmOverlap) {
      await this.rejectIfOverlapping(userId, schedule.startTime, schedule.endTime, utcOffsetMinutes);
    }
    const event = await this.eventsService.create(userId, {
      title: args.title,
      description: args.description,
      location: args.location,
      isAllDay: args.isAllDay ?? false,
      rrule: schedule.startTime ? buildRrule(args) : undefined,
      reminders: schedule.startTime ? args.reminderMinutesBefore : undefined,
      ...schedule,
    });
    return this.toEventToolResult(event, utcOffsetMinutes);
  }

  private async updateEvent(
    userId: string,
    args: Record<string, any>,
    utcOffsetMinutes: number,
  ): Promise<EventToolResult> {
    const { eventId, ...fields } = args;
    if (!this.isValidEventId(eventId)) {
      // Seen in practice: the model skips find_events and invents an id —
      // once literally a datetime string — which otherwise reaches Prisma
      // as a raw UUID lookup and throws a raw, unhelpful driver error.
      // Failing fast with a plain-English reason gives the model something
      // it can actually act on (it's already shown find_events first).
      throw new Error(`"${eventId}" is not a valid event id — call find_events first and use the id it returns.`);
    }
    const hasScheduleChange = fields.day !== undefined || fields.startTime !== undefined;
    let schedule: { assignedDate?: string; startTime?: string; endTime?: string } = {};

    if (hasScheduleChange) {
      let day = fields.day;
      if (day === undefined) {
        // The tool description tells the model to "only pass fields that
        // should change" — a time-only change (e.g. "change the hour to
        // 14") legitimately omits `day`. resolveSchedule's fallback to
        // "today" exists for create_event, where there's no prior day to
        // fall back to; reusing it here silently moved the event to today
        // instead of leaving it on its actual day. Look up the event's
        // current day ourselves so an omitted `day` means "keep it".
        const current = await this.prisma.event.findUnique({ where: { id: eventId } });
        if (current) {
          day = current.startTime
            ? this.localDayFromInstant(current.startTime, utcOffsetMinutes)
            : (current.assignedDate?.toISOString().slice(0, 10) ?? undefined);
        }
      }
      schedule = this.resolveSchedule({ ...fields, day }, utcOffsetMinutes);
    }

    if (schedule.startTime && schedule.endTime && !fields.confirmOverlap) {
      await this.rejectIfOverlapping(userId, schedule.startTime, schedule.endTime, utcOffsetMinutes, eventId);
    }

    const event = await this.eventsService.update(userId, eventId, {
      title: fields.title,
      description: fields.description,
      location: fields.location,
      isAllDay: fields.isAllDay,
      rrule: schedule.startTime ? buildRrule(fields) : undefined,
      reminders: fields.reminderMinutesBefore,
      ...schedule,
    });
    return this.toEventToolResult(event, utcOffsetMinutes);
  }

  private toEventToolResult(
    event: {
      id: string;
      title: string;
      assignedDate: Date | null;
      startTime: Date | null;
      endTime: Date | null;
    },
    utcOffsetMinutes: number,
  ): EventToolResult {
    return {
      id: event.id,
      title: event.title,
      day: event.assignedDate?.toISOString().slice(0, 10) ?? event.startTime?.toISOString().slice(0, 10) ?? null,
      startTime: event.startTime?.toISOString() ?? null,
      endTime: event.endTime?.toISOString() ?? null,
      startLocal: event.startTime ? this.localDateTimeString(event.startTime, utcOffsetMinutes) : null,
      endLocal: event.endTime ? this.localDateTimeString(event.endTime, utcOffsetMinutes) : null,
    };
  }

  // Same shift-then-read-UTC-components trick as localDayFromInstant, kept
  // as "YYYY-MM-DD HH:mm" — deliberately not reusing formatEventWhen's
  // locale-formatted "Aug 1, 2026, 10:00 AM" output here, since that's meant
  // for the human-facing receipt line, while this is meant for the model to
  // read back unambiguously (and, per resolveSchedule/localToUtcIso, feed
  // the HH:mm half of straight back into its own next tool call untouched).
  private localDateTimeString(instant: Date, utcOffsetMinutes: number): string {
    const iso = new Date(instant.getTime() + utcOffsetMinutes * 60000).toISOString();
    return `${iso.slice(0, 10)} ${iso.slice(11, 16)}`;
  }

  /// Turns the tool's flat day/startTime/endTime (local wall-clock) into
  /// either a timed event (startTime/endTime), a loose day-only item
  /// (assignedDate), or nothing at all (a bare backlog idea, when neither
  /// is given — only relevant for create, since update leaves whatever it
  /// doesn't mention unchanged).
  private resolveSchedule(
    args: { day?: string; startTime?: string; endTime?: string },
    utcOffsetMinutes: number,
  ): { assignedDate?: string; startTime?: string; endTime?: string } {
    if (!args.day && !args.startTime) return {};
    if (!args.startTime) return { assignedDate: args.day };

    const day = args.day ?? this.todayLocalDate(utcOffsetMinutes);
    const startTime = this.localToUtcIso(day, args.startTime, utcOffsetMinutes);
    const endTime = args.endTime
      ? this.localToUtcIso(day, args.endTime, utcOffsetMinutes)
      : new Date(new Date(startTime).getTime() + 60 * 60 * 1000).toISOString();
    return { startTime, endTime };
  }

  private localToUtcIso(day: string, time: string, utcOffsetMinutes: number): string {
    // The schema asks for a plain "HH:mm", but the model sometimes echoes a
    // full ISO-looking value instead (e.g. copying the shape of a
    // find_events result) — pulling the HH:mm out of wherever it lands in
    // the string handles that without failing the whole update over a
    // formatting slip the day/eventId fields already got right.
    const match = time.match(/(\d{1,2}):(\d{2})/);
    if (!match) throw new Error(`"${time}" is not a valid HH:mm time`);
    const hour = Number(match[1]);
    const minute = Number(match[2]);
    const [year, month, date] = day.split('-').map(Number);
    const utcMillis = Date.UTC(year, month - 1, date, hour, minute) - utcOffsetMinutes * 60000;
    return new Date(utcMillis).toISOString();
  }

  private todayLocalDate(utcOffsetMinutes: number): string {
    const localNow = new Date(Date.now() + utcOffsetMinutes * 60000);
    return localNow.toISOString().slice(0, 10);
  }

  // Same shift-then-read-UTC-components trick as formatEventWhen — avoids
  // needing an IANA timezone database just to recover which local day a
  // stored UTC instant falls on.
  private localDayFromInstant(instant: Date, utcOffsetMinutes: number): string {
    return new Date(instant.getTime() + utcOffsetMinutes * 60000).toISOString().slice(0, 10);
  }

  // Polish prepositions/conjunctions plus a handful of English equivalents —
  // words too common to mean anything when comparing titles for similarity.
  private static readonly TITLE_STOPWORDS = new Set([
    'z', 'i', 'w', 'o', 'u', 'do', 'od', 'na', 'za', 'się', 'ze', 'the', 'a', 'an', 'and', 'with', 'to', 'on', 'at', 'of', 'for', 'in',
  ]);

  private static readonly DIACRITICS: Record<string, string> = {
    ą: 'a', ć: 'c', ę: 'e', ł: 'l', ń: 'n', ó: 'o', ś: 's', ź: 'z', ż: 'z',
  };

  // Diacritic-stripped, stopword-filtered significant words — deliberately
  // loose (not exact-match) since the whole point is catching titles that
  // differ by exactly the kind of single-letter voice-transcription slip
  // that defeats an exact substring search (see createEvent above).
  private normalizeTitleWords(title: string): string[] {
    const ascii = title
      .toLowerCase()
      .replace(/[ąćęłńóśźż]/g, (c) => AssistantService.DIACRITICS[c] ?? c)
      .replace(/[^a-z0-9\s]/g, ' ');
    return ascii.split(/\s+/).filter((w) => w.length >= 3 && !AssistantService.TITLE_STOPWORDS.has(w));
  }

  // Finds the user's own most-recent-title best match by significant-word
  // overlap, if any is a close enough call to be worth flagging before
  // create_event silently adds a duplicate. Titles too short/generic to
  // compare meaningfully (fewer than 2 significant words) are skipped
  // entirely rather than risk a false positive blocking a legitimate create.
  private async findPossibleDuplicate(
    userId: string,
    title: string | undefined,
    utcOffsetMinutes: number,
  ): Promise<EventToolResult | null> {
    if (!title) return null;
    const words = this.normalizeTitleWords(title);
    if (words.length < 2) return null;

    const candidates = await this.prisma.event.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    let best: { event: (typeof candidates)[number]; overlap: number } | null = null;
    for (const candidate of candidates) {
      const candidateWords = this.normalizeTitleWords(candidate.title);
      if (candidateWords.length === 0) continue;
      const shared = words.filter((w) => candidateWords.includes(w)).length;
      const overlap = shared / Math.min(words.length, candidateWords.length);
      if (shared >= 2 && overlap >= 0.6 && (!best || overlap > best.overlap)) {
        best = { event: candidate, overlap };
      }
    }
    return best ? this.toEventToolResult(best.event, utcOffsetMinutes) : null;
  }

  // Blocks a silent double-booking the same way findPossibleDuplicate blocks
  // a silent duplicate — a prose-only "watch out for conflicts" instruction
  // is easy for a local model to just not act on, especially mid-voice-
  // command where it's already juggling a garbled transcript. Scoped to a
  // literal time-range overlap against each event's own stored start/end;
  // it deliberately does not expand recurring events into their individual
  // occurrences (that logic only exists client-side today), so a conflict
  // against one specific occurrence of a recurring series can still slip
  // through. All-day/loose items (no startTime) never conflict with
  // anything — they don't occupy a specific time slot to begin with.
  private async rejectIfOverlapping(
    userId: string,
    startTimeIso: string,
    endTimeIso: string,
    utcOffsetMinutes: number,
    excludeEventId?: string,
  ): Promise<void> {
    const conflict = await this.prisma.event.findFirst({
      where: {
        userId,
        id: excludeEventId ? { not: excludeEventId } : undefined,
        startTime: { not: null, lt: new Date(endTimeIso) },
        endTime: { not: null, gt: new Date(startTimeIso) },
      },
      orderBy: { startTime: 'asc' },
    });
    if (!conflict) return;

    const when = this.formatEventWhen(this.toEventToolResult(conflict, utcOffsetMinutes), 'en', utcOffsetMinutes);
    throw new Error(
      `That time overlaps with an existing event: "${conflict.title}" (id "${conflict.id}"${when ? `, ${when}` : ''}). ` +
        `Tell the user about the conflict and ask whether to schedule it anyway, pick a different time, or cancel — ` +
        `only call this again with confirmOverlap: true once the user has said they want the overlap.`,
    );
  }

  private static readonly UUID_PATTERN =
    /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

  private isValidEventId(id: unknown): id is string {
    return typeof id === 'string' && AssistantService.UUID_PATTERN.test(id);
  }

  private async resolvePendingDelete(
    userId: string,
    args: { eventId?: string },
  ): Promise<AssistantPendingDelete | { error: string }> {
    // Not just a truthiness check — resolvePendingDelete is called directly
    // from chat(), not through executeTool's try/catch, so a non-UUID value
    // reaching Prisma's findUnique would otherwise throw uncaught and fail
    // the whole request instead of giving the model a recoverable error.
    if (!this.isValidEventId(args.eventId)) {
      return { error: `"${args.eventId}" is not a valid event id — call find_events first and use the id it returns.` };
    }
    const event = await this.prisma.event.findUnique({ where: { id: args.eventId } });
    if (!event || event.userId !== userId) {
      return { error: `No event with id "${args.eventId}" found — call find_events again to get the right id` };
    }
    return {
      eventId: event.id,
      title: event.title,
      when: event.startTime?.toISOString() ?? event.assignedDate?.toISOString().slice(0, 10) ?? 'unscheduled',
    };
  }

  private buildSystemPrompt(clientNowLocal: string, language: 'en' | 'pl'): string {
    const now = new Date(clientNowLocal);
    const weekday = Number.isNaN(now.getTime())
      ? ''
      : now.toLocaleDateString('en-US', { weekday: 'long' });
    const languageName = language === 'pl' ? 'Polish' : 'English';

    return [
      `You are a calendar assistant embedded in a personal calendar app.`,
      `The current date and time is ${clientNowLocal}${weekday ? ` (a ${weekday})` : ''}, in the user's own local time. Use this to resolve relative dates like "tomorrow" or "next Thursday".`,
      `Dates are YYYY-MM-DD and times are 24-hour HH:mm, both in the user's local time — never UTC.`,
      `Always call find_events first to get an event's real id before calling update_event or delete_event — never guess or invent an id.`,
      `If the user asks to delete every event matching something (e.g. "remove every event about bowling"), call delete_event once per matching event returned by find_events, not just the first one. Never ask the user to confirm a deletion in your own text — call delete_event directly and let the app's own confirmation dialog handle that; asking first yourself just means they get asked twice.`,
      `When the user asks about an event, search for it immediately with your best-guess titleContains and/or date range rather than asking them clarifying questions first — a search costs nothing, and you can always search again with different terms. Only ask the user a question if find_events has already come back empty after you've tried a couple of variations.`,
      `Your own date-range arithmetic for vague phrases like "a month ago" or "sometime last spring" is often imprecise, so when searching for something the user only vaguely dated, prefer a wide dateFrom/dateTo (or omit them and rely on titleContains) rather than a single exact day — it's better to get some extra results than to miss the real one. If find_events comes back empty, don't immediately conclude nothing exists: try again with a wider range, a looser or dropped titleContains, or both, before telling the user you couldn't find it.`,
      `When you write an event's title, reuse the exact words the user themselves used wherever reasonable (e.g. their own "trening koszykówki" becomes the title "Trening koszykówki") instead of composing new phrasing yourself — copying text you were already given is far less likely to introduce a spelling mistake than generating it fresh, especially in Polish. Only compose new title wording when the user didn't describe the event in a way you can reuse directly.`,
      `startTime and endTime are always exactly "HH:mm" (e.g. "14:00"), never a full date, when you're the one calling a tool. Every event a tool gives back to you also includes startLocal/endLocal ("YYYY-MM-DD HH:mm", already in the user's local time) — always read and speak from those, and copy the HH:mm part of startLocal/endLocal (never of the plain startTime/endTime fields, which are raw UTC and will look like a different, earlier time) into your own next call.`,
      `A tool result with no "error" field means that call already succeeded — trust it and move on. Do not call update_event again for a change you already made, and do not call find_events again just to double-check a change that just succeeded; repeating successful calls doesn't make them "more" done and just wastes turns.`,
      `Never call create_event to fix, replace, or redo something that already exists — that just leaves a duplicate behind. If find_events already returned the event, always change it in place with update_event on its real id, no matter how many attempts it takes.`,
      `create_event itself will refuse and return an error if its title looks like a near-duplicate of an existing event, naming that event's real id — when that happens, call update_event on the id it gives you instead of retrying create_event, unless you're confident it really is a separate event, in which case call create_event again with confirmNotDuplicate: true.`,
      `create_event and update_event will also refuse and return an error if the time given overlaps an existing timed event, naming the conflicting event. Do not just retry with confirmOverlap: true on your own — tell the user about the conflict (which event it clashes with, and when) and ask whether to double-book anyway, pick a different time, or cancel, then act on what they say. Only ever mention a scheduling conflict if a create_event or update_event call in this same turn actually came back with that error — if the call succeeded (no "error" field), there is no conflict, full stop, even if the JSON result shows UTC timestamps that look different from the local time you were given; never invent, guess at, or infer a conflict yourself from comparing times in your head.`,
      `Voice input is transcribed by speech recognition and can misspell names or drop a word — if a search for an event by the exact words the user said comes back empty, try again with just the most distinctive word (e.g. a name) rather than the full phrase, since minor transcription errors are more likely in short connecting words than in a name spoken clearly.`,
      `After using tools, reply with a short, plain confirmation of what happened. Do not mention tools, ids, or JSON — speak naturally.`,
      `The app's UI language right now is ${languageName}. Always reply in ${languageName}, and only ${languageName} — never mix in words or characters from any other language, even a single one, regardless of what language the user's own message used.`,
    ].join(' ');
  }
}
