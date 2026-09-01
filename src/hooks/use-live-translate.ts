import { useCallback, useEffect, useState } from 'react';

import LiveTranslate, { type LanguagePackStatus } from '../../modules/live-translate';

export type TranslationEntry = {
  id: string;
  original: string;
  translated: string;
};

export function useLiveTranslate(sourceLocale: string, targetLocale: string) {
  const [isListening, setIsListening] = useState(false);
  const [isStarting, setIsStarting] = useState(false);
  const [partialTranscript, setPartialTranscript] = useState('');
  const [history, setHistory] = useState<TranslationEntry[]>([]);
  const [error, setError] = useState<string | null>(null);

  const [languageStatus, setLanguageStatus] = useState<LanguagePackStatus | 'checking'>('checking');
  const [isDownloading, setIsDownloading] = useState(false);

  useEffect(() => {
    const subscriptions = [
      LiveTranslate.addListener('onPartialTranscript', ({ text }) => {
        setPartialTranscript(text);
      }),
      LiveTranslate.addListener('onFinalTranscript', ({ text }) => {
        setPartialTranscript('');
        void text;
      }),
      LiveTranslate.addListener('onTranslated', ({ original, translated }) => {
        setHistory((prev) => [{ id: `${Date.now()}`, original, translated }, ...prev]);
      }),
      LiveTranslate.addListener('onError', ({ message }) => {
        setError(message);
      }),
    ];

    return () => {
      subscriptions.forEach((sub) => sub.remove());
    };
  }, []);

  // Re-check language pack availability whenever the pair changes.
  useEffect(() => {
    let cancelled = false;
    setLanguageStatus('checking');
    LiveTranslate.checkLanguageAvailability(sourceLocale, targetLocale)
      .then((status) => {
        if (!cancelled) setLanguageStatus(status);
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof Error ? err.message : String(err));
      });
    return () => {
      cancelled = true;
    };
  }, [sourceLocale, targetLocale]);

  // Restart the recognizer whenever the language pair changes while listening.
  useEffect(() => {
    if (!isListening) return;
    LiveTranslate.stopListening()
      .then(() => LiveTranslate.startListening(sourceLocale, targetLocale))
      .catch((err) => setError(err instanceof Error ? err.message : String(err)));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sourceLocale, targetLocale]);

  const downloadLanguagePack = useCallback(async () => {
    setError(null);
    setIsDownloading(true);
    try {
      await LiveTranslate.prepareLanguageDownload(sourceLocale, targetLocale);
      const status = await LiveTranslate.checkLanguageAvailability(sourceLocale, targetLocale);
      setLanguageStatus(status);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setIsDownloading(false);
    }
  }, [sourceLocale, targetLocale]);

  const start = useCallback(async () => {
    setError(null);
    setIsStarting(true);
    try {
      const granted = await LiveTranslate.requestPermissions();
      if (!granted) {
        setError('Microphone or speech recognition permission was denied.');
        return;
      }
      await LiveTranslate.startListening(sourceLocale, targetLocale);
      setIsListening(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setIsStarting(false);
    }
  }, [sourceLocale, targetLocale]);

  const stop = useCallback(async () => {
    await LiveTranslate.stopListening();
    setIsListening(false);
    setPartialTranscript('');
  }, []);

  const toggle = useCallback(() => {
    if (isListening) {
      stop();
    } else {
      start();
    }
  }, [isListening, start, stop]);

  useEffect(() => {
    return () => {
      if (isListening) {
        LiveTranslate.stopListening();
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return {
    isListening,
    isStarting,
    partialTranscript,
    history,
    error,
    toggle,
    languageStatus,
    isDownloading,
    downloadLanguagePack,
  };
}