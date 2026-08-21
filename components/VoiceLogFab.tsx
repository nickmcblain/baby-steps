import { useAction } from "convex/react";
import * as Device from "expo-device";
import * as Haptics from "expo-haptics";
import {
  AudioModule,
  RecordingPresets,
  setAudioModeAsync,
  useAudioRecorder,
  useAudioRecorderState,
} from "expo-audio";
import { EncodingType, getInfoAsync, readAsStringAsync } from "expo-file-system/legacy";
import { useRef, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  Pressable,
  StyleSheet,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { MicIcon } from "@/components/ActionIcons";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { colors, shadow } from "@/lib/theme";

const MAX_MS = 30_000;
const MIN_MS = 900;
/** Tiny m4a headers are a few hundred bytes; real speech is larger. */
const MIN_BYTES = 2_500;

export function VoiceLogFab({
  babyId,
  onStatus,
}: {
  babyId: Id<"babies">;
  onStatus: (message: string | null) => void;
}) {
  const insets = useSafeAreaInsets();
  const logFromAudio = useAction(api.voiceLog.logFromAudio);
  const recorder = useAudioRecorder({
    ...RecordingPresets.HIGH_QUALITY,
    isMeteringEnabled: true,
    numberOfChannels: 1,
  });
  const recorderState = useAudioRecorderState(recorder, 200);
  const [busy, setBusy] = useState(false);
  const maxTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const recordingRef = useRef(false);
  const startingRef = useRef(false);
  const startedAtRef = useRef(0);

  async function ensureMicPermission(): Promise<boolean> {
    const current = await AudioModule.getRecordingPermissionsAsync();
    if (current.granted) return true;
    if (current.status !== "undetermined") {
      Alert.alert(
        "Microphone needed",
        "Allow mic access in Settings to voice-log.",
      );
      return false;
    }
    const requested = await AudioModule.requestRecordingPermissionsAsync();
    if (!requested.granted) {
      Alert.alert(
        "Microphone needed",
        "Allow mic access to log feeds and sleeps hands-free.",
      );
      return false;
    }
    return true;
  }

  async function startRecording() {
    if (busy || recordingRef.current || startingRef.current) return;
    startingRef.current = true;
    try {
      if (!Device.isDevice) {
        Alert.alert(
          "Use a real phone",
          "iOS Simulator mic is usually silent, so Whisper hears nothing. Run on a device.",
        );
        return;
      }
      if (!(await ensureMicPermission())) return;
      await setAudioModeAsync({
        playsInSilentMode: true,
        allowsRecording: true,
      });
      await recorder.prepareToRecordAsync();
      recorder.record();
      recordingRef.current = true;
      startedAtRef.current = Date.now();
      void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      onStatus("Listening… tap mic again to send");
      if (maxTimerRef.current) clearTimeout(maxTimerRef.current);
      maxTimerRef.current = setTimeout(() => {
        void finishRecording();
      }, MAX_MS);
    } catch (error) {
      recordingRef.current = false;
      onStatus(null);
      Alert.alert(
        "Could not record",
        error instanceof Error ? error.message : "Try again",
      );
    } finally {
      startingRef.current = false;
    }
  }

  async function finishRecording() {
    if (maxTimerRef.current) {
      clearTimeout(maxTimerRef.current);
      maxTimerRef.current = null;
    }
    if (!recordingRef.current) return;
    recordingRef.current = false;

    const elapsed = Date.now() - startedAtRef.current;
    if (elapsed < MIN_MS) {
      try {
        await recorder.stop();
      } catch {
        // ignore
      }
      onStatus(null);
      Alert.alert(
        "Too short",
        "Tap mic, speak for a second or two, then tap again to send.",
      );
      return;
    }

    try {
      await recorder.stop();
    } catch {
      // already stopped
    }

    const uri = recorder.uri;
    if (!uri) {
      onStatus(null);
      Alert.alert("Voice log", "No recording saved — try again.");
      return;
    }

    const info = await getInfoAsync(uri);
    const size = info.exists && "size" in info ? Number(info.size ?? 0) : 0;
    if (size < MIN_BYTES) {
      onStatus(null);
      Alert.alert(
        "No audio captured",
        Device.isDevice
          ? "Mic produced an empty clip. Check mic permission and try again."
          : "Simulator mic is silent — use a real phone.",
      );
      return;
    }

    setBusy(true);
    onStatus("Logging…");
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

    try {
      const audioBase64 = await readAsStringAsync(uri, {
        encoding: EncodingType.Base64,
      });
      const result = await logFromAudio({
        babyId,
        audioBase64,
        format: "m4a",
      });
      void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      onStatus(result.confirmation);
      setTimeout(() => onStatus(null), 5000);
    } catch (error) {
      void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      const message =
        error instanceof Error ? error.message : "Could not log from voice";
      onStatus(null);
      Alert.alert("Voice log", message);
    } finally {
      setBusy(false);
      try {
        await setAudioModeAsync({
          playsInSilentMode: true,
          allowsRecording: false,
        });
      } catch {
        // ignore
      }
    }
  }

  function onMicPress() {
    if (busy || startingRef.current) return;
    if (recordingRef.current || recorderState.isRecording) {
      void finishRecording();
      return;
    }
    void startRecording();
  }

  const recording = recorderState.isRecording || recordingRef.current;

  return (
    <View
      style={[styles.fab, { bottom: Math.max(insets.bottom, 12) + 8 }]}
      pointerEvents="box-none"
    >
      <Pressable
        disabled={busy}
        onPress={onMicPress}
        accessibilityLabel={recording ? "Stop voice log" : "Start voice log"}
        accessibilityHint="Tap to start, speak, tap again to log"
        style={[
          styles.btn,
          recording && styles.btnRecording,
          busy && styles.btnBusy,
        ]}
      >
        {busy ? (
          <ActivityIndicator color={colors.ink} />
        ) : (
          <MicIcon color={recording ? "#fff" : colors.ink} />
        )}
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  fab: {
    position: "absolute",
    left: 16,
    zIndex: 40,
    elevation: 40,
  },
  btn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.card,
    alignItems: "center",
    justifyContent: "center",
    ...shadow,
  },
  btnRecording: {
    backgroundColor: colors.danger,
  },
  btnBusy: {
    opacity: 0.85,
  },
});
