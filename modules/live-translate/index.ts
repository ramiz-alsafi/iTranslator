import { NativeModule, requireNativeModule } from 'expo';

export type TranscriptEvent = { text: string };
export type TranslatedEvent = { original: string; translated: string };
export type ErrorEvent = { message: string };

export type LiveTranslateEvents = {
  onPartialTranscript: (event: TranscriptEvent) => void;
  onFinalTranscript: (event: TranscriptEvent) => void;
  onTranslated: (event: TranslatedEvent) => void;
  onError: (event: ErrorEvent) => void;
};

declare class LiveTranslateModule extends NativeModule<LiveTranslateEvents> {
  /** Requests Speech Recognition + Microphone permission. Resolves false if either is denied. */
  requestPermissions(): Promise<boolean>;
  /**
   * Starts continuous on-device transcription + translation.
   * @param sourceLocale BCP-47 locale of the spoken language, e.g. "en-US"
   * @param targetLocale BCP-47 locale to translate into, e.g. "es-ES"
   */
  startListening(sourceLocale: string, targetLocale: string): Promise<void>;
  stopListening(): Promise<void>;
}

export default requireNativeModule<LiveTranslateModule>('LiveTranslate');
