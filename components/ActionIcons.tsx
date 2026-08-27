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

export function AskIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.bubble, { backgroundColor: color }]} />
      <View style={[styles.bubbleTail, { borderTopColor: color }]} />
    </View>
  );
}

/** Simple mic glyph for voice log FAB. */
export function MicIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.micCapsule, { backgroundColor: color }]} />
      <View style={[styles.micStand, { backgroundColor: color }]} />
      <View style={[styles.micBase, { backgroundColor: color }]} />
    </View>
  );
}

export function SleepIcon({
  color = "#fff",
  cutColor = "#6D5EF5",
}: {
  color?: string;
  cutColor?: string;
}) {
  return (
    <View style={styles.box}>
      <View style={[styles.moon, { backgroundColor: color }]} />
      <View style={[styles.moonCut, { backgroundColor: cutColor }]} />
    </View>
  );
}

/** Play-mat + baby silhouette — geometric, no emoji. */
export function PumpIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.drop, { backgroundColor: color }]} />
    </View>
  );
}

export function MedicineIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={[styles.box, styles.pillRow]}>
      <View style={[styles.pillL, { backgroundColor: color }]} />
      <View style={[styles.pillR, { backgroundColor: color, opacity: 0.45 }]} />
    </View>
  );
}

export function PottyIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.seat, { borderColor: color }]} />
      <View style={[styles.seatBase, { backgroundColor: color }]} />
    </View>
  );
}

export function TypeIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.typeLine, { backgroundColor: color }]} />
      <View style={[styles.typeLineShort, { backgroundColor: color }]} />
    </View>
  );
}

export function ActivityIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.play, { borderLeftColor: color }]} />
    </View>
  );
}

export function TummyIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.mat, { backgroundColor: color, opacity: 0.45 }]} />
      <View style={[styles.tummyBody, { backgroundColor: color }]} />
      <View style={[styles.tummyHead, { backgroundColor: color }]} />
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
  bubble: {
    width: 16,
    height: 12,
    borderRadius: 5,
    marginTop: -2,
  },
  bubbleTail: {
    width: 0,
    height: 0,
    marginTop: -1,
    marginLeft: -6,
    borderLeftWidth: 4,
    borderRightWidth: 4,
    borderTopWidth: 5,
    borderLeftColor: "transparent",
    borderRightColor: "transparent",
  },
  micCapsule: {
    width: 10,
    height: 14,
    borderRadius: 5,
  },
  micStand: {
    width: 2,
    height: 4,
    marginTop: 1,
  },
  micBase: {
    width: 12,
    height: 2,
    borderRadius: 1,
  },
  moon: {
    width: 16,
    height: 16,
    borderRadius: 8,
  },
  moonCut: {
    position: "absolute",
    width: 13,
    height: 13,
    borderRadius: 7,
    right: 0,
    top: 1,
  },
  mat: {
    position: "absolute",
    width: 20,
    height: 12,
    borderRadius: 4,
    bottom: 2,
  },
  tummyBody: {
    width: 14,
    height: 8,
    borderRadius: 4,
    marginTop: 2,
  },
  tummyHead: {
    position: "absolute",
    width: 7,
    height: 7,
    borderRadius: 4,
    top: 1,
    right: 2,
  },
  drop: {
    width: 12,
    height: 16,
    borderRadius: 6,
    transform: [{ rotate: "180deg" }],
    borderTopLeftRadius: 10,
    borderTopRightRadius: 10,
  },
  pillRow: { flexDirection: "row" },
  pillL: {
    width: 10,
    height: 12,
    borderTopLeftRadius: 6,
    borderBottomLeftRadius: 6,
  },
  pillR: {
    width: 10,
    height: 12,
    borderTopRightRadius: 6,
    borderBottomRightRadius: 6,
  },
  seat: {
    width: 16,
    height: 10,
    borderWidth: 2.5,
    borderRadius: 5,
    marginBottom: 2,
  },
  seatBase: {
    width: 14,
    height: 3,
    borderRadius: 2,
  },
  typeLine: {
    width: 16,
    height: 3,
    borderRadius: 2,
    marginBottom: 3,
  },
  typeLineShort: {
    width: 11,
    height: 3,
    borderRadius: 2,
  },
  play: {
    width: 0,
    height: 0,
    marginLeft: 3,
    borderTopWidth: 7,
    borderBottomWidth: 7,
    borderLeftWidth: 12,
    borderTopColor: "transparent",
    borderBottomColor: "transparent",
  },
});
