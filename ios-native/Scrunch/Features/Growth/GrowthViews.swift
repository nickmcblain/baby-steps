import Accessibility
import Charts
import ScrunchCore
import SwiftUI

/// Port of weight.tsx / height.tsx.
struct GrowthLogView: View {
  let babyId: BabyID
  let metric: GrowthMetric

  @Environment(ConvexService.self) private var convex
  @Environment(SaveFeedback.self) private var saveFeedback
  @Environment(AppRouter.self) private var router
  @Environment(LogGate.self) private var gate
  @Environment(\.dismiss) private var dismiss
  @State private var series = Live<GrowthSeries>()
  @State private var dash = Live<Dashboard>()
  @State private var loggedAt = LoggedAt.nowSnapped()
  @State private var grams: Double?
  @State private var cm: Double?
  @State private var note = ""
  @State private var alert: FormAlert?

  private var isWeight: Bool { metric == .weight }

  var body: some View {
    ScreenScaffold {
      ScreenTitle(isWeight ? "Weigh-in" : "Height")
      if let series = series.value {
        GrowthChart(metric: metric, sex: series.baby.sex, dateOfBirth: series.baby.dateOfBirth, points: series.points)
        if series.baby.sex == nil {
          Button { router.push(babyId, .edit) } label: {
            Text("Add boy / girl on Edit →").font(.app(.medium, 14)).foregroundStyle(C.tealDark).frame(minHeight: 44)
          }
          .accessibilityLabel("Add boy or girl on Edit")
        }
      } else {
        Text("Loading chart…").font(.app(.body, 15)).foregroundStyle(C.muted)
      }
      LoggedAtField(value: $loggedAt)
      if isWeight {
        WeightField(grams: $grams)
      } else {
        HeightField(cm: $cm)
      }
      FormField(label: "Note", text: $note, placeholder: isWeight ? "After bath" : "Clinic visit")
      PrimaryButton(label: isWeight ? "Save weigh-in" : "Save height") { await save() }
    }
    .formAlert($alert)
    .task { await series.bind(API.events.growthSeries(babyId: babyId, kind: isWeight ? .weight : .height), convex) }
    .task { if isWeight { await dash.bind(API.events.dashboard(babyId), convex) } }
    .onChange(of: series.value?.baby) { _, baby in
      guard let baby else { return }
      if isWeight, grams == nil { grams = baby.weightGrams }
      if !isWeight, cm == nil, let heightCm = baby.heightCm { cm = heightCm }
    }
  }

  private func save() async {
    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let noteValue = trimmed.isEmpty ? nil : trimmed
    do {
      if isWeight {
        guard let grams, grams > 0 else { return alert = FormAlert(title: "Pick a weight") }
        let saved = try await gate.save(.growth, babyId: babyId) {
          try await convex.log(API.events.logWeight(babyId: babyId, loggedAt: loggedAt, weightGrams: grams, note: noteValue))
        }
        guard saved != nil else { return }
        if let baby = series.value?.baby {
          let updated = Baby(id: baby.id, name: baby.name, dateOfBirth: baby.dateOfBirth, weightGrams: grams, feedingMode: baby.feedingMode)
          await Reminders.refreshFeed(baby: updated, lastFeedAt: dash.value?.lastFeed.map(FeedWindows.feedEndedAt))
        }
      } else {
        guard let cm, cm > 0 else { return alert = FormAlert(title: "Pick a height") }
        let saved = try await gate.save(.growth, babyId: babyId) {
          try await convex.log(API.events.logHeight(babyId: babyId, loggedAt: loggedAt, heightCm: cm, note: noteValue))
        }
        guard saved != nil else { return }
      }
      saveFeedback.logged(isWeight ? .weight : .height, babyId: babyId)
      dismiss()
    } catch {
      alert = FormAlert(title: "That didn’t save", message: UserMessage.from(error, fallback: String(localized: "Try again")))
    }
  }
}

/// Port of components/GrowthChart.tsx using Swift Charts.
struct GrowthChart: View {
  let metric: GrowthMetric
  let sex: Sex?
  let dateOfBirth: EpochMs
  let points: [GrowthPoint]

  private struct CentilePoint: Identifiable {
    let centile: String
    let month: Double
    let value: Double
    var id: String { "\(centile)-\(month)" }
  }

  private struct LogPoint: Identifiable {
    let index: Int
    let month: Double
    let value: Double
    var id: Int { index }
  }

