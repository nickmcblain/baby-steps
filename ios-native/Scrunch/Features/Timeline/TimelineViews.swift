import ScrunchCore
import SwiftUI

/// Port of app/(app)/(tabs)/timeline.tsx.
struct TimelineTab: View {
  @Environment(ConvexService.self) private var convex
  @Environment(AppRouter.self) private var router
  @Environment(ActiveBabyStore.self) private var activeBaby
  @State private var babies = Live<[Baby]>()

  var body: some View {
    Group {
      if let list = babies.value {
        if let id = activeBaby.babyId, list.contains(where: { $0.id == id }) {
          TimelineView(babyId: id, showsBack: false).id(id)
        } else {
          ScreenScaffold(showsBack: false, clearDock: true) {
            Text("Timeline").font(.app(.displayBold, 28)).foregroundStyle(C.ink)
            Text("Pick a kid first.").font(.app(.body, 16)).foregroundStyle(C.muted)
            Button { router.tab = .kids } label: {
              Text("Go to Kids")
                .font(.app(.bold, 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(C.ink, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(PressScale())
          }
        }
      } else {
        ScreenScaffold(showsBack: false, clearDock: true) {
          Text("Loading…").font(.app(.body, 16)).foregroundStyle(C.muted)
        }
      }
    }
    .task { await babies.bind(API.babies.list(), convex) }
  }
}

/// Port of `TimelineView` in app/(app)/baby/[id]/log.tsx.
struct TimelineView: View {
  let babyId: BabyID
  var showsBack = true

  @Environment(ConvexService.self) private var convex
  @State private var mode: Mode = .list
  @State private var weekStartMs = WeekGrid.startOfWeekMonday(Date().epochMs)
  @State private var week = Live<WeekGridData>()

  enum Mode { case list, week }

  var body: some View {
    ScreenScaffold(showsBack: showsBack, clearDock: !showsBack, scrolls: mode == .list) {
      HStack(spacing: 12) {
        ScreenTitle("Timeline")
        Spacer()
        HStack(spacing: 8) {
          modePill("List", .list)
          modePill("Week", .week)
        }
      }

      switch mode {
      case .list:
        EventListView(babyId: babyId, emptyText: "Nothing yet. Log care, or tap + to add a midwife visit or jab date.")
      case .week:
        if let grid = week.value {
          WeekRhythmChart(
            data: grid,
            onPrevWeek: { weekStartMs = WeekGrid.addDays(weekStartMs, -7) },
            onNextWeek: { weekStartMs = WeekGrid.addDays(weekStartMs, 7) }
          )
        } else {
          Text("Loading week…").font(.app(.body, 15)).foregroundStyle(C.muted)
        }
      }
    }
    .task(id: mode == .week ? weekStartMs : nil) {
      guard mode == .week else { return }
      await week.bind(API.events.weekGrid(babyId: babyId, weekStartMs: weekStartMs), convex)
    }
  }

  private func modePill(_ label: String, _ value: Mode) -> some View {
    Button { mode = value } label: {
      Text(label)
        .font(.app(.bold, 14))
        .foregroundStyle(mode == value ? C.card : C.muted)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(mode == value ? C.ink : C.card, in: Capsule())
    }
    .buttonStyle(PressScale())
    .accessibilityAddTraits(mode == value ? .isSelected : [])
  }
}

// MARK: - Event list

extension EventKind {
  var tint: Color {
    switch self {
    case .feed, .pump: C.tealSoft
    case .nappy, .potty: C.peachSoft
    case .weight, .medicine: C.amberSoft
    case .height, .tummy: C.skySoft
    case .sleep, .activity: C.purpleSoft
    case .custom: C.roseSoft
    }
  }

  var ink: Color {
    switch self {
    case .feed, .pump: C.tealDark
    case .nappy, .potty: C.peach
    case .weight, .medicine: C.amber
    case .height, .tummy: C.sky
    case .sleep, .activity: C.purple
    case .custom: C.rose
    }
  }
}

/// Port of components/EventList.tsx. Paging re-subscribes with a larger page, which the
/// RN `usePaginatedQuery(…).loadMore(20)` amounts to for a single list.
struct EventListView: View {
  let babyId: BabyID
  var kind: EventKind? = nil
  var window: (startMs: EpochMs, endMs: EpochMs)? = nil
  var emptyText: String? = nil

  @Environment(ConvexService.self) private var convex
  @State private var page = Live<EventPage>()
  @State private var numItems: Int?
  @State private var pendingDelete: Event?

  private var pageSize: Int {
    numItems ?? (kind != nil || window != nil ? Timeline.filteredPageSize : Timeline.initialPageSize)
  }

  var body: some View {
    let now = Date().epochMs
    let events = Timeline.filter(page.value?.page ?? [], kind: kind, window: window)

    VStack(alignment: .leading, spacing: 16) {
      ForEach(Timeline.sections(events, now: now)) { section in
        VStack(alignment: .leading, spacing: 12) {
          Text(section.label.uppercased())
            .font(.app(.bold, 13))
            .tracking(0.7)
            .foregroundStyle(C.tealDark)
            .accessibilityAddTraits(.isHeader)
          VStack(spacing: 0) {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, event in
              row(event, now: now, last: index == section.items.count - 1)
            }
          }
        }
      }

      if page.value?.isDone == false {
        Button { numItems = pageSize + Timeline.loadMoreStep } label: {
          Text("Load older")
            .font(.app(.bold, 15))
            .foregroundStyle(C.tealDark)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(C.card, in: Capsule())
        }
        .buttonStyle(PressScale())
      }

      if page.value != nil, events.isEmpty, let emptyText {
        Text(emptyText).font(.app(.body, 15)).foregroundStyle(C.muted).lineSpacing(4)
      }
    }
    .task(id: pageSize) { await page.bind(API.events.list(babyId: babyId, numItems: pageSize), convex) }
    .sheet(item: $pendingDelete) { event in
      DeleteEventSheet(event: event) { pendingDelete = nil }
    }
  }

  private func row(_ event: Event, now: EpochMs, last: Bool) -> some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(spacing: 4) {
        Circle().fill(event.kind.ink).frame(width: 12, height: 12).padding(.top, 18)
        if !last {
          Rectangle().fill(C.line).frame(width: 2).frame(maxHeight: .infinity)
        }
      }
      .frame(width: 18)

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(EventCopy.kindLabel(event, now: now).uppercased())
            .font(.app(.bold, 12))
            .tracking(0.6)
            .foregroundStyle(event.kind.ink)
          Spacer()
          Text(LoggedAt.format(event.loggedAt).components(separatedBy: " · ").last ?? "")
            .font(.app(.medium, 13))
            .foregroundStyle(C.muted)
        }
        Text(EventCopy.title(event)).font(.app(.bold, 17)).foregroundStyle(C.ink)
        if let note = event.note, !note.isEmpty {
          Text(note).font(.app(.body, 15)).foregroundStyle(C.ink.opacity(0.75)).padding(.top, 2)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(event.kind.tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      .padding(.bottom, 12)
      .contentShape(Rectangle())
      .onLongPressGesture(minimumDuration: 0.38) { pendingDelete = event }
      .sensoryFeedback(.impact(weight: .light), trigger: pendingDelete?.id == event.id)
      .accessibilityElement(children: .combine)
      .accessibilityHint("Press and hold to delete")
      .accessibilityAction(named: "Delete") { pendingDelete = event }
    }
    .frame(minHeight: 72)
  }
}

private struct DeleteEventSheet: View {
  let event: Event
  let onClose: () -> Void

  @Environment(ConvexService.self) private var convex
  @State private var deleting = false
  @State private var alert: FormAlert?
  @State private var deletedTick = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(EventCopy.kindLabel(event, now: Date().epochMs).uppercased())
        .font(.app(.bold, 12)).tracking(0.6).foregroundStyle(C.muted)
      Text(EventCopy.title(event)).font(.app(.bold, 20)).foregroundStyle(C.ink)
      Text(LoggedAt.format(event.loggedAt)).font(.app(.body, 15)).foregroundStyle(C.muted)
      Text("This can’t be undone.").font(.app(.body, 14)).foregroundStyle(C.muted).padding(.top, 4).padding(.bottom, 8)
      Button { Task { await confirm() } } label: {
        Text(deleting ? "Deleting…" : "Delete")
          .font(.app(.bold, 17))
          .foregroundStyle(C.onAccent)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(C.danger, in: Capsule())
          .opacity(deleting ? 0.45 : 1)
      }
      .buttonStyle(PressScale())
      .disabled(deleting)
      Button(action: onClose) {
        Text("Cancel").font(.app(.bold, 16)).foregroundStyle(C.muted).frame(maxWidth: .infinity).padding(.vertical, 12)
      }
      .disabled(deleting)
    }
    .padding(.horizontal, 20)
    .padding(.top, 28)
    .sensoryFeedback(.impact(weight: .medium), trigger: deletedTick)
    .interactiveDismissDisabled(deleting)
    .presentationDetents([.height(330)])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(32)
    .presentationBackground(C.bg)
    .formAlert($alert)
  }

