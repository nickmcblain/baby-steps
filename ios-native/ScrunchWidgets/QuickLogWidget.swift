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
    case .accessoryCircular where nappiesLocked:
      Button(intent: OpenPaywallIntent()) {
        ZStack {
          AccessoryWidgetBackground()
          Image(systemName: "lock.fill").font(.system(size: 16, weight: .bold))
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Self.lockedLabel)
    case .accessoryCircular:
      Button(intent: LogNappyIntent(nappy: .wet)) {
        ZStack {
          AccessoryWidgetBackground()
          VStack(spacing: 0) {
            Image(systemName: "drop.fill").font(.system(size: 16, weight: .bold))
            Text(QuickLog.Nappy.wet.label).font(.custom("Nunito-Bold", size: 11, relativeTo: .caption))
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
        .font(.custom("Nunito-SemiBold", size: 13, relativeTo: .footnote))
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
      .font(.custom("Fredoka-Bold", size: 15, relativeTo: .subheadline))
      .lineLimit(1)
  }

  /// Past the free nappies the buttons open Scrunch to the paywall rather than logging.
  private var nappiesLocked: Bool {
    guard let babyId = QuickLogStore.babies.active?.id else { return false }
    return !SharedAllowance.load(from: GlanceStore.defaults).canLog(.nappy(.wet), babyId: babyId)
  }

  private static let lockedLabel: LocalizedStringKey = "Free nappies used. Open Scrunch to subscribe"

  private var buttons: some View {
    Grid(horizontalSpacing: 6, verticalSpacing: 6) {
      GridRow {
        nappyButton(.wet, symbol: "drop.fill", spoken: "Log a wet nappy")
        nappyButton(.dirty, symbol: "circle.fill", spoken: "Log a dirty nappy")
      }
      GridRow {
        nappyButton(.both, symbol: "circle.grid.2x2.fill", spoken: "Log a wet and dirty nappy")
        QuickLogButton(intent: StartTimerIntent(timer: .feed), symbol: "timer", label: String(localized: "Feed"), spoken: "Start a feed timer")
      }
    }
  }

  @ViewBuilder
  private func nappyButton(_ option: NappyOption, symbol: String, spoken: LocalizedStringKey) -> some View {
    if nappiesLocked {
      QuickLogButton(intent: OpenPaywallIntent(), symbol: "lock.fill", label: option.nappy.label, spoken: Self.lockedLabel)
    } else {
      QuickLogButton(intent: LogNappyIntent(nappy: option), symbol: symbol, label: option.nappy.label, spoken: spoken)
    }
  }
}

struct QuickLogButton<Intent: AppIntent>: View {
  let intent: Intent
  let symbol: String
  let label: String
  let spoken: LocalizedStringKey

  var body: some View {
    Button(intent: intent) {
      VStack(spacing: 2) {
        Image(systemName: symbol).font(.system(size: 14, weight: .bold))
        Text(label).font(.custom("Nunito-Bold", size: 12, relativeTo: .caption)).lineLimit(1)
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
