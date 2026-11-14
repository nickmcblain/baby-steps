import ScrunchCore
import SwiftUI

/// Optional "little firsts". No target ages, no reminders, no streaks: tap one when it
/// happens, or hide the card. Visibility is per device and can be turned back on in Profile.
struct MilestonesCard: View {
  static let visibleKey = "scrunch.milestones.visible"

  let baby: Baby

  @Environment(ConvexService.self) private var convex
  @Environment(SaveFeedback.self) private var saveFeedback
  @AppStorage(MilestonesCard.visibleKey) private var visible = true
  @State private var marks = Live<[MilestoneMark]>()
  @State private var editing: Milestone?

  var body: some View {
    if visible {
      Card(spacing: 10) {
        HStack(alignment: .firstTextBaseline) {
          Text("Little firsts")
            .font(.app(.display, 20, relativeTo: .headline))
            .foregroundStyle(C.ink)
            .accessibilityAddTraits(.isHeader)
          Spacer()
          Button("Hide") { visible = false }
            .font(.app(.medium, 14))
            .foregroundStyle(C.muted)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Hide little firsts")
        }
        Text("Tap one when it happens. Every baby has their own pace.")
          .font(.app(.body, 14))
          .foregroundStyle(C.muted)
        WrapLayout {
          ForEach(MilestoneCopy.rows(marks.value ?? []), id: \.milestone) { row in
            pill(row.milestone, reachedAt: row.reachedAt)
          }
        }
      }
      .task(id: baby.id) { await marks.bind(API.babies.milestones(baby.id), convex) }
      .sheet(item: $editing) { milestone in
        MilestoneSheet(
          baby: baby,
          milestone: milestone,
          reachedAt: MilestoneCopy.rows(marks.value ?? []).first { $0.milestone == milestone }?.reachedAt
        ) { editing = nil }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(C.bg)
      }
    }
  }

  private func pill(_ milestone: Milestone, reachedAt: EpochMs?) -> some View {
    Button { editing = milestone } label: {
      HStack(spacing: 6) {
        if reachedAt != nil {
          Image(systemName: "star.fill").font(.system(size: 11, weight: .bold)).accessibilityHidden(true)
        }
        Text(reachedAt.map { "\(milestone.title) · \(Self.day($0))" } ?? milestone.title)
          .font(.app(.bold, 14))
      }
      .foregroundStyle(reachedAt != nil ? C.rose : C.ink)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(reachedAt != nil ? C.roseSoft : C.bg, in: Capsule())
    }
    .buttonStyle(PressScale())
    .accessibilityValue(reachedAt.map { "Reached \(Self.day($0))" } ?? "")
  }

  static func day(_ ms: EpochMs) -> String {
    Date(epochMs: ms).formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "en_GB")))
  }
}

private struct MilestoneSheet: View {
  let baby: Baby
  let milestone: Milestone
  let reachedAt: EpochMs?
  let onDone: () -> Void

  @Environment(ConvexService.self) private var convex
  @Environment(SaveFeedback.self) private var saveFeedback
  @State private var date = Date()
  @State private var alert: FormAlert?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(milestone.title)
        .font(.app(.displayBold, 24))
        .foregroundStyle(C.ink)
      DatePicker("When", selection: $date, in: Date(epochMs: baby.dateOfBirth)...Date(), displayedComponents: .date)
        .font(.app(.medium, 16))
        .foregroundStyle(C.ink)
        .tint(C.teal)
      PrimaryButton(label: "Save") { await save() }
      if reachedAt != nil {
        Button { Task { await clear() } } label: {
          Text("Remove").font(.app(.medium, 15)).foregroundStyle(C.muted).frame(maxWidth: .infinity, minHeight: 44)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 28)
    .frame(maxHeight: .infinity, alignment: .top)
    .formAlert($alert)
    .onAppear { if let reachedAt { date = Date(epochMs: reachedAt) } }
  }

  private func save() async {
    // Midday, so the day survives a timezone change.
    let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    let at = min(noon.epochMs, Date().epochMs)
    do {
      try await convex.mutation(API.babies.setMilestone(babyId: baby.id, milestone: milestone, reachedAt: at))
      saveFeedback.show(MilestoneCopy.saved(milestone, babyName: baby.name))
      onDone()
    } catch {
      alert = FormAlert(title: "Could not save", message: UserMessage.from(error, fallback: "Try again"))
    }
  }

  private func clear() async {
    do {
      try await convex.mutation(API.babies.clearMilestone(babyId: baby.id, milestone: milestone))
      onDone()
    } catch {
      alert = FormAlert(title: "Could not remove", message: UserMessage.from(error, fallback: "Try again"))
    }
  }
}
