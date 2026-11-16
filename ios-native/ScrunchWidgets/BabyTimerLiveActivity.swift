import ActivityKit
import ScrunchCore
import SwiftUI
import WidgetKit

// Port of widgets/BabyTimerActivity.tsx.

struct BabyTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BabyTimerAttributes.self) { context in
      let state = context.state
      LockScreenTimerBanner(state: state)
        .activityBackgroundTint(Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
          ? UIColor.black.withAlphaComponent(0.85)
          : UIColor.white.withAlphaComponent(0.92) }))
        .activitySystemActionForegroundColor(Color(uiColor: .label))
        .widgetURL(context.attributes.deepLink)
    } dynamicIsland: { context in
      let state = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 4) {
            Image(systemName: state.symbol).foregroundStyle(state.accent).accessibilityHidden(true)
            Text(state.shortLabel).font(.custom("Nunito-SemiBold", size: 12, relativeTo: .caption)).foregroundStyle(.white)
          }
          .padding(10)
          .accessibilityElement(children: .combine)
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 2) {
            TimerClockText(state: state, size: 24).frame(width: 100, alignment: .trailing)
            Text(state.running ? "Running" : "Paused").font(.custom("Nunito-SemiBold", size: 11, relativeTo: .caption)).foregroundStyle(.white.opacity(0.75))
          }
          .padding(10)
          .accessibilityElement(children: .combine)
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(state.title).font(.custom("Fredoka-SemiBold", size: 15, relativeTo: .subheadline)).foregroundStyle(.white)
              if !state.subtitle.isEmpty {
                Text(state.subtitle).font(.custom("Nunito-SemiBold", size: 13, relativeTo: .footnote)).foregroundStyle(.white.opacity(0.75))
              }
            }
            Spacer()
            StopTimerButton(accent: state.accent)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 12)
          .padding(.bottom, 10)
        }
      } compactLeading: {
        Image(systemName: state.symbol).foregroundStyle(state.accent).accessibilityLabel(state.shortLabel)
      } compactTrailing: {
        TimerClockText(state: state, size: 16).frame(width: 64, alignment: .trailing)
      } minimal: {
        TimerClockText(state: state, size: 12).frame(width: 44, alignment: .trailing)
      }
      .widgetURL(context.attributes.deepLink)
    }
  }
}

/// Lock Screen / banner presentation. Follows the system appearance so text stays AA on the banner.
private struct LockScreenTimerBanner: View {
  let state: TimerActivityContent
  @Environment(\.colorScheme) private var scheme

  private var dark: Bool { scheme == .dark }
  private var ink: Color { dark ? .white : Color(hex: 0x12141A) }
  private var secondary: Color { dark ? Color.white.opacity(0.75) : Color(hex: 0x4A505A) }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: state.symbol)
        .foregroundStyle(dark ? state.accent : state.accentInk)
        .font(.title2)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(state.title)
          .font(.custom("Fredoka-Bold", size: 16, relativeTo: .callout))
          .foregroundStyle(ink)
        if !state.subtitle.isEmpty {
          Text(state.subtitle)
            .font(.custom("Nunito-SemiBold", size: 13, relativeTo: .footnote))
            .foregroundStyle(secondary)
        }
        Label(state.running ? "Timing…" : "Paused", systemImage: state.running ? "record.circle" : "pause.fill")
          .font(.custom("Nunito-SemiBold", size: 12, relativeTo: .caption))
          .foregroundStyle(secondary)
      }
      Spacer()
      TimerClockText(state: state, size: 28, color: ink).frame(width: 110, alignment: .trailing)
      StopTimerButton(accent: state.accent)
    }
    .padding(14)
    .accessibilityElement(children: .combine)
  }
}

/// Saves the timer as a log and ends the Live Activity, without opening the app.
struct StopTimerButton: View {
  let accent: Color

  var body: some View {
    Button(intent: StopTimerIntent()) {
      Image(systemName: "stop.fill")
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(Color(hex: 0x12141A))
        .frame(width: 40, height: 40)
        .background(accent, in: Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Stop and save")
  }
}

/// Counts up natively while running, so the Island keeps ticking with the app suspended.
struct TimerClockText: View {
  let state: TimerActivityContent
  let size: CGFloat
  var color: Color = .white

  var body: some View {
    Group {
      if state.running {
        Text(
          timerInterval: Date(timeIntervalSince1970: state.startEpochMs / 1000)...Date(timeIntervalSince1970: state.endEpochMs / 1000),
          countsDown: false
        )
      } else {
        Text(state.pausedLabel)
      }
    }
    .font(.system(size: size, weight: .bold))
    .monospacedDigit()
    .foregroundStyle(color)
    .multilineTextAlignment(.trailing)
    .lineLimit(1)
    .minimumScaleFactor(0.6)
  }
}

extension TimerActivityContent {
  var accent: Color {
    switch style {
    case .sleep: Color(hex: 0x6D5EF5)
    case .tummy: Color(hex: 0x4BA3E3)
    case .feed: Color(hex: 0x14C4B2)
    }
  }

  /// Darker accent for the light Lock Screen banner (3:1+ on white for the icon).
  var accentInk: Color {
    switch style {
    case .sleep: Color(hex: 0x5B4FE0)
    case .tummy: Color(hex: 0x1D6FA8)
    case .feed: Color(hex: 0x0F766E)
    }
  }

  var symbol: String {
    switch style {
    case .sleep: "moon.fill"
    case .tummy: "figure.arms.open"
    case .feed: "drop.fill"
    }
  }

  var shortLabel: String {
    switch style {
    case .sleep: "Sleep"
    case .tummy: "Tummy"
    case .feed: "Feed"
    }
  }
}
