import { NativeModule, requireNativeModule } from 'expo';
import { Platform } from 'react-native';

export type TranscriptEvent = { text: string };
export type TranslatedEvent = { original: string; translated: string };
export type ErrorEvent = { message: string };
export type LanguagePackStatus = 'installed' | 'supported' | 'unsupported';

export type LiveTranslateEvents = {
  onPartialTranscript: (event: TranscriptEvent) => void;
  onFinalTranscript: (event: TranscriptEvent) => void;
  onTranslated: (event: TranslatedEvent) => void;
  onError: (event: ErrorEvent) => void;
};

declare class LiveTranslateModule extends NativeModule<LiveTranslateEvents> {
  /** Requests Speech Recognition + Microphone permission. Resolves false if either is denied. */
  requestPermissions(): Promise<boolean>;
  /** Checks whether the on-device language pack for this pair is installed/downloadable. */
  checkLanguageAvailability(sourceLocale: string, targetLocale: string): Promise<LanguagePackStatus>;
  /**
   * Presents Apple's system sheet asking permission to download the language pack.
   * Resolves once the user responds — re-check `checkLanguageAvailability` afterward, since
   * the actual download continues in the background.
   */
  prepareLanguageDownload(sourceLocale: string, targetLocale: string): Promise<void>;
  /**
   * Starts continuous on-device transcription + translation.
   * @param sourceLocale BCP-47 locale of the spoken language, e.g. "en-US"
   * @param targetLocale BCP-47 locale to translate into, e.g. "es-ES"
   */
  startListening(sourceLocale: string, targetLocale: string): Promise<void>;
  stopListening(): Promise<void>;
}

// This module only exists on iOS (see expo-module.config.json). requireNativeModule()
// throws immediately if the native side isn't linked, so on Android/web we fall back to a
// stub with the same shape that just reports "unsupported" rather than crashing the bundle.
function createUnsupportedStub(): LiveTranslateModule {
  const message = `LiveTranslate is iOS-only (got Platform.OS === "${Platform.OS}")`;
  return {
    requestPermissions: async () => false,
    checkLanguageAvailability: async () => 'unsupported',
    prepareLanguageDownload: async () => {
      throw new Error(message);
    },
    startListening: async () => {
      throw new Error(message);
    },
    stopListening: async () => {},
    addListener: () => ({ remove: () => {} }),
    removeAllListeners: () => {},
  } as unknown as LiveTranslateModule;
}

export default Platform.OS === 'ios'
  ? requireNativeModule<LiveTranslateModule>('LiveTranslate')
  : createUnsupportedStub();

// --- Floating (Picture-in-Picture) captions ---
// Uses AVPictureInPictureController + AVSampleBufferDisplayLayer to render live captions in a
// real system-wide floating window. See ios/PipCaptionRenderer.swift for the "why" and caveats.

declare class PipCaptionNativeModule extends NativeModule {
  isSupported(): boolean;
  isActive(): boolean;
  /** Push new caption text into the floating window. Cheap to call on every partial update. */
  updateCaption(original: string, translated: string): void;
  start(): Promise<void>;
  stop(): Promise<void>;
}

function createPipUnsupportedStub(): PipCaptionNativeModule {
  return {
    isSupported: () => false,
    isActive: () => false,
    updateCaption: () => {},
    start: async () => {},
    stop: async () => {},
  } as unknown as PipCaptionNativeModule;
}

export const PipCaption =
  Platform.OS === 'ios'
    ? requireNativeModule<PipCaptionNativeModule>('PipCaption')
    : createPipUnsupportedStub();