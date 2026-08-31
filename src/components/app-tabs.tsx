import { Image } from 'expo-image';
import { Tabs, TabList, TabTrigger, TabSlot, TabTriggerSlotProps } from 'expo-router/ui';
import { Platform, Pressable, StyleSheet, useColorScheme, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BottomTabInset, Colors, Spacing } from '@/constants/theme';

export default function AppTabs() {
  return (
    <Tabs>
      <TabSlot />
      <TabList asChild>
        <BottomTabBar>
          <TabTrigger name="index" href="/" asChild>
            <TabButton icon={require('@/assets/images/tabIcons/home.png')} label="Home" />
          </TabTrigger>
          <TabTrigger name="explore" href="/explore" asChild>
            <TabButton icon={require('@/assets/images/tabIcons/explore.png')} label="Explore" />
          </TabTrigger>
        </BottomTabBar>
      </TabList>
    </Tabs>
  );
}

function BottomTabBar({ children }: { children: React.ReactNode }) {
  const scheme = useColorScheme();
  const colors = Colors[scheme === 'dark' ? 'dark' : 'light'];
  const insets = useSafeAreaInsets();

  return (
    <View
      style={[
        styles.bar,
        {
          backgroundColor: colors.background,
          borderTopColor: colors.backgroundElement,
          paddingBottom: Math.max(insets.bottom, Spacing.two),
          height: BottomTabInset + Spacing.four,
        },
      ]}>
      {children}
    </View>
  );
}

function TabButton({
  icon,
  label,
  isFocused,
  ...props
}: TabTriggerSlotProps & { icon: number; label: string }) {
  const scheme = useColorScheme();
  const colors = Colors[scheme === 'dark' ? 'dark' : 'light'];

  return (
    <Pressable {...props} style={styles.tabButton}>
      <Image
        source={icon}
        style={{
          width: 24,
          height: 24,
          tintColor: isFocused ? colors.text : colors.textSecondary,
        }}
      />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  bar: {
    flexDirection: 'row',
    justifyContent: 'space-evenly',
    alignItems: 'center',
    borderTopWidth: Platform.select({ ios: StyleSheet.hairlineWidth, android: 1 }),
    paddingTop: Spacing.two,
  },
  tabButton: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});