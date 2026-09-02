import { SymbolView } from 'expo-symbols';
import { useState } from 'react';
import { ActivityIndicator, FlatList, Platform, Pressable, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { LanguagePicker } from '@/components/language-picker';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { nextLanguage } from '@/constants/languages';
import { BottomTabInset, MaxContentWidth, Spacing } from '@/constants/theme';
import { useLiveTranslate, type TranslationEntry } from '@/hooks/use-live-translate';
import { useTheme } from '@/hooks/use-theme';

const RECORDING_COLOR = '#FF3B30';

export default function HomeScreen() {
  const [sourceLocale, setSourceLocale] = useState('en-US');
  const [targetLocale, setTargetLocale] = useState('es-ES');
  const theme = useTheme();

  const {
    isListening,
    isStarting,
    partialTranscript,
    history,
    error,
    toggle,
    languageStatus,
    isDownloading,
    downloadLanguagePack,
  } = useLiveTranslate(sourceLocale, targetLocale);

  const unsupported = Platform.OS !== 'ios';
  const needsDownload = languageStatus === 'supported';
  const packUnsupported = languageStatus === 'unsupported';
  const micDisabled =
    unsupported || isStarting || needsDownload || packUnsupported || languageStatus === 'checking';

  return (
    <ThemedView style={styles.root}>
      <SafeAreaView style={styles.safeArea}>
        <LanguagePicker
          sourceLocale={sourceLocale}
          targetLocale={targetLocale}
          onPressSource={() => setSourceLocale((cur) => nextLanguage(cur).locale)}
          onPressTarget={() => setTargetLocale((cur) => nextLanguage(cur).locale)}
          onSwap={() => {
            setSourceLocale(targetLocale);
            setTargetLocale(sourceLocale);
          }}
          disabled={isListening}
        />

        {unsupported ? (
          <ThemedView style={styles.centerFill}>
            <ThemedText themeColor="textSecondary" style={styles.centerText}>
              Live translation uses on-device Speech and Translation frameworks, which are
              iOS-only.
            </ThemedText>
          </ThemedView>
        ) : (
          <>
            {needsDownload && (
              <Pressable
                onPress={downloadLanguagePack}
                disabled={isDownloading}
                style={({ pressed }) => pressed && styles.pressed}>
                <ThemedView type="backgroundElement" style={styles.downloadBanner}>
                  {isDownloading ? (
                    <ActivityIndicator color={theme.text} />
                  ) : (
                    <SymbolView
                      tintColor={theme.text}
                      name={{ ios: 'arrow.down.circle', android: 'download', web: 'download' }}
                      size={18}
                    />
                  )}
                  <ThemedText type="smallBold">
                    {isDownloading ? 'Downloading language pack…' : 'Download language pack to translate'}
                  </ThemedText>
                </ThemedView>
              </Pressable>
            )}

            {packUnsupported && (
              <ThemedText themeColor="textSecondary" style={styles.centerText}>
                This language pair isn&apos;t supported for on-device translation yet.
              </ThemedText>
            )}

            <FlatList
              style={styles.list}
              contentContainerStyle={styles.listContent}
              data={history}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => <TranscriptCard entry={item} />}
              ListHeaderComponent={
                partialTranscript ? (
                  <ThemedText themeColor="textSecondary" style={styles.partial}>
                    {partialTranscript}
                  </ThemedText>
                ) : null
              }
              ListEmptyComponent={
                !partialTranscript ? (
                  <ThemedView style={styles.centerFill}>
                    <ThemedText themeColor="textSecondary" style={styles.centerText}>
                      Tap the mic and start speaking — captions and translations show up here.
                    </ThemedText>
                  </ThemedView>
                ) : null
              }
            />
          </>
        )}

        {error && (
          <ThemedText themeColor="textSecondary" style={styles.error} numberOfLines={2}>
            {error}
          </ThemedText>
        )}

        <Pressable
          onPress={toggle}
          disabled={micDisabled}
          style={({ pressed }) => [
            styles.micButton,
            { backgroundColor: isListening ? RECORDING_COLOR : theme.backgroundElement },
            micDisabled && styles.micDisabled,
            pressed && styles.pressed,
          ]}>
          <SymbolView
            tintColor={isListening ? '#ffffff' : theme.text}
            name={{
              ios: isListening ? 'mic.fill' : 'mic',
              android: isListening ? 'mic' : 'mic-none',
              web: 'mic',
            }}
            size={28}
          />
        </Pressable>
      </SafeAreaView>
    </ThemedView>
  );
}

function TranscriptCard({ entry }: { entry: TranslationEntry }) {
  return (
    <ThemedView type="backgroundElement" style={styles.card}>
      <ThemedText themeColor="textSecondary" type="small">
        {entry.original}
      </ThemedText>
      <ThemedText type="default">{entry.translated}</ThemedText>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    alignItems: 'center',
  },
  safeArea: {
    flex: 1,
    width: '100%',
    maxWidth: MaxContentWidth,
    paddingHorizontal: Spacing.four,
    paddingTop: Spacing.three,
    paddingBottom: BottomTabInset + Spacing.three,
    gap: Spacing.three,
  },
  list: {
    flex: 1,
  },
  listContent: {
    gap: Spacing.two,
    flexGrow: 1,
  },
  centerFill: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: Spacing.four,
  },
  centerText: {
    textAlign: 'center',
  },
  partial: {
    fontStyle: 'italic',
    marginBottom: Spacing.two,
  },
  card: {
    borderRadius: Spacing.three,
    padding: Spacing.three,
    gap: Spacing.one,
  },
  downloadBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.two,
    borderRadius: Spacing.three,
    paddingVertical: Spacing.two,
    paddingHorizontal: Spacing.three,
  },
  error: {
    textAlign: 'center',
  },
  micButton: {
    alignSelf: 'center',
    width: 72,
    height: 72,
    borderRadius: 36,
    alignItems: 'center',
    justifyContent: 'center',
  },
  micDisabled: {
    opacity: 0.4,
  },
  pressed: {
    opacity: 0.85,
  },
});