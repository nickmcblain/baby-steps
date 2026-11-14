import ScrunchCore
import SwiftUI

/// Port of nappy/index.tsx and potty.tsx (same form, different mutation).
struct NappyView: View {
  let babyId: BabyID
  let potty: Bool

  @Environment(ConvexService.self) private var convex
  @Environment(LogGate.self) private var gate
  @Environment(\.dismiss) private var dismiss
  @State private var loggedAt = LoggedAt.nowSnapped()
  @State private var kind: NappyKind = .wee
  @State private var wee: NappySize = .medium
  @State private var poo: NappySize = .medium
  @State private var note = ""
  @State private var alert: FormAlert?

  var body: some View {
    ScreenScaffold {
      ScreenTitle(potty ? "Potty" : "Nappy")
      LoggedAtField(value: $loggedAt)
      HStack(spacing: 8) {
        Pill(label: "Wee", selected: kind == .wee, tint: C.amberSoft, ink: C.ink) { kind = .wee }
        Pill(label: "Poo", selected: kind == .poo, tint: C.peachSoft, ink: C.peach) { kind = .poo }
        Pill(label: "Both", selected: kind == .both) { kind = .both }
      }
      if kind != .poo {
        FieldLabel("Wee size")
        sizeRow($wee)
      }
      if kind != .wee {
        FieldLabel("Poo size")
        sizeRow($poo)
      }
      FormField(label: "Note", text: $note, placeholder: potty ? "Sat on their own" : "Seedy mustard")
      PrimaryButton(label: potty ? "Save potty" : "Save nappy") { await save() }
    }
    .formAlert($alert)
  }

  private func sizeRow(_ value: Binding<NappySize>) -> some View {
    HStack(spacing: 8) {
      Pill(label: "Small", selected: value.wrappedValue == .small) { value.wrappedValue = .small }
      Pill(label: "Medium", selected: value.wrappedValue == .medium) { value.wrappedValue = .medium }
      Pill(label: "Large", selected: value.wrappedValue == .large) { value.wrappedValue = .large }
    }
  }

  private func save() async {
    let weeSize = kind != .poo ? wee : nil
    let pooSize = kind != .wee ? poo : nil
    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let noteValue = trimmed.isEmpty ? nil : trimmed
    do {
      let saved = try await gate.save(potty ? LogType.potty : .nappy, babyId: babyId) {
        if potty {
          try await convex.mutation(API.events.logPotty(babyId: babyId, loggedAt: loggedAt, nappy: kind, weeSize: weeSize, pooSize: pooSize, note: noteValue))
        } else {
          try await convex.mutation(API.events.logNappy(babyId: babyId, loggedAt: loggedAt, nappy: kind, weeSize: weeSize, pooSize: pooSize, note: noteValue))
        }
      }
      guard saved != nil else { return }
      dismiss()
    } catch {
      alert = FormAlert(title: "Could not log", message: UserMessage.from(error, fallback: "Try again"))
    }
  }
}

/// Port of medicine.tsx.
struct MedicineView: View {
  let babyId: BabyID

  @Environment(ConvexService.self) private var convex
  @Environment(LogGate.self) private var gate
  @Environment(\.dismiss) private var dismiss
  @State private var baby = Live<Baby>()
  @State private var loggedAt = LoggedAt.nowSnapped()
  @State private var name = ""
  @State private var dose = ""
  @State private var remindHours: Int? = 4
  @State private var alert: FormAlert?

  var body: some View {
    ScreenScaffold {
      ScreenTitle("Medicine")
      LoggedAtField(value: $loggedAt)
      FormField(label: "Name", text: $name, placeholder: "Calpol")
      FormField(label: "Dose", text: $dose, placeholder: "2.5 ml")
      FieldLabel("Remind me")
      HStack(spacing: 8) {
        ForEach(ReminderPlans.medicineReminderHours.compactMap { $0 }, id: \.self) { hours in
          Pill(label: "\(hours)h", selected: remindHours == hours, tint: C.amberSoft, ink: C.ink) { remindHours = hours }
        }
        Pill(label: "Off", selected: remindHours == nil, tint: C.amberSoft, ink: C.ink) { remindHours = nil }
      }
      PrimaryButton(label: "Save medicine") { await save() }
    }
    .formAlert($alert)
    .task { await baby.bind(API.babies.get(babyId), convex) }
  }

  private func save() async {
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return alert = FormAlert(title: "Add a medicine name") }
    let trimmedDose = dose.trimmingCharacters(in: .whitespacesAndNewlines)
    let doseValue = trimmedDose.isEmpty ? nil : trimmedDose
    do {
      let saved = try await gate.save(.medicine, babyId: babyId) {
        try await convex.mutation(API.events.logMedicine(babyId: babyId, loggedAt: loggedAt, title: title, note: doseValue))
      }
      guard saved != nil else { return }
      if let remindHours, let baby = baby.value {
        let scheduled = await Reminders.scheduleMedicine(babyId: baby.id, babyName: baby.name, name: title, dose: doseValue, hours: remindHours)
        if !scheduled {
          let close = dismiss
          alert = FormAlert(title: "Logged, no reminder", message: "Allow notifications to get the next-dose nudge.", onDismiss: { close() })
          return
        }
      }
      dismiss()
    } catch {
      alert = FormAlert(title: "Could not log", message: UserMessage.from(error, fallback: "Try again"))
    }
  }
}

