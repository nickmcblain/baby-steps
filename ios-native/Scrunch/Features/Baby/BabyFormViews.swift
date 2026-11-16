import ScrunchCore
import SwiftUI

/// Simple OK alert used by the forms (RN `Alert.alert(title, message?)`).
struct FormAlert: Identifiable {
  let id = UUID()
  let title: String
  var message: String?
  var onDismiss: (() -> Void)?

  init(title: String.LocalizationValue, message: String? = nil, onDismiss: (() -> Void)? = nil) {
    self.init(verbatimTitle: String(localized: title), message: message, onDismiss: onDismiss)
  }

  init(verbatimTitle: String, message: String? = nil, onDismiss: (() -> Void)? = nil) {
    title = verbatimTitle
    self.message = message
    self.onDismiss = onDismiss
  }
}

extension View {
  func formAlert(_ alert: Binding<FormAlert?>) -> some View {
    let current = alert.wrappedValue
    return self.alert(current?.title ?? "", isPresented: Binding(
      get: { alert.wrappedValue != nil },
      set: { if !$0 { alert.wrappedValue = nil } }
    )) {
      Button("OK", role: .cancel) { current?.onDismiss?() }
    } message: {
      if let message = alert.wrappedValue?.message { Text(message) }
    }
  }
}

/// Port of app/(app)/babies/new.tsx.
struct NewBabyView: View {
  @Environment(ConvexService.self) private var convex
  @Environment(SaveFeedback.self) private var saveFeedback
  @Environment(AppRouter.self) private var router
  @Environment(ActiveBabyStore.self) private var activeBaby

  @State private var name = ""
  @State private var dateOfBirth: EpochMs?
  @State private var sex: Sex?
  @State private var weightGrams: Double?
  @State private var heightCm: Double?
  @State private var notes = ""
  @State private var careConsent = false
  @State private var alert: FormAlert?

  var body: some View {
    ScreenScaffold {
      ScreenTitle("New baby")
      FormField(label: "Name", text: $name, placeholder: "e.g. Nico")
      DateOfBirthField(value: $dateOfBirth)
      ToggleRow(label: "Sex (for UK growth charts)", options: [(Sex.boy, "Boy"), (Sex.girl, "Girl")], selection: $sex)
      WeightField(grams: $weightGrams)
      HeightField(cm: $heightCm)
      FormField(label: "Notes (optional)", text: $notes, placeholder: "e.g. Prefers left side first")

      Button { careConsent.toggle() } label: {
        HStack(alignment: .top, spacing: 12) {
          ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(careConsent ? C.teal : C.card)
              .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(careConsent ? C.teal : C.tealDark, lineWidth: 2))
            if careConsent {
              Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            }
          }
          .frame(width: 24, height: 24)
          .padding(.top, 2)
          Text("I am a parent or guardian and I consent to Scrunch storing this baby's care details (such as name, date of birth, growth, and logs) so the app can work. Scrunch is not a medical or healthcare service.")
            .font(.app(.body, 14))
            .foregroundStyle(C.ink)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 4)
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(careConsent ? [.isToggle, .isSelected] : .isToggle)
      .accessibilityInputLabels(["Consent", "I consent", "Checkbox"])

      PrimaryButton(label: "Save baby", disabled: !careConsent) { await save() }
    }
    .formAlert($alert)
  }

  private func save() async {
    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return alert = FormAlert(title: "Add a name") }
    guard let dateOfBirth else { return alert = FormAlert(title: "Pick a date of birth") }
    guard let weightGrams else { return alert = FormAlert(title: "Pick a weight") }
    guard careConsent else {
      return alert = FormAlert(title: "One more thing", message: String(localized: "Tick the box so Scrunch can keep these details safe for you."))
    }
    let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      let id = try await convex.mutation(API.babies.create(
        name: name,
        dateOfBirth: dateOfBirth,
        weightGrams: weightGrams,
        heightCm: heightCm,
        sex: sex,
        notes: trimmedNotes.isEmpty ? nil : trimmedNotes
      ))
      activeBaby.select(id)
      saveFeedback.show("Welcome, \(name.trimmingCharacters(in: .whitespaces))")
      router.popToRoot(tab: .home)
    } catch {
      alert = FormAlert(title: "That didn’t save", message: UserMessage.from(error, fallback: String(localized: "Try again")))
    }
  }
}

/// Port of app/(app)/baby/[id]/edit.tsx.
struct EditBabyView: View {
  let babyId: BabyID

  @Environment(ConvexService.self) private var convex
  @Environment(SaveFeedback.self) private var saveFeedback
  @Environment(\.dismiss) private var dismiss
  @State private var baby = Live<Baby>()
  @State private var dash = Live<Dashboard>()
  @State private var loaded = false

  @State private var name = ""
  @State private var dateOfBirth: EpochMs?
  @State private var sex: Sex?
  @State private var notes = ""
  @State private var deliveryType: DeliveryType?
  @State private var gestation = ""
  @State private var feedingMode: FeedingMode?
  @State private var alert: FormAlert?

  var body: some View {
    ScreenScaffold {
      HeaderButton(label: "Save") { await save() }
    } content: {
      ScreenTitle("Edit baby")
      BabyPhotoField(babyId: babyId, name: name)
      FormField(label: "Name", text: $name)
      DateOfBirthField(value: $dateOfBirth)
      ToggleRow(label: "Sex (for UK growth charts)", options: [(Sex.boy, "Boy"), (Sex.girl, "Girl")], selection: $sex)
      ToggleRow(label: "Delivery (optional)", options: [(DeliveryType.vaginal, "Vaginal"), (DeliveryType.cSection, "C-section")], selection: $deliveryType)
      FormField(label: "Gestation weeks (optional)", text: $gestation, placeholder: "e.g. 40", keyboard: .numberPad)
      ToggleRow(
        label: "Feeding (optional)",
        options: [(FeedingMode.breast, "Breast"), (FeedingMode.bottle, "Bottle"), (FeedingMode.mixed, "Mixed")],
        selection: $feedingMode
      )
      FormField(label: "Notes", text: $notes)
    }
    .formAlert($alert)
    .task { await baby.bind(API.babies.get(babyId), convex) }
    .task { await dash.bind(API.events.dashboard(babyId), convex) }
    .onChange(of: baby.value) { _, value in
      guard let value, !loaded else { return }
      loaded = true
      name = value.name
      dateOfBirth = value.dateOfBirth
      sex = value.sex
      notes = value.notes ?? ""
      deliveryType = value.deliveryType
      gestation = value.gestationWeeks.map(jsNumber) ?? ""
      feedingMode = value.feedingMode
    }
  }

  private func save() async {
    guard !name.trimmingCharacters(in: .whitespaces).isEmpty, let dateOfBirth else {
      return alert = FormAlert(title: "Check name and date of birth")
    }
    let trimmedGestation = gestation.trimmingCharacters(in: .whitespaces)
    var gestationWeeks: Double?
    if !trimmedGestation.isEmpty {
      guard let weeks = Double(trimmedGestation), weeks.isFinite, weeks >= 22, weeks <= 44 else {
        return alert = FormAlert(title: "Gestation weeks should be between 22 and 44")
      }
      gestationWeeks = weeks
    }
    let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      try await convex.mutation(API.babies.update(
        babyId: babyId,
        name: name,
        dateOfBirth: dateOfBirth,
        notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
        sex: sex,
        deliveryType: deliveryType,
        gestationWeeks: gestationWeeks,
        feedingMode: feedingMode
      ))
      saveFeedback.show("Changes saved")
      if let current = baby.value {
        let updated = Baby(
          id: babyId,
          name: name.trimmingCharacters(in: .whitespaces),
          dateOfBirth: dateOfBirth,
          weightGrams: current.weightGrams,
          feedingMode: feedingMode
        )
        await Reminders.refreshFeed(baby: updated, lastFeedAt: dash.value?.lastFeed.map(FeedWindows.feedEndedAt))
      }
      dismiss()
    } catch {
      alert = FormAlert(title: "That didn’t save", message: UserMessage.from(error, fallback: String(localized: "Try again")))
    }
  }
}
