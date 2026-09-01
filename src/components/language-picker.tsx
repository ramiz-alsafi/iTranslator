import { SymbolView } from 'expo-symbols';
import { Pressable, StyleSheet } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { labelFor } from '@/constants/languages';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';

type Props = {
  sourceLocale: string;
  targetLocale: string;
  onPressSource: () => void;
  onPressTarget: () => void;
  onSwap: () => void;
  disabled?: boolean;
};

export function LanguagePicker({
  sourceLocale,
  targetLocale,
  onPressSource,
  onPressTarget,
  onSwap,
  disabled,
}: Props) {
  const theme = useTheme();

  return (
    <ThemedView style={styles.row}>
      <LanguageChip label={labelFor(sourceLocale)} onPress={onPressSource} disabled={disabled} />

      <Pressable onPress={onSwap} disabled={disabled} hitSlop={12} style={styles.swapButton}>
        <SymbolView
          tintColor={theme.textSecondary}
          name={{ ios: 'arrow.left.arrow.right', android: 'swap-horiz', web: 'arrow-left-right' }}
          size={18}
        />
      </Pressable>

      <LanguageChip label={labelFor(targetLocale)} onPress={onPressTarget} disabled={disabled} />
    </ThemedView>
  );
}

function LanguageChip({
  label,
  onPress,
  disabled,
}: {
  label: string;
  onPress: () => void;
  disabled?: boolean;
}) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      style={({ pressed }) => [styles.chipWrapper, pressed && styles.pressed]}>
      <ThemedView type="backgroundElement" style={styles.chip}>
        <ThemedText type="smallBold" numberOfLines={1}>
          {label}
        </ThemedText>
      </ThemedView>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.two,
  },
  chipWrapper: {
    flex: 1,
    maxWidth: 160,
  },
  chip: {
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
    borderRadius: Spacing.five,
    alignItems: 'center',
  },
  swapButton: {
    padding: Spacing.two,
  },
  pressed: {
    opacity: 0.7,
  },
});
