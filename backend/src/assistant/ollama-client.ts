import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface OllamaToolCall {
  function: { name: string; arguments: Record<string, unknown> | string };
}

export interface OllamaMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  tool_calls?: OllamaToolCall[];
}

/// Thin wrapper around Ollama's /api/chat, using Node's built-in fetch (no
/// extra dependency needed). Tool-calling uses the same JSON-schema function
/// format as OpenAI's, supported by tool-capable models (llama3.1, qwen2.5,
/// etc.) — see assistant-tools.ts.
@Injectable()
export class OllamaClient {
  constructor(private readonly config: ConfigService) {}

  private get baseUrl() {
    return this.config.get<string>('OLLAMA_URL', 'http://localhost:11434');
  }

  private get model() {
    return this.config.get<string>('OLLAMA_MODEL', 'qwen2.5:14b');
  }

  async chat(
    messages: OllamaMessage[],
    tools: readonly unknown[],
  ): Promise<OllamaMessage> {
    // Seen in practice: an occasional bare "fetch failed" (a connection
    // reset/refused at the TCP level, not an HTTP error response) when
    // Ollama is briefly busy loading or swapping a model. That used to
    // propagate straight up and fail the user's whole message with no
    // recovery. It's transient by nature, so one short-delay retry before
    // giving up is enough to ride out the blip instead of surfacing it as a
    // hard failure.
    try {
      return await this.doChat(messages, tools);
    } catch (error) {
      if (!(error instanceof TypeError)) throw error;
      await new Promise((resolve) => setTimeout(resolve, 500));
      return this.doChat(messages, tools);
    }
  }

  private async doChat(
    messages: OllamaMessage[],
    tools: readonly unknown[],
  ): Promise<OllamaMessage> {
    const response = await fetch(`${this.baseUrl}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: this.model,
        messages,
        tools,
        stream: false,
        // Lower than Ollama's default (~0.8) — this model occasionally
        // wanders into stray low-probability tokens (e.g. leaking Chinese
        // characters into an English/Polish reply, garbling a tool call as
        // text, or substituting a single wrong letter mid-word in
        // generated Polish, like "koszyłówki" for "koszykówki"). Sticking
        // closer to its most-likely tokens reduces all of these, though it
        // can't eliminate cases where the model's own top-ranked token is
        // simply the wrong one — that's a knowledge gap, not sampling
        // noise, and temperature has no effect on it.
        options: { temperature: 0.2 },
      }),
    });

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error(`Ollama request failed (${response.status}): ${body}`);
    }

    const data = (await response.json()) as { message: OllamaMessage };
    return data.message;
  }
}