/// Port of activity.tsx.
struct ActivityLogView: View {
  let babyId: BabyID

  private static let presets = ["Bath", "Play", "Walk", "Other"]
  private static let quick = [5, 10, 15, 20, 30, 45]

  @Environment(ConvexService.self) private var convex
  @Environment(LogGate.self) private var gate
  @Environment(\.dismiss) private var dismiss
  @State private var loggedAt = LoggedAt.nowSnapped()
  @State private var preset = "Play"
  @State private var customTitle = ""
  @State private var minutes = ""
  @State private var note = ""
  @State private var alert: FormAlert?

  private var title: String {
    preset == "Other" ? customTitle.trimmingCharacters(in: .whitespacesAndNewlines) : preset
  }

  var body: some View {
    ScreenScaffold {
      ScreenTitle("Activity")
      LoggedAtField(value: $loggedAt)
      SectionLabel("Type")
      WrapLayout {
        ForEach(Self.presets, id: \.self) { item in
          Pill(label: item, selected: preset == item, tint: C.purpleSoft, ink: C.purple) { preset = item }
        }
      }
      if preset == "Other" {
        FormField(label: "Title", text: $customTitle, placeholder: "Swimming")
      }
      SectionLabel("Duration")
      WrapLayout {
        ForEach(Self.quick, id: \.self) { m in
          Pill(label: "\(m)m", selected: Double(minutes) == Double(m), tint: C.purpleSoft, ink: C.purple) { minutes = String(m) }
        }
      }
      FormField(label: "Minutes", text: $minutes, placeholder: "Optional", keyboard: .numberPad)
      FormField(label: "Note", text: $note, placeholder: "Loved the water")
      PrimaryButton(label: "Save activity") { await save() }
    }
    .formAlert($alert)
  }

  private func save() async {
    guard !title.isEmpty else { return alert = FormAlert(title: "Pick an activity") }
    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      let saved = try await gate.save(.activity, babyId: babyId) {
        try await convex.mutation(API.events.logActivity(
          babyId: babyId,
          loggedAt: loggedAt,
          title: title,
          durationMinutes: minutes.isEmpty ? nil : Double(minutes.trimmingCharacters(in: .whitespaces)),
          note: trimmed.isEmpty ? nil : trimmed
        ))
      }
      guard saved != nil else { return }
      dismiss()
    } catch {
      alert = FormAlert(title: "Could not log", message: UserMessage.from(error, fallback: "Try again"))
    }
  }
}

/// Port of event.tsx (appointments; future dates allowed).
struct CustomEventView: View {
  let babyId: BabyID

  private static let presets = ["Midwife visit", "GP visit", "Immunisation", "Health visitor", "Other"]

  @Environment(ConvexService.self) private var convex
  @Environment(LogGate.self) private var gate
  @Environment(\.dismiss) private var dismiss
  @State private var loggedAt = LoggedAt.nowSnapped()
  @State private var preset = "Midwife visit"
  @State private var customTitle = ""
  @State private var note = ""
  @State private var alert: FormAlert?

  private var title: String {
    preset == "Other" ? customTitle.trimmingCharacters(in: .whitespacesAndNewlines) : preset
  }

  var body: some View {
    ScreenScaffold {
      ScreenTitle("Add event")
      Hint("Midwife, GP, jabs, and other appointments — past or upcoming.")
      FieldLabel("Type")
      WrapLayout {
        ForEach(Self.presets, id: \.self) { item in
          Pill(label: item, selected: preset == item, tint: C.roseSoft, ink: C.rose) { preset = item }
        }
      }
      if preset == "Other" {
        FormField(label: "Title", text: $customTitle, placeholder: "Hearing test")
      }
      LoggedAtField(value: $loggedAt, label: "When", allowFuture: true)
      FormField(label: "Note", text: $note, placeholder: "Bring red book")
      PrimaryButton(label: "Save event") { await save() }
    }
    .formAlert($alert)
  }

  private func save() async {
    guard !title.isEmpty else { return alert = FormAlert(title: "Add a title") }
    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      let saved = try await gate.save(.note, babyId: babyId) {
        try await convex.mutation(API.events.logCustom(babyId: babyId, loggedAt: loggedAt, title: title, note: trimmed.isEmpty ? nil : trimmed))
      }
      guard saved != nil else { return }
      dismiss()
    } catch {
      alert = FormAlert(title: "Could not save", message: UserMessage.from(error, fallback: "Try again"))
    }
  }
}
