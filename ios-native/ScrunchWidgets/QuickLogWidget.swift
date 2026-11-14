import AppIntents
import ScrunchCore
import SwiftUI
import WidgetKit

/// Interactive widget: log a nappy or start a feed without opening the app. Small and
/// medium also show in StandBy; the circular one sits on the Lock Screen.
struct QuickLogWidget: Widget {
  static let kind = "QuickLogWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: GlanceProvider()) { entry in
      QuickLogView(snapshot: entry.snapshot)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
    .configurationDisplayName("Quick log")
    .description("Log a nappy or start a feed without opening Scrunch.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
  }
}

struct QuickLogView: View {
  let snapshot: GlanceSnapshot

  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .accessoryCircular:
      Button(intent: LogNappyIntent(nappy: .wet)) {
        ZStack {
          AccessoryWidgetBackground()
          VStack(spacing: 0) {
            Image(systemName: "drop.fill").font(.system(size: 16, weight: .bold))
            Text("Wee").font(.system(size: 11, weight: .bold))
          }
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Log a wet nappy")
    case .systemMedium:
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          title
          Label(snapshot.lastFeed, systemImage: "drop.fill")
          Label(snapshot.lastNappy, systemImage: "circle.grid.2x2.fill")
          Spacer(minLength: 0)
        }
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        buttons
      }
    default:
      VStack(alignment: .leading, spacing: 6) {
        title
        buttons
      }
    }
  }

  private var title: some View {
    Text(snapshot.babyName)
      .font(.system(size: 15, weight: .bold))
      .lineLimit(1)
  }

  private var buttons: some View {
    Grid(horizontalSpacing: 6, verticalSpacing: 6) {
      GridRow {
        QuickLogButton(intent: LogNappyIntent(nappy: .wet), symbol: "drop.fill", label: "Wee", spoken: "Log a wet nappy")
        QuickLogButton(intent: LogNappyIntent(nappy: .dirty), symbol: "circle.fill", label: "Poo", spoken: "Log a dirty nappy")
      }
      GridRow {
        QuickLogButton(intent: LogNappyIntent(nappy: .both), symbol: "circle.grid.2x2.fill", label: "Both", spoken: "Log a wet and dirty nappy")
        QuickLogButton(intent: StartTimerIntent(timer: .feed), symbol: "timer", label: "Feed", spoken: "Start a feed timer")
      }
    }
  }
}

struct QuickLogButton<Intent: AppIntent>: View {
  let intent: Intent
  let symbol: String
  let label: String
  let spoken: String

  var body: some View {
    Button(intent: intent) {
      VStack(spacing: 2) {
        Image(systemName: symbol).font(.system(size: 14, weight: .bold))
        Text(label).font(.system(size: 12, weight: .bold)).lineLimit(1)
      }
      .foregroundStyle(.primary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(spoken)
  }
}

/// Lock Screen glances for the existing glance widget.
struct GlanceAccessoryView: View {
  let snapshot: GlanceSnapshot

  @Environment(\.widgetFamily) private var family

  var body: some View {
    if family == .accessoryInline {
      Label("Feed \(snapshot.lastFeed)", systemImage: "drop.fill")
    } else {
      VStack(alignment: .leading, spacing: 1) {
        Text(snapshot.babyName).font(.headline).widgetAccentable().lineLimit(1)
        Label(snapshot.lastFeed, systemImage: "drop.fill").lineLimit(1)
        Label(snapshot.lastNappy, systemImage: "circle.grid.2x2.fill").lineLimit(1)
      }
      .font(.caption)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

@available(iOS 18.0, *)
struct StartFeedControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "com.nickmcblain.babysteps.start-feed") {
      ControlWidgetButton(action: StartTimerIntent(timer: .feed)) {
        Label("Start a feed", systemImage: "drop.fill")
      }
    }
    .displayName("Start a feed")
    .description("Starts a feed timer for your baby.")
  }
}

@available(iOS 18.0, *)
struct StartNapControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "com.nickmcblain.babysteps.start-nap") {
      ControlWidgetButton(action: StartTimerIntent(timer: .nap)) {
        Label("Start a nap", systemImage: "moon.fill")
      }
    }
    .displayName("Start a nap")
    .description("Starts a sleep timer for your baby.")
  }
}