  private func confirm() async {
    guard !deleting else { return }
    deleting = true
    deletedTick += 1
    defer { deleting = false }
    do {
      try await convex.mutation(API.events.remove(event.id))
      onClose()
    } catch {
      alert = FormAlert(title: "Couldn’t delete", message: UserMessage.from(error, fallback: "Try again"))
    }
  }
}

// MARK: - Week chart

/// Port of components/WeekRhythmChart.tsx, drawn with Canvas.
struct WeekRhythmChart: View {
  let data: WeekGridData
  let onPrevWeek: () -> Void
  let onNextWeek: () -> Void

  private static let pad = (top: 22.0, right: 10.0, bottom: 12.0, left: 36.0)
  private static let hourTicks = [0, 3, 6, 9, 12, 15, 18, 21, 24]
  private static let dotRadius = 6.5

  private static func markerColor(_ kind: WeekMarkerKind) -> Color {
    switch kind {
    case .feed: C.teal
    case .nappy, .potty: C.peach
    case .weight, .medicine: C.amber
    case .height: C.sky
    case .custom: C.rose
    case .pump: C.tealDark
    case .activity: C.purple
    }
  }

  /// Small x-offsets so same-minute markers of different kinds stay readable.
  private static func kindOffset(_ kind: WeekMarkerKind) -> Double {
    switch kind {
    case .feed: -3
    case .nappy: 3
    case .weight: -6
    case .height: 6
    case .custom: 0
    case .pump: -4
    case .medicine: 4
    case .potty: -7
    case .activity: 7
    }
  }

  private static let legend: [(String, Color, Bool)] = [
    ("Sleep", C.purple, true), ("Tummy", C.sky, true),
    ("Feed", C.teal, false), ("Nappy", C.peach, false), ("Weight", C.amber, false),
    ("Height", C.sky, false), ("Event", C.rose, false), ("Pump", C.tealDark, false),
    ("Meds", C.amber, false), ("Potty", C.peach, false), ("Play", C.purple, false),
  ]

  var body: some View {
    let days = WeekGrid.weekDayLabels(data.weekStartMs)
    let thisWeek = WeekGrid.startOfWeekMonday(Date().epochMs) == data.weekStartMs

    VStack(spacing: 12) {
      HStack {
        Button(action: onPrevWeek) {
          Image(systemName: "chevron.left").font(.system(size: 20, weight: .bold)).foregroundStyle(C.ink).padding(8)
        }
        .accessibilityLabel("Previous week")
        Spacer()
        VStack(spacing: 2) {
          Text(thisWeek ? "This week" : "Week").font(.app(.bold, 17)).foregroundStyle(C.ink)
          Text(WeekGrid.formatWeekRange(data.weekStartMs)).font(.app(.body, 13)).foregroundStyle(C.muted)
        }
        Spacer()
        Button(action: onNextWeek) {
          Image(systemName: "chevron.right").font(.system(size: 20, weight: .bold)).foregroundStyle(C.ink).padding(8)
        }
        .accessibilityLabel("Next week")
      }

      FlowLegend(items: Self.legend)

      Canvas { context, size in
        draw(context: context, size: size, days: days)
      }
      .frame(maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)
      .background(C.card)
      .padding(.horizontal, -20)
      .padding(.bottom, -20)
      .accessibilityLabel("Week chart of sleep, tummy time and logged events")
    }
  }

  private func draw(context: GraphicsContext, size: CGSize, days: [WeekDayLabel]) {
    let pad = Self.pad
    let plotW = max(0, size.width - pad.left - pad.right)
    let plotH = max(0, size.height - pad.top - pad.bottom)
    guard plotW > 0, plotH > 0 else { return }
    let colW = plotW / Double(days.count)
    func y(_ min: Double) -> Double { pad.top + (min / 1440) * plotH }

    for (index, day) in days.enumerated() {
      context.draw(
        Text("\(day.label) \(day.dateNum)").font(.app(.bold, 11)).foregroundStyle(C.ink),
        at: CGPoint(x: pad.left + Double(index) * colW + colW / 2, y: 9)
      )
    }
    for hour in Self.hourTicks {
      let yy = y(Double(hour * 60))
      context.draw(
        Text(WeekGrid.formatHourLabel(hour)).font(.app(.medium, 10)).foregroundStyle(C.muted),
        at: CGPoint(x: pad.left - 4, y: yy),
        anchor: .trailing
      )
      context.fill(Path(CGRect(x: pad.left, y: yy, width: plotW, height: 1)), with: .color(C.line))
    }

    let blocks = data.sleeps.map { ($0, false) } + data.tummies.map { ($0, true) }
    for (block, isTummy) in blocks {
      for slice in WeekGrid.splitAcrossLocalDays(block.startMs, block.endMs) {
        guard let dayIndex = days.firstIndex(where: { $0.dayStartMs == slice.dayStartMs }) else { continue }
        let top = y(slice.startMin)
        let height = max(4, y(slice.endMin) - top)
        let inset = isTummy ? max(4, colW * 0.28) : max(2, colW * 0.12)
        let width = max(4, colW - inset * 2)
        let rect = CGRect(x: pad.left + Double(dayIndex) * colW + inset, y: top, width: width, height: height)
        context.fill(
          Path(roundedRect: rect, cornerRadius: min(6, width / 2)),
          with: .color((isTummy ? C.sky : C.purple).opacity(0.85))
        )
      }
    }

    for marker in data.markers {
      let dayStart = WeekGrid.startOfLocalDay(marker.atMs)
      guard let dayIndex = days.firstIndex(where: { $0.dayStartMs == dayStart }) else { continue }
      let cx = pad.left + Double(dayIndex) * colW + colW / 2 + Self.kindOffset(marker.kind)
      let cy = y(WeekGrid.minutesOfDay(marker.atMs))
      let r = Self.dotRadius
      context.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(Self.markerColor(marker.kind)))
    }
  }
}

/// Wrapping, centred legend row.
private struct FlowLegend: View {
  let items: [(String, Color, Bool)]

  var body: some View {
    WrapLayout(spacing: 10, rowSpacing: 6, centered: true) {
      ForEach(items, id: \.0) { label, color, bar in
        HStack(spacing: 5) {
          RoundedRectangle(cornerRadius: bar ? 4 : 6).fill(color).frame(width: bar ? 12 : 11, height: bar ? 12 : 11)
          Text(label).font(.app(.medium, 12)).foregroundStyle(C.muted)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .accessibilityHidden(true)
  }
}

/// Minimal flow layout (RN `flexWrap: "wrap"`).
struct WrapLayout: Layout {
  var spacing: CGFloat = 8
  var rowSpacing: CGFloat = 8
  var centered = false

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
    let height = rows.reduce(0) { $0 + $1.height } + rowSpacing * CGFloat(max(0, rows.count - 1))
    return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in rows(width: bounds.width, subviews: subviews) {
      var x = bounds.minX + (centered ? (bounds.width - row.width) / 2 : 0)
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
        x += size.width + spacing
      }
      y += row.height + rowSpacing
    }
  }

  private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

  private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = [Row()]
    for (index, subview) in subviews.enumerated() {
      let size = subview.sizeThatFits(.unspecified)
      let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
      if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
        rows.append(Row())
      }
      let added = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
      rows[rows.count - 1].indices.append(index)
      rows[rows.count - 1].width += added
      rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
    }
    return rows
  }
}
