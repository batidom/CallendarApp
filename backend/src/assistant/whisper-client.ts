import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/// Thin wrapper around whisper.cpp's local server (see whisper/ at the repo
/// root for setup) — same pattern as OllamaClient. Speech-to-text is a much
/// more constrained task than the LLM's text generation (transcribing what
/// was said, not composing new text), so it doesn't share the LLM's
/// Polish-reliability problems — verified directly against this exact
/// server before wiring it in.
@Injectable()
export class WhisperClient {
  constructor(private readonly config: ConfigService) {}

  private get baseUrl() {
    return this.config.get<string>('WHISPER_URL', 'http://127.0.0.1:8081');
  }

  async transcribe(
    audio: Buffer,
    filename: string,
    language: string,
  ): Promise<string> {
    const form = new FormData();
    form.append('file', new Blob([new Uint8Array(audio)]), filename);
    form.append('response_format', 'json');
    form.append('language', language);

    const response = await fetch(`${this.baseUrl}/inference`, {
      method: 'POST',
      body: form,
    });

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error(`Whisper request failed (${response.status}): ${body}`);
    }

    const data = (await response.json()) as { text: string };
    return data.text.trim();
  }
}
