import { StyleSheet, View } from "react-native";

/** Geometric action glyphs — no emoji fonts (broken on some iOS simulators). */

export function FeedIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.bottleNeck, { backgroundColor: color }]} />
      <View style={[styles.bottleBody, { backgroundColor: color }]} />
    </View>
  );
}

export function NappyIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.nappyTop, { backgroundColor: color }]} />
      <View style={[styles.nappyTabL, { backgroundColor: color }]} />
      <View style={[styles.nappyTabR, { backgroundColor: color }]} />
    </View>
  );
}

export function TempIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.thermoStem, { backgroundColor: color }]} />
      <View style={[styles.thermoBulb, { backgroundColor: color }]} />
    </View>
  );
}

export function LogIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.clockRing, { borderColor: color }]} />
      <View style={[styles.clockHandH, { backgroundColor: color }]} />
      <View style={[styles.clockHandV, { backgroundColor: color }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  box: {
    width: 22,
    height: 22,
    alignItems: "center",
    justifyContent: "center",
  },
  bottleNeck: {
    width: 7,
    height: 5,
    borderTopLeftRadius: 2,
    borderTopRightRadius: 2,
    marginBottom: -1,
  },
  bottleBody: {
    width: 14,
    height: 14,
    borderRadius: 5,
  },
  nappyTop: {
    width: 18,
    height: 12,
    borderRadius: 6,
  },
  nappyTabL: {
    position: "absolute",
    left: 0,
    bottom: 2,
    width: 5,
    height: 8,
    borderRadius: 2,
  },
  nappyTabR: {
    position: "absolute",
    right: 0,
    bottom: 2,
    width: 5,
    height: 8,
    borderRadius: 2,
  },
  thermoStem: {
    width: 5,
    height: 12,
    borderRadius: 3,
    marginBottom: -3,
  },
  thermoBulb: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  clockRing: {
    width: 18,
    height: 18,
    borderRadius: 9,
    borderWidth: 2.5,
    position: "absolute",
  },
  clockHandH: {
    position: "absolute",
    width: 6,
    height: 2.5,
    borderRadius: 2,
    left: 11,
    top: 10,
  },
  clockHandV: {
    position: "absolute",
    width: 2.5,
    height: 6,
    borderRadius: 2,
    left: 10,
    top: 5,
  },
});
