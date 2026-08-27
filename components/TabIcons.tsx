import { StyleSheet, View } from "react-native";

export function HomeTabIcon({ color }: { color: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.roof, { borderBottomColor: color }]} />
      <View style={[styles.body, { backgroundColor: color }]} />
    </View>
  );
}

export function TimelineTabIcon({ color }: { color: string }) {
  return (
    <View style={[styles.box, styles.bars]}>
      <View style={[styles.bar, { height: 8, backgroundColor: color }]} />
      <View style={[styles.bar, { height: 14, backgroundColor: color }]} />
      <View style={[styles.bar, { height: 10, backgroundColor: color }]} />
    </View>
  );
}

export function KidsTabIcon({ color }: { color: string }) {
  return (
    <View style={styles.box}>
      <View style={[styles.head, { backgroundColor: color, left: 2 }]} />
      <View style={[styles.head, { backgroundColor: color, right: 2 }]} />
      <View style={[styles.shoulders, { backgroundColor: color }]} />
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
  roof: {
    width: 0,
    height: 0,
    borderLeftWidth: 9,
    borderRightWidth: 9,
    borderBottomWidth: 8,
    borderLeftColor: "transparent",
    borderRightColor: "transparent",
    marginBottom: -1,
  },
  body: {
    width: 14,
    height: 10,
    borderBottomLeftRadius: 2,
    borderBottomRightRadius: 2,
  },
  bars: {
    flexDirection: "row",
    alignItems: "flex-end",
    gap: 3,
    paddingBottom: 2,
  },
  bar: {
    width: 4,
    borderRadius: 2,
  },
  head: {
    position: "absolute",
    top: 2,
    width: 7,
    height: 7,
    borderRadius: 4,
  },
  shoulders: {
    position: "absolute",
    bottom: 2,
    width: 18,
    height: 8,
    borderRadius: 4,
  },
});