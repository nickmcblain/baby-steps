import Accessibility
import Charts
import ScrunchCore
import SwiftUI

/// Port of {sleep,feed,tummy,nappy}/patterns.tsx.
struct PatternsView: View {
  enum Kind { case feed, sleep, tummy, nappy }

  let babyId: BabyID
  let kind: Kind

  @Environment(ConvexService.self) private var convex
  @Environment(AppRouter.self) private var router
  @State private var days = 7
  /// Stable window end so the query doesn't thrash every render.
  @State private var rangeEndMs = Date().epochMs
  @State private var sleep = Live<SleepPatterns>()
  @State private var feed = Live<FeedPatterns>()
  @State private var tummy = Live<TummyPatterns>()
  @State private var nappy = Live<NappyPatterns>()

  private struct Summary {
    var items: [PatternItem]
    var stats: [(String, String)]
  }

  private var accent: Color {
    switch kind {
    case .sleep: C.purple
    case .feed: C.teal
    case .tummy: C.sky
    case .nappy: C.peach
    }
  }

  private var soft: Color {
    switch kind {
    case .sleep: C.purpleSoft
    case .feed: C.tealSoft
    case .tummy: C.skySoft
    case .nappy: C.peachSoft
    }
  }

  private var statInk: Color {
    switch kind {
    case .sleep: C.purple
    case .feed: C.tealDark
    case .tummy: C.sky
    case .nappy: C.peach
    }
  }

  private var title: String {
    switch kind {
    case .sleep: "Sleep patterns"
    case .feed: "Feed patterns"
    case .tummy: "Tummy patterns"
    case .nappy: "Nappy patterns"
    }
  }

  private var addLabel: String {
    switch kind {
    case .sleep: "Add sleep"
    case .feed: "Add feed"
    case .tummy: "Add tummy time"
    case .nappy: "Add nappy"
    }
  }

  private var emptyText: String {
    switch kind {
    case .sleep: "No sleeps in this range yet."
    case .feed: "No feeds in this range yet."
    case .tummy: "No tummy time in this range yet."
    case .nappy: "No nappies in this range yet."
    }
  }

  private var summary: Summary? {
    switch kind {
    case .sleep:
      sleep.value.map { Summary(items: $0.sleeps, stats: [
        ("Avg sleep / day", Patterns.minutesPerDay($0.stats.avgSleepMinutesPerDay)),
        ("Avg sessions / day", Patterns.sessionsPerDay($0.stats.avgSessionsPerDay)),
      ]) }
    case .feed:
      feed.value.map { Summary(items: $0.feeds, stats: [
        ("Avg feed / day", Patterns.minutesPerDay($0.stats.avgFeedMinutesPerDay)),
        ("Avg sessions / day", Patterns.sessionsPerDay($0.stats.avgSessionsPerDay)),
      ]) }
    case .tummy:
      tummy.value.map { Summary(items: $0.tummies, stats: [
        ("Avg tummy / day", Patterns.minutesPerDay($0.stats.avgTummyMinutesPerDay)),
        ("Avg sessions / day", Patterns.sessionsPerDay($0.stats.avgSessionsPerDay)),
      ]) }
    case .nappy:
      nappy.value.map { Summary(items: $0.nappies, stats: [
        ("Avg / day", Patterns.sessionsPerDay($0.stats.avgSessionsPerDay)),
        ("Wee · poo", "\(jsNumber($0.stats.weeCount)) · \(jsNumber($0.stats.pooCount))"),
      ]) }
    }
  }

  private var eventKind: EventKind? {
    switch kind {
    case .sleep: .sleep
    case .feed: .feed
    case .nappy: .nappy
    case .tummy: nil
    }
  }

  var body: some View {
    ScreenScaffold {
      CircleIconButton(systemImage: "plus", label: addLabel, spokenNames: ["Add", "Plus"]) { add() }
    } content: {
      ScreenTitle(title)
      WrapLayout {
        ForEach(Patterns.ranges, id: \.self) { range in
          Button { days = range } label: {
            Text("\(range) days")
              .font(.app(.bold, 14))
              .foregroundStyle(days == range ? C.card : C.muted)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(days == range ? accent : C.card, in: Capsule())
              .frame(minHeight: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(PressScale())
          .accessibilityAddTraits(days == range ? .isSelected : [])
        }
      }

      if let summary {
        AdaptiveStack(spacing: 10) {
          ForEach(summary.stats, id: \.0) { label, value in
            VStack(alignment: .leading, spacing: 4) {
              Text(label.uppercased()).font(.app(.medium, 12)).tracking(0.5).foregroundStyle(statInk).accessibilityLabel(label)
              Text(value).font(.app(.bold, 20)).foregroundStyle(C.ink)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(soft, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .accessibilityElement(children: .combine)
          }
        }
        PatternChart(title: title, items: summary.items, days: days, rangeEndMs: rangeEndMs, barColor: accent, emptyText: emptyText)
      } else {
        Text("Loading…").font(.app(.body, 15)).foregroundStyle(C.muted)
      }

      if let eventKind {
        EventListView(babyId: babyId, kind: eventKind, window: Timeline.patternWindow(days: days, rangeEndMs: rangeEndMs))
          .id(days)
      }
    }
    .task(id: days) {
      switch kind {
      case .sleep: await sleep.bind(API.events.sleepPatterns(babyId: babyId, days: days, rangeEndMs: rangeEndMs), convex)
      case .feed: await feed.bind(API.events.feedPatterns(babyId: babyId, days: days, rangeEndMs: rangeEndMs), convex)
      case .tummy: await tummy.bind(API.events.tummyPatterns(babyId: babyId, days: days, rangeEndMs: rangeEndMs), convex)
      case .nappy: await nappy.bind(API.events.nappyPatterns(babyId: babyId, days: days, rangeEndMs: rangeEndMs), convex)
      }
    }
  }

  private func add() {
    switch kind {
    case .sleep: router.push(babyId, .sleepTimer)
    case .feed: router.push(babyId, .feedTimer)
    case .tummy: router.push(babyId, .tummyTimer)
    case .nappy: router.push(babyId, .nappy)
    }
  }
}

/// Port of components/SleepPatternChart.tsx: per-day bars, or a day × time-of-day chart.
struct PatternChart: View {
  let title: String
  let items: [PatternItem]
  let days: Int
  let rangeEndMs: EpochMs
  let barColor: Color
  let emptyText: String

  @State private var showChart = false
  @Environment(\.dynamicTypeSize) private var typeSize

  /// Nappies are instants; everything else has a duration worth reading out.
  private var timed: Bool { items.contains { $0.durationMinutes > 0 } }

  private struct Bar: Identifiable {
    let id: String
    let day: String
    let startMin: Double
    let endMin: Double
  }

  var body: some View {
    let rows = Patterns.days(items, days: days, rangeEndMs: rangeEndMs)

    if items.isEmpty {
      Text(emptyText)
        .font(.app(.body, 15))
        .foregroundStyle(C.muted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    } else {
      VStack(alignment: .leading, spacing: 10) {
        WrapLayout {
          switchPill("Bars", selected: !showChart) { showChart = false }
          switchPill("Chart", selected: showChart) { showChart = true }
        }
        Group {
          if showChart { chart(rows) } else { bars(rows) }
        }
        .accessibilityChartDescriptor(PatternChartDescriptor(title: title, rows: rows, timed: timed))
        Text(Spoken.patternSummary(rows))
          .font(.app(.body, 13))
          .foregroundStyle(C.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func switchPill(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.app(.bold, 14))
        .foregroundStyle(selected ? C.card : C.muted)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(selected ? C.ink : C.card, in: Capsule())
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(PressScale())
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityHint(label == "Bars" ? "Shows a bar per day" : "Shows a day by time-of-day chart")
  }

  private func bars(_ rows: [PatternDay]) -> some View {
    let stacked = typeSize.isAccessibilitySize
    return VStack(spacing: 8) {
      ForEach(rows) { row in
        AdaptiveStack(spacing: stacked ? 4 : 8) {
          Text(row.label).font(.app(.bold, 12)).foregroundStyle(C.ink).frame(width: stacked ? nil : 58, alignment: .leading)
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 6).fill(C.line)
              ForEach(Array(row.slices.enumerated()), id: \.offset) { _, slice in
                let start = slice.startMin / 1440
                let width = min(max(slice.endMin - slice.startMin, 12) / 1440, 1 - start)
                RoundedRectangle(cornerRadius: 4)
                  .fill(barColor)
                  .frame(width: geo.size.width * width)
                  .offset(x: geo.size.width * start)
              }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
          }
          .frame(height: 22)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.label)
        .accessibilityValue(Spoken.patternDay(row, timed: timed))
      }
      HStack(spacing: 0) {
        Color.clear.frame(width: stacked ? 0 : 66)
        GeometryReader { geo in
          ForEach([("12am", 0.0), ("6am", 0.25), ("12pm", 0.5), ("6pm", 0.75)], id: \.0) { label, at in
            Text(label).font(.app(.medium, 10)).foregroundStyle(C.muted).offset(x: geo.size.width * at)
          }
        }
        .frame(height: 16)
        .dynamicTypeSize(...DynamicTypeSize.large)
      }
      .accessibilityHidden(true)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
  }

  private func chart(_ rows: [PatternDay]) -> some View {
    let bars = rows.flatMap { row in
      row.slices.enumerated().map { index, slice in
        Bar(id: "\(row.dayStartMs)-\(index)", day: row.label, startMin: slice.startMin, endMin: max(slice.endMin, slice.startMin + 4))
      }
    }
    let labels = rows.map(\.label)
    let every = days > 7 ? 2 : 1

    return Chart(bars) { bar in
      RectangleMark(
        x: .value("Day", bar.day),
        yStart: .value("Start", -bar.startMin),
        yEnd: .value("End", -bar.endMin),
        width: .ratio(0.8)
      )
      .foregroundStyle(barColor.opacity(0.85))
      .clipShape(RoundedRectangle(cornerRadius: 5))
      .accessibilityLabel(bar.day)
      .accessibilityValue("\(Spoken.timeOfDay(minutes: bar.startMin)) to \(Spoken.timeOfDay(minutes: bar.endMin))")
    }
    .chartXScale(domain: labels)
    // Minutes are negated so midnight sits at the top, like the RN chart.
    .chartYScale(domain: -1440...0)
    .chartYAxis {
      AxisMarks(position: .leading, values: stride(from: 0.0, through: 1440, by: 180).map { -$0 }) { value in
        AxisGridLine().foregroundStyle(C.line)
        AxisValueLabel {
          if let minutes = value.as(Double.self) {
            Text(WeekGrid.formatHourLabel(Int(-minutes / 60))).font(.app(.medium, 10)).foregroundStyle(C.muted)
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: labels.enumerated().filter { $0.offset % every == 0 }.map(\.element)) { value in
        AxisValueLabel {
          if let label = value.as(String.self) {
            Text(label).font(.app(.bold, days > 7 ? 9 : 11)).foregroundStyle(C.ink)
          }
        }
      }
    }
    // Axis ticks stay readable-sized; the descriptor and the Bars view carry the detail at larger sizes.
    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    .frame(height: 320)
    .padding(8)
    .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
  }
}

/// Audio graph and VoiceOver chart summary for the pattern bars / chart.
struct PatternChartDescriptor: AXChartDescriptorRepresentable {
  let title: String
  let rows: [PatternDay]
  let timed: Bool

  func makeChartDescriptor() -> AXChartDescriptor {
    let counts = rows.map { Double($0.slices.count) }
    let xAxis = AXCategoricalDataAxisDescriptor(title: "Day", categoryOrder: rows.map(\.label))
    let yAxis = AXNumericDataAxisDescriptor(
      title: "Logged",
      range: 0...max(1, counts.max() ?? 1),
      gridlinePositions: []
    ) { "\(Int($0)) logged" }
    let series = AXDataSeriesDescriptor(
      name: "Logged per day",
      isContinuous: false,
      dataPoints: rows.map { row in
        AXDataPoint(x: row.label, y: Double(row.slices.count), additionalValues: [], label: Spoken.patternDay(row, timed: timed))
      }
    )
    return AXChartDescriptor(
      title: title,
      summary: Spoken.patternSummary(rows),
      xAxis: xAxis,
      yAxis: yAxis,
      additionalAxes: [],
      series: [series]
    )
  }
}
