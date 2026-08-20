import AsyncStorage from "@react-native-async-storage/async-storage";

const KEY = "baby-steps.activeBabyId";

export async function getActiveBabyId(): Promise<string | null> {
  return AsyncStorage.getItem(KEY);
}

export async function setActiveBabyId(id: string): Promise<void> {
  await AsyncStorage.setItem(KEY, id);
}
