import ActivityKit
import ScrunchCore
import SwiftUI
import WidgetKit

// Port of widgets/BabyTimerActivity.tsx.

struct BabyTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BabyTimerAttributes.self) { context in
      let state = context.state
      HStack(spacing: 12) {
        Image(systemName: state.symbol).foregroundStyle(state.accent).font(.title2).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text(state.title).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
          if !state.subtitle.isEmpty {
            Text(state.subtitle).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
          }
          Label(state.running ? "Timing…" : "Paused", systemImage: state.running ? "record.circle" : "pause.fill")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.6))
        }
        Spacer()
        TimerClockText(state: state, size: 28).frame(width: 110, alignment: .trailing)
      }
      .padding(14)
      .accessibilityElement(children: .combine)
      .activityBackgroundTint(Color.black.opacity(0.85))
      .activitySystemActionForegroundColor(.white)
      .widgetURL(context.attributes.deepLink)
    } dynamicIsland: { context in
      let state = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 4) {
            Image(systemName: state.symbol).foregroundStyle(state.accent).accessibilityHidden(true)
            Text(state.shortLabel).font(.system(size: 12)).foregroundStyle(.white)
          }
          .padding(10)
          .accessibilityElement(children: .combine)
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 2) {
            TimerClockText(state: state, size: 24).frame(width: 100, alignment: .trailing)
            Text(state.running ? "Running" : "Paused").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
          }
          .padding(10)
          .accessibilityElement(children: .combine)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 2) {
            Text(state.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            if !state.subtitle.isEmpty {
              Text(state.subtitle).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
            }
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

/// Counts up natively while running, so the Island keeps ticking with the app suspended.
struct TimerClockText: View {
  let state: TimerActivityContent
  let size: CGFloat

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
    .foregroundStyle(.white)
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
