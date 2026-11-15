import ScrunchCore
import SwiftUI

/// Port of components/ProgressRing.tsx.
struct ProgressRing: View {
  let progress: Double
  var size: CGFloat = 36
  var stroke: CGFloat = 4
  let color: Color
  let track: Color

  var body: some View {
    ZStack {
      Circle().stroke(track, lineWidth: stroke)
      Circle()
        .trim(from: 0, to: min(1, max(0, progress)))
        .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
    .padding(stroke / 2)
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

/// Port of components/WeekStrip.tsx (Monday-first week of the selected day).
struct WeekStrip: View {
  let selectedDayStart: EpochMs
  let onSelect: (EpochMs) -> Void

  var body: some View {
    let weekStart = WeekGrid.startOfWeekMonday(selectedDayStart)
    let todayStart = WeekGrid.startOfLocalDay(Date().epochMs)
    HStack(spacing: 4) {
      ForEach(WeekGrid.weekDayLabels(weekStart), id: \.dayStartMs) { day in
        let selected = day.dayStartMs == selectedDayStart
        let isToday = day.dayStartMs == todayStart
        let ink: Color = selected ? C.ink : (isToday ? C.tealDark : C.muted)
        Button { onSelect(day.dayStartMs) } label: {
          VStack(spacing: 4) {
            Text(day.label).font(.app(.medium, 12, relativeTo: .caption))
            Text("\(day.dateNum)").font(.app(.bold, 16))
          }
          .foregroundStyle(ink)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background {
            if selected {
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(C.card)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xE4E6EA), lineWidth: 1))
            }
          }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
  }
}

/// Port of components/DayRhythmBar.tsx: 24h bar from 7am, with a "now" marker.
struct DayRhythmBar: View {
  let rhythm: DayRhythm
  let now: EpochMs
  var embedded = true
  let onTap: () -> Void

  private let napFill = Color(hex: 0xC4BEF8)
  private let ticks = [7, 13, 19, 1].map { WeekGrid.formatHourLabel($0) }

  var body: some View {
    VStack(alignment: .leading, spacing: embedded ? 8 : 10) {
      if !embedded {
        Text(rhythm.source == .logs ? "Usual day" : "Typical day")
          .font(.app(.medium, 12))
          .foregroundStyle(C.purple)
      }
      Button(action: onTap) {
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            HStack(spacing: 0) {
              ForEach(Array(rhythm.segments.enumerated()), id: \.offset) { _, segment in
                fill(segment.kind)
                  .frame(width: geo.size.width * CGFloat(segment.end - segment.start) / 1440)
              }
            }
            Rectangle()
              .fill(C.ink)
              .frame(width: 2)
              .offset(x: geo.size.width * CGFloat(DayRhythmEngine.dayBarOffset(now) / 1440) - 1)
          }
        }
        .frame(height: 28)
        .background(C.line)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(rhythm.caption)
      HStack {
        ForEach(ticks, id: \.self) { tick in
          Text(tick).font(.app(.medium, 11, relativeTo: .caption2)).foregroundStyle(C.muted)
          if tick != ticks.last { Spacer() }
        }
      }
    }
    .padding(embedded ? 0 : 16)
    .background {
      if !embedded {
        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(C.card).cardShadow()
      }
    }
  }

  private func fill(_ kind: RhythmKind) -> Color {
    switch kind {
    case .night: C.purple
    case .nap: napFill
    case .awake: C.line
    }
  }
}

/// Hairline-topped one-line footer used under the home cards.
struct LastStrip: View {
  let text: String
  var inset: CGFloat = 12
  /// Side-by-side tiles reserve two lines so their footers line up.
  var reservesTwoLines = true

  var body: some View {
    Text(text)
      .font(.app(.medium, 11, relativeTo: .caption2))
      .foregroundStyle(C.muted)
      .lineLimit(2, reservesSpace: reservesTwoLines)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, inset)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(C.card)
      .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 0.5) }
  }
}
