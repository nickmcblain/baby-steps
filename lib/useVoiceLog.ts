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
import { Alert } from "react-native";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";

const MAX_MS = 30_000;
const MIN_MS = 900;
const MIN_BYTES = 2_500;

export function useVoiceLog(babyId: Id<"babies"> | null) {
  const logFromAudio = useAction(api.voiceLog.logFromAudio);
  const recorder = useAudioRecorder({
    ...RecordingPresets.HIGH_QUALITY,
    isMeteringEnabled: true,
    numberOfChannels: 1,
  });
  const recorderState = useAudioRecorderState(recorder, 200);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);
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
        "Allow mic access in Settings to speak a log.",
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
    if (!babyId || busy || recordingRef.current || startingRef.current) return;
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
      setStatus("Listening… tap again to send");
      if (maxTimerRef.current) clearTimeout(maxTimerRef.current);
      maxTimerRef.current = setTimeout(() => {
        void finishRecording();
      }, MAX_MS);
    } catch (error) {
      recordingRef.current = false;
      setStatus(null);
      Alert.alert(
        "Could not record",
        error instanceof Error ? error.message : "Try again",
      );
    } finally {
      startingRef.current = false;
    }
  }

  async function finishRecording(): Promise<
    | { transcript: string; confirmation: string; handoff: "ask" | null }
    | null
  > {
    if (maxTimerRef.current) {
      clearTimeout(maxTimerRef.current);
      maxTimerRef.current = null;
    }
    if (!recordingRef.current || !babyId) return null;
    recordingRef.current = false;

    const elapsed = Date.now() - startedAtRef.current;
    if (elapsed < MIN_MS) {
      try {
        await recorder.stop();
      } catch {
        // ignore
      }
      setStatus(null);
      Alert.alert(
        "Too short",
        "Tap Speak, talk for a second or two, then tap again to send.",
      );
      return null;
    }

    try {
      await recorder.stop();
    } catch {
      // already stopped
    }

    const uri = recorder.uri;
    if (!uri) {
      setStatus(null);
      Alert.alert("Voice log", "No recording saved — try again.");
      return null;
    }

    const info = await getInfoAsync(uri);
    const size = info.exists && "size" in info ? Number(info.size ?? 0) : 0;
    if (size < MIN_BYTES) {
      setStatus(null);
      Alert.alert(
        "No audio captured",
        Device.isDevice
          ? "Mic produced an empty clip. Check mic permission and try again."
          : "Simulator mic is silent — use a real phone.",
      );
      return null;
    }

    setBusy(true);
    setStatus("Logging…");
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
      setStatus(null);
      return result;
    } catch (error) {
      void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      setStatus(null);
      Alert.alert(
        "Voice log",
        error instanceof Error ? error.message : "Could not log from voice",
      );
      return null;
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

  async function toggle() {
    if (busy || startingRef.current) return null;
    if (recordingRef.current || recorderState.isRecording) {
      return finishRecording();
    }
    await startRecording();
    return null;
  }

  async function cancel() {
    if (maxTimerRef.current) {
      clearTimeout(maxTimerRef.current);
      maxTimerRef.current = null;
    }
    if (!recordingRef.current) return;
    recordingRef.current = false;
    setStatus(null);
    try {
      await recorder.stop();
    } catch {
      // ignore
    }
  }

  return {
    busy,
    recording: recorderState.isRecording || recordingRef.current,
    status,
    toggle,
    cancel,
  };
}
