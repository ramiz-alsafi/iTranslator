import { Audio } from 'expo-av';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

export default function HomeScreen() {
  const [recording, setRecording] = useState<Audio.Recording | null>(null);
  const [status, setStatus] = useState('Idle');

  async function startRecording() {
    try {
      const { granted } = await Audio.requestPermissionsAsync();
      if (!granted) {
        setStatus('Mic permission denied');
        return;
      }

      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });

      const { recording: newRecording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );
      setRecording(newRecording);
      setStatus('Recording...');
    } catch (err) {
      setStatus(`Error: ${err}`);
    }
  }

  async function stopRecording() {
    if (!recording) return;
    await recording.stopAndUnloadAsync();
    const uri = recording.getURI();
    setRecording(null);
    setStatus(`Saved: ${uri}`);
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>iTranslator</Text>
      <Text style={styles.status}>{status}</Text>

      <Pressable
        style={[styles.button, recording && styles.buttonRecording]}
        onPress={recording ? stopRecording : startRecording}>
        <Text style={styles.buttonText}>
          {recording ? 'Stop Recording' : 'Start Recording'}
        </Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#000', padding: 20 },
  title: { fontSize: 32, fontWeight: 'bold', color: '#fff', marginBottom: 20 },
  status: { fontSize: 14, color: '#888', marginBottom: 40, textAlign: 'center' },
  button: { backgroundColor: '#208AEF', paddingVertical: 16, paddingHorizontal: 32, borderRadius: 12 },
  buttonRecording: { backgroundColor: '#E53E3E' },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
});