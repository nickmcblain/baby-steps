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
  /// Feed totals come from the events themselves: pattern items carry no millilitres.
  @State private var feedEvents = Live<EventPage>()
  @State private var tummy = Live<TummyPatterns>()
  @State private var nappy = Live<NappyPatterns>()

  /// Enough for two weeks of a busy newborn's logs.
  private static let feedEventLimit = 500

  private struct Summary {
    var items: [PatternItem]
    var stats: [(String, String)]
    var loggedDays: Int
    var feedTotals: FeedTotals? = nil
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

  private var kindSymbol: String {
    switch kind {
    case .sleep: EventKind.sleep.symbol
    case .feed: EventKind.feed.symbol
    case .tummy: EventKind.tummy.symbol
    case .nappy: EventKind.nappy.symbol
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

  private var empty: (title: String, message: String) {
    switch kind {
    case .sleep: ("No sleeps logged yet", "Time a nap or add one you remember. Patterns show up after a few days.")
    case .feed: ("No feeds logged yet", "Log feeds as they happen to see feeds and bottle milk for each day.")
    case .tummy: ("No tummy time yet", "A few minutes a day on their tummy helps. Time a session to start.")
    case .nappy: ("No nappies logged yet", "Log each change to see wees and poos for each day.")
    }
  }

  private func loggedDays(_ items: [PatternItem]) -> Int {
    Patterns.loggedDays(Patterns.days(items, days: days, rangeEndMs: rangeEndMs))
  }

  private var summary: Summary? {
    switch kind {
    case .sleep:
      sleep.value.map { Summary(items: $0.sleeps, stats: [
        ("Sleep a day", Patterns.minutesPerDay($0.stats.avgSleepMinutesPerDay)),
        ("Sleeps a day", Patterns.sessionsPerDay($0.stats.avgSessionsPerDay)),
      ], loggedDays: loggedDays($0.sleeps)) }
    case .feed:
      feedEvents.value.map { page in
        let totals = Patterns.feedTotals(page.page, days: days, rangeEndMs: rangeEndMs)
        return Summary(items: [], stats: [
          ("Feeds a day", Patterns.perDay(totals.feedsPerDay)),
          ("Bottle milk a day", totals.mlPerDay > 0 ? "\(jsNumber(jsRound(totals.mlPerDay))) ml" : "None logged"),
        ], loggedDays: totals.loggedDays, feedTotals: totals)
      }
    case .tummy:
      tummy.value.map { Summary(items: $0.tummies, stats: [
        ("Tummy time a day", Patterns.minutesPerDay($0.stats.avgTummyMinutesPerDay)),
        ("Sessions a day", Patterns.sessionsPerDay($0.stats.avgSessionsPerDay)),
      ], loggedDays: loggedDays($0.tummies)) }
    case .nappy:
      nappy.value.map { Summary(items: $0.nappies, stats: [
        ("Nappies a day", Patterns.sessionsPerDay($0.stats.avgSessionsPerDay)),
        ("Wees · poos", "\(jsNumber($0.stats.weeCount)) · \(jsNumber($0.stats.pooCount))"),
      ], loggedDays: loggedDays($0.nappies)) }
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
      CircleIconButton(systemImage: "plus", label: addLabel) { add() }
    } content: {
      ScreenTitle(title)
      HStack(spacing: 8) {
        ForEach(Patterns.ranges, id: \.self) { range in
          Button { days = range } label: {
            Text("\(range) days")
              .font(.app(.bold, 14))
              .foregroundStyle(days == range ? C.card : C.muted)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(days == range ? accent : C.card, in: Capsule())
          }
          .buttonStyle(PressScale())
          .accessibilityAddTraits(days == range ? .isSelected : [])
        }
      }

      if let summary {
        if summary.loggedDays == 0 {
          EmptyState(
            symbol: kindSymbol,
            tint: accent,
            title: empty.title,
            message: empty.message,
            actionLabel: addLabel,
            action: add
          )
        } else {
          HStack(alignment: .top, spacing: 10) {
            ForEach(summary.stats, id: \.0) { label, value in
              VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.app(.medium, 13)).foregroundStyle(statInk)
                Text(value).font(.app(.bold, 20)).foregroundStyle(C.ink).lineLimit(1).minimumScaleFactor(0.7)
              }
              .padding(14)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(soft, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
              .accessibilityElement(children: .combine)
            }
          }
          if let note = Patterns.sparseNote(loggedDays: summary.loggedDays, days: days) {
            Label(note, systemImage: "info.circle")
              .font(.app(.body, 14))
              .foregroundStyle(C.muted)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, 4)
          }
          if let totals = summary.feedTotals {
            FeedDaysChart(totals: totals, color: accent)
          } else {
            PatternChart(items: summary.items, days: days, rangeEndMs: rangeEndMs, barColor: accent)
          }
        }
      } else {
        LoadingView().frame(minHeight: 200)
      }

      if let eventKind {
        EventListView(babyId: babyId, kind: eventKind, window: Timeline.patternWindow(days: days, rangeEndMs: rangeEndMs))
          .id(days)
      }
    }
    .task(id: days) {
      switch kind {
      case .sleep: await sleep.bind(API.events.sleepPatterns(babyId: babyId, days: days, rangeEndMs: rangeEndMs), convex)
      case .feed: await feedEvents.bind(API.events.list(babyId: babyId, numItems: Self.feedEventLimit), convex)
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
  let items: [PatternItem]
  let days: Int
  let rangeEndMs: EpochMs
  let barColor: Color

  @State private var showChart = false

  private struct Bar: Identifiable {
    let id: String
    let day: String
    let startMin: Double
    let endMin: Double
  }

  var body: some View {
    let rows = Patterns.days(items, days: days, rangeEndMs: rangeEndMs)

    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        switchPill("Rows", selected: !showChart) { showChart = false }
        switchPill("Columns", selected: showChart) { showChart = true }
      }
      if showChart { chart(rows) } else { bars(rows) }
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
    }
    .buttonStyle(PressScale())
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func bars(_ rows: [PatternDay]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Each row is one day, midnight to midnight")
        .font(.app(.medium, 12, relativeTo: .caption))
        .foregroundStyle(C.muted)
        .padding(.bottom, 2)
      ForEach(rows) { row in
        HStack(spacing: 8) {
          Text(row.label).font(.app(.bold, 12)).foregroundStyle(C.ink).frame(width: 58, alignment: .leading)
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
        .accessibilityValue(row.slices.isEmpty ? "Nothing logged" : "\(row.slices.count) logged")
      }
      HStack(spacing: 0) {
        Color.clear.frame(width: 66)
        GeometryReader { geo in
          ForEach([("12am", 0.0), ("6am", 0.25), ("12pm", 0.5), ("6pm", 0.75)], id: \.0) { label, at in
            Text(label).font(.app(.medium, 10)).foregroundStyle(C.muted).offset(x: geo.size.width * at)
          }
        }
        .frame(height: 16)
      }
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
    }
    .chartXScale(domain: labels)
    // Minutes are negated so midnight sits at the top, like the RN chart.
    .chartYScale(domain: -1440...0)
    .chartYAxisLabel("Time of day", position: .leading)
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
    .frame(height: 320)
    .padding(8)
    .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
  }
}

/// Feeds per day as bars, with each day's feeds and bottle millilitres listed underneath.
struct FeedDaysChart: View {
  let totals: FeedTotals
  let color: Color

  var body: some View {
    let labels = totals.days.map(\.label)
    let every = totals.days.count > 7 ? 2 : 1
    let logged = totals.days.filter { $0.feeds > 0 }.reversed()

    VStack(alignment: .leading, spacing: 14) {
      Text("Feeds each day").font(.app(.bold, 16)).foregroundStyle(C.ink)
      Chart(totals.days) { day in
        BarMark(x: .value("Day", day.label), y: .value("Feeds", day.feeds), width: .ratio(0.6))
          .foregroundStyle(color)
          .clipShape(RoundedRectangle(cornerRadius: 6))
          .annotation(position: .top, spacing: 4) {
            if day.feeds > 0 {
              Text("\(day.feeds)").font(.app(.bold, 11)).foregroundStyle(C.ink)
            }
          }
      }
      .chartXScale(domain: labels)
      .chartYAxisLabel("Feeds", position: .leading)
      .chartYAxis {
        AxisMarks(position: .leading) { _ in
          AxisGridLine().foregroundStyle(C.line)
          AxisValueLabel().font(.app(.medium, 10)).foregroundStyle(C.muted)
        }
      }
      .chartXAxis {
        AxisMarks(values: labels.enumerated().filter { $0.offset % every == 0 }.map(\.element)) { value in
          AxisValueLabel {
            if let label = value.as(String.self) {
              Text(label).font(.app(.bold, every > 1 ? 9 : 11)).foregroundStyle(C.ink)
            }
          }
        }
      }
      .frame(height: 200)
      .accessibilityLabel("Feeds each day")
      .accessibilityValue(logged.map { "\($0.label): \($0.feeds)" }.joined(separator: ", "))

      VStack(spacing: 0) {
        ForEach(Array(logged)) { day in
          HStack {
            Text(day.label).font(.app(.bold, 14)).foregroundStyle(C.ink)
            Spacer()
            Text(day.feeds == 1 ? "1 feed" : "\(day.feeds) feeds").font(.app(.medium, 14)).foregroundStyle(C.muted)
            Text(day.ml > 0 ? "\(jsNumber(jsRound(day.ml))) ml" : "No bottles")
              .font(.app(.bold, 14))
              .foregroundStyle(day.ml > 0 ? C.ink : C.muted)
              .frame(minWidth: 84, alignment: .trailing)
          }
          .padding(.vertical, 10)
          .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
          .accessibilityElement(children: .combine)
        }
      }
    }
    .padding(16)
    .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
  }
}
