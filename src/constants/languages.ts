export type Language = {
  /** BCP-47 locale identifier, e.g. "en-US" — matches what SFSpeechRecognizer / Translation expect. */
  locale: string;
  label: string;
};

export const LANGUAGES: Language[] = [
  { locale: 'en-US', label: 'English' },
  { locale: 'es-ES', label: 'Spanish' },
  { locale: 'fr-FR', label: 'French' },
  { locale: 'de-DE', label: 'German' },
  { locale: 'it-IT', label: 'Italian' },
  { locale: 'pt-BR', label: 'Portuguese' },
  { locale: 'ja-JP', label: 'Japanese' },
  { locale: 'zh-CN', label: 'Chinese (Simplified)' },
  { locale: 'ar-SA', label: 'Arabic' },
];

export function nextLanguage(current: string): Language {
  const index = LANGUAGES.findIndex((lang) => lang.locale === current);
  return LANGUAGES[(index + 1) % LANGUAGES.length];
}

export function labelFor(locale: string): string {
  return LANGUAGES.find((lang) => lang.locale === locale)?.label ?? locale;
}
