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

/// Month calendar for picking the day Home is showing.
struct HomeDatePickerSheet: View {
  @Binding var dayStart: EpochMs
  @Environment(\.dismiss) private var dismiss
  @State private var pickerDate: Date

  init(dayStart: Binding<EpochMs>) {
    self._dayStart = dayStart
    self._pickerDate = State(initialValue: Date(epochMs: dayStart.wrappedValue))
  }

  var body: some View {
    NavigationStack {
      DatePicker(selection: $pickerDate, in: ...Date(), displayedComponents: .date) {
        Text("Pick a date")
      }
      .datePickerStyle(.graphical)
      .labelsHidden()
      .tint(C.teal)
      .padding(.horizontal, 8)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(C.bg.ignoresSafeArea())
      .navigationTitle("Pick a date")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Today") { select(Date()) }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
            .fontWeight(.semibold)
        }
      }
      .onChange(of: pickerDate) { _, date in
        select(date)
      }
    }
  }

  private func select(_ date: Date) {
    dayStart = WeekGrid.startOfLocalDay(date.epochMs)
    dismiss()
  }
}

/// Port of components/DayRhythmBar.tsx: 24h bar from 7am, with a "now" marker.
struct DayRhythmBar: View {
  let rhythm: DayRhythm
  let now: EpochMs
  var embedded = true
  let onTap: () -> Void

  private let napFill = C.napFill
  private let ticks = [7, 13, 19, 1].map { WeekGrid.formatHourLabel($0) }

  var body: some View {
    VStack(alignment: .leading, spacing: embedded ? 8 : 10) {
      if !embedded {
        Text(rhythm.source == .logs ? "Usual day" : "Typical day")
          .font(.app(.medium, 12))
          .foregroundStyle(C.purpleInk)
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
      .frame(minHeight: 44)
      .contentShape(Rectangle())
      .buttonStyle(.plain)
      .accessibilityLabel(rhythm.source == .logs ? "Usual day" : "Typical day")
      .accessibilityValue(rhythm.caption)
      .accessibilityHint("Opens sleep patterns")
      .accessibilityInputLabels(["Day rhythm", "Usual day", "Typical day"])
      ViewThatFits(in: .horizontal) {
        tickRow(ticks)
        tickRow(ticks.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element))
        tickRow([ticks[0]])
      }
      .accessibilityHidden(true)
    }
    .padding(embedded ? 0 : 16)
    .background {
      if !embedded {
        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(C.card).cardShadow()
      }
    }
  }

  private func tickRow(_ labels: [String]) -> some View {
    HStack {
      ForEach(labels, id: \.self) { tick in
        Text(tick)
          .font(.app(.medium, 11, relativeTo: .caption))
          .foregroundStyle(C.muted)
          .fixedSize()
        if tick != labels.last { Spacer(minLength: 4) }
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

/// Hairline-topped footer used under the home cards.
struct LastStrip: View {
  let text: String
  var inset: CGFloat = 12
  /// Side-by-side tiles reserve two lines so their footers line up.
  var reservesTwoLines = true

  var body: some View {
    Text(text)
      .font(.app(.medium, 11, relativeTo: .caption))
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