  var body: some View {
    let now = Date().epochMs
    let maxMonth = GrowthLMS.maxChartMonths(dateOfBirth: dateOfBirth, now: now)

    VStack(alignment: .leading, spacing: 6) {
      Text(metric == .weight ? "Weight for age" : "Length / height for age")
        .font(.app(.display, 18)).foregroundStyle(C.ink)
        .accessibilityAddTraits(.isHeader)
      Text(HealthRegion.current.growthChartSource)
        .font(.app(.body, 12)).foregroundStyle(C.muted).padding(.bottom, 4)

      if let sex {
        let latest = points.max { $0.at < $1.at }
        let status = latest.flatMap { GrowthLMS.latestStatus(metric, sex: sex, dateOfBirth: dateOfBirth, latest: $0) }
        if let status {
          Text(status.text).font(.app(.medium, 14)).foregroundStyle(C.tealDark).padding(.bottom, 4)
        }
        chart(sex: sex, maxMonth: maxMonth)
        VStack(alignment: .leading, spacing: 2) {
          Text("Lines: 0.4 · 9 · 50 · 91 · 99.6")
          Text("Dots: your logs (\(metric == .weight ? "kg" : "cm"))")
        }
        .font(.app(.body, 12, relativeTo: .caption))
        .foregroundStyle(C.muted)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 4)
        if let band = status?.band, band == .veryLow || band == .veryHigh {
          Text(GrowthLMS.outsideRangeCaution).font(.app(.medium, 12)).foregroundStyle(C.danger).padding(.top, 6)
        }
      } else {
        Text("Set boy or girl on Edit profile to plot against UK charts.")
          .font(.app(.body, 14)).foregroundStyle(C.muted).padding(.vertical, 12)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(C.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    .cardShadow()
  }

  private func chart(sex: Sex, maxMonth: Double) -> some View {
    let steps = max(24, Int(jsRound(maxMonth * 4)))
    let centiles: [CentilePoint] = GrowthLMS.chartCentiles.flatMap { centile in
      (0...steps).compactMap { i -> CentilePoint? in
        let month = Double(i) / Double(steps) * maxMonth
        guard let value = GrowthLMS.valueFromZ(metric, sex: sex, month: month, z: centile.z) else { return nil }
        return CentilePoint(centile: centile.label, month: month, value: value)
      }
    }
    let logs = points.enumerated()
      .map { LogPoint(index: $0.offset, month: GrowthLMS.ageMonths(dateOfBirth: dateOfBirth, at: $0.element.at), value: $0.element.value) }
      .filter { $0.month <= maxMonth + 0.05 }
      .sorted { $0.month < $1.month }

    let values = centiles.map(\.value) + logs.map(\.value)
    var low = values.min() ?? (metric == .weight ? 2 : 45)
    var high = values.max() ?? (metric == .weight ? 12 : 90)
    let pad = (high - low) * 0.08 == 0 ? 1 : (high - low) * 0.08
    low -= pad
    high += pad

    return Chart {
      ForEach(centiles) { point in
        if point.month == 0 {
          PointMark(x: .value("Month", point.month), y: .value("Birth centile", point.value))
            .symbolSize(12)
            .foregroundStyle(point.centile == "50th" ? C.ink : C.line)
        } else {
          LineMark(x: .value("Month", point.month), y: .value("Centile", point.value), series: .value("Centile", point.centile))
            .foregroundStyle(point.centile == "50th" ? C.ink : C.line)
            .lineStyle(StrokeStyle(lineWidth: point.centile == "50th" ? 2 : 1))
        }
      }
      if logs.count > 1 {
        ForEach(logs) { point in
          LineMark(x: .value("Month", min(point.month, maxMonth)), y: .value("Logged", point.value), series: .value("Series", "logs"))
            .foregroundStyle(C.teal.opacity(0.55))
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
      }
      ForEach(logs) { point in
        PointMark(x: .value("Month", min(point.month, maxMonth)), y: .value("Logged", point.value))
          .symbol {
            Circle().fill(C.teal).frame(width: 10, height: 10).overlay(Circle().stroke(.white, lineWidth: 2))
          }
      }
    }
    .chartXScale(domain: 0...maxMonth)
    .chartYScale(domain: low...high)
    .chartXAxis {
      AxisMarks(values: [0, 6, 12, 18, 24].map { Double($0) }.filter { $0 <= maxMonth }) { value in
        AxisValueLabel {
          if let month = value.as(Double.self) { Text("\(Int(month))m").font(.app(.body, 10)).foregroundStyle(C.muted) }
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
        AxisGridLine().foregroundStyle(C.line)
        AxisValueLabel {
          if let v = value.as(Double.self) {
            Text(metric == .weight ? jsToFixed(v, 1) : String(Int(jsRound(v)))).font(.app(.body, 10)).foregroundStyle(C.muted)
          }
        }
      }
    }
    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    .frame(height: 220)
    .accessibilityLabel(metric == .weight ? "Weight for age chart" : "Length for age chart")
    .accessibilityChartDescriptor(GrowthChartDescriptor(
      metric: metric,
      logs: logs.map { (month: $0.month, value: $0.value) },
      maxMonth: maxMonth,
      range: low...high,
      summary: points.max { $0.at < $1.at }.flatMap { GrowthLMS.latestStatus(metric, sex: sex, dateOfBirth: dateOfBirth, latest: $0) }?.text
    ))
  }
}

/// Audio graph of the logged growth points against age in months.
private struct GrowthChartDescriptor: AXChartDescriptorRepresentable {
  let metric: GrowthMetric
  let logs: [(month: Double, value: Double)]
  let maxMonth: Double
  let range: ClosedRange<Double>
  let summary: String?

  private var unit: String { metric == .weight ? "kg" : "cm" }

  func makeChartDescriptor() -> AXChartDescriptor {
    let xAxis = AXNumericDataAxisDescriptor(title: "Age", range: 0...max(1, maxMonth), gridlinePositions: []) {
      "\(jsToFixed($0, 1)) months"
    }
    let yAxis = AXNumericDataAxisDescriptor(title: metric == .weight ? "Weight" : "Length", range: range, gridlinePositions: []) {
      "\(jsToFixed($0, 1)) \(unit)"
    }
    let series = AXDataSeriesDescriptor(
      name: "Your logs",
      isContinuous: true,
      dataPoints: logs.map { AXDataPoint(x: $0.month, y: $0.value) }
    )
    let count = logs.count == 1 ? "1 log" : "\(logs.count) logs"
    return AXChartDescriptor(
      title: metric == .weight ? "Weight for age" : "Length for age",
      summary: [count + " plotted against UK-WHO centiles.", summary].compactMap { $0 }.joined(separator: " "),
      xAxis: xAxis,
      yAxis: yAxis,
      additionalAxes: [],
      series: [series]
    )
  }
}
