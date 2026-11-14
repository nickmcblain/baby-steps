import ScrunchCore
import SwiftUI
import WidgetKit

// Port of widgets/BabyGlanceWidget.tsx. Same kind string, so widgets people already
// placed keep working after the update.

struct GlanceEntry: TimelineEntry {
  let date: Date
  let snapshot: GlanceSnapshot
}

struct GlanceProvider: TimelineProvider {
  func placeholder(in context: Context) -> GlanceEntry {
    GlanceEntry(date: .now, snapshot: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> Void) {
    completion(GlanceEntry(date: .now, snapshot: GlanceStore.load() ?? .placeholder))
  }

  /// The app pushes a new snapshot and reloads; there is nothing to compute ahead of time.
  func getTimeline(in context: Context, completion: @escaping (WidgetKit.Timeline<GlanceEntry>) -> Void) {
    let entry = GlanceEntry(date: .now, snapshot: GlanceStore.load() ?? .placeholder)
    completion(WidgetKit.Timeline(entries: [entry], policy: .never))
  }
}

struct BabyGlanceWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: GlanceStore.widgetKind, provider: GlanceProvider()) { entry in
      GlanceRouter(snapshot: entry.snapshot)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
    .configurationDisplayName("Scrunch")
    .description("Next nap, last feed and nappy at a glance")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
  }
}

private struct GlanceRouter: View {
  let snapshot: GlanceSnapshot

  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .accessoryRectangular, .accessoryInline: GlanceAccessoryView(snapshot: snapshot)
    default: GlanceView(snapshot: snapshot)
    }
  }
}

struct GlanceView: View {
  let snapshot: GlanceSnapshot

  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  private var dark: Bool { scheme == .dark }
  private var ink: Color { dark ? Color(hex: 0xF3F4F6) : Color(hex: 0x12141A) }
  private var muted: Color { dark ? Color(hex: 0x9AA0A8) : Color(hex: 0x8A9099) }
  private var purple: Color { dark ? Color(hex: 0x8B80FF) : Color(hex: 0x6D5EF5) }
  private var teal: Color { dark ? Color(hex: 0x5EE0D2) : Color(hex: 0x0B9E90) }
  private let peach = Color(hex: 0xFF8A65)

  var body: some View {
    if family == .systemMedium {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          header
          Spacer()
          Text(snapshot.sleepToday)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(muted)
        }
        HStack(spacing: 12) {
          row("moon.fill", purple, "Next nap", snapshot.nextNap)
          row("drop.fill", teal, "Last feed", snapshot.lastFeed)
        }
        row("circle.grid.2x2.fill", peach, "Last nappy", snapshot.lastNappy)
      }
    } else {
      VStack(alignment: .leading, spacing: 8) {
        header
        row("moon.fill", purple, "Next nap", snapshot.nextNap)
        row("drop.fill", teal, "Last feed", snapshot.lastFeed)
      }
    }
  }

  private var header: some View {
    Text(snapshot.babyName)
      .font(.system(size: 15, weight: .bold))
      .foregroundStyle(ink)
      .lineLimit(1)
  }

  private func row(_ symbol: String, _ color: Color, _ label: String, _ value: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: symbol).foregroundStyle(color)
      VStack(alignment: .leading, spacing: 0) {
        Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
        Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.8)
      }
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}
