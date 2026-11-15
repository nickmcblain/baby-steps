import ScrunchCore
import SwiftUI

// Native replacements for DateOfBirthField, LoggedAtField, WeightField and HeightField.
// The hand-built RN WheelPicker (and its fast-scroll bug) is gone: these use
// SwiftUI DatePicker / Picker(.wheel).

/// Field-styled button that opens a picker sheet.
struct PickerTrigger: View {
  let label: LocalizedStringKey
  let value: String
  var placeholder = false
  let action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      FieldLabel(label)
      Button(action: action) {
        HStack {
          Text(value)
            .font(.app(.medium, 16))
            .foregroundStyle(placeholder ? C.muted : C.ink)
          Spacer()
          Image(systemName: "chevron.down")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(C.tealDark)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(C.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .cardShadow()
      }
      .buttonStyle(PressScale())
      .accessibilityLabel(label)
      .accessibilityValue(value)
    }
  }
}

/// Sheet chrome shared by the pickers: content plus a teal confirm button.
struct PickerSheet<Content: View>: View {
  let confirm: LocalizedStringKey
  let onConfirm: () -> Void
  @ViewBuilder var content: Content

  var body: some View {
    VStack(spacing: 16) {
      content
      Button(action: onConfirm) {
        Text(confirm)
          .font(.app(.bold, 16))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(C.teal, in: Capsule())
      }
      .buttonStyle(PressScale())
    }
    .padding(.horizontal, 20)
    .padding(.top, 28)
    .padding(.bottom, 12)
    .presentationDetents([.height(420)])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(32)
    .presentationBackground(C.bg)
  }
}

// MARK: - Date of birth (stored as UTC midnight)

struct DateOfBirthField: View {
  @Binding var value: EpochMs?

  @State private var open = false
  @State private var draft = Date()

  private static let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()

  private var range: ClosedRange<Date> {
    let today = Date()
    let year = Self.utc.component(.year, from: today)
    let earliest = Self.utc.date(from: DateComponents(year: year - 6, month: 1, day: 1)) ?? today
    return earliest...today
  }

  var body: some View {
    PickerTrigger(label: "Date of birth", value: value.map { Format.dob($0) } ?? String(localized: "Pick a date"), placeholder: value == nil) {
      draft = value.map { Date(epochMs: $0) } ?? Date()
      open = true
    }
    .sheet(isPresented: $open, onDismiss: apply) {
      PickerSheet(confirm: "Use this date", onConfirm: { open = false }) {
        DatePicker("Date of birth", selection: $draft, in: range, displayedComponents: .date)
          .datePickerStyle(.wheel)
          .labelsHidden()
          .environment(\.calendar, Self.utc)
          .environment(\.timeZone, Self.utc.timeZone)
      }
    }
  }

  private func apply() {
    let parts = Self.utc.dateComponents([.year, .month, .day], from: draft)
    value = Format.dobMs(year: parts.year ?? 2024, month: parts.month ?? 1, day: parts.day ?? 1)
  }
}

// MARK: - Logged at (local, snapped to the minute)

struct LoggedAtField: View {
  @Binding var value: EpochMs
  var label: LocalizedStringKey = "When"
  /// Allow dates ahead of now (appointments).
  var allowFuture = false

  @State private var open = false
  @State private var draft = Date()

  private var range: ClosedRange<Date> {
    let now = Date()
    let calendar = Calendar.current
    let year = calendar.component(.year, from: now)
    let earliest = calendar.date(from: DateComponents(year: year - 3, month: 1, day: 1)) ?? now
    let latest = allowFuture ? (calendar.date(from: DateComponents(year: year + 2, month: 12, day: 31, hour: 23, minute: 59)) ?? now) : now
    return earliest...latest
  }

  var body: some View {
    PickerTrigger(label: label, value: LoggedAt.format(value)) {
      draft = Date(epochMs: value)
      open = true
    }
    .sheet(isPresented: $open, onDismiss: apply) {
      PickerSheet(confirm: "Use this time", onConfirm: { open = false }) {
        DatePicker(label, selection: $draft, in: range, displayedComponents: [.date, .hourAndMinute])
          .datePickerStyle(.wheel)
          .labelsHidden()
      }
    }
  }

  private func apply() {
    value = LoggedAt.resolve(draft.epochMs, allowFuture: allowFuture)
  }
}

// MARK: - Weight

struct WeightField: View {
  @Binding var grams: Double?
  var label: LocalizedStringKey = "Weight"

  @State private var open = false
  @State private var unit = DisplayFormat.current.weightUnit
  @State private var kg = 3
  @State private var tenths = 4
  @State private var lb = 7
  @State private var oz = 8

  var body: some View {
    PickerTrigger(label: label, value: grams.map { Format.weight($0, unit: unit) } ?? String(localized: "Pick a weight"), placeholder: grams == nil) {
      load(grams, into: unit)
      open = true
    }
    .sheet(isPresented: $open, onDismiss: apply) {
      PickerSheet(confirm: "Use this weight", onConfirm: { open = false }) {
        HStack(spacing: 8) {
          Pill(label: "Kilograms", selected: unit == .kg) { switchUnit(.kg) }
          Pill(label: "Pounds & oz", selected: unit == .lb, tint: C.peachSoft, ink: C.peach) { switchUnit(.lb) }
        }
        HStack(spacing: 4) {
          if unit == .kg {
            wheel("Kilograms", $kg, Array(0...20)) { "\($0)" }
            unitGlyph("kg")
            wheel("Tenths", $tenths, Array(0...9)) { ".\($0)" }
          } else {
            wheel("Pounds", $lb, Array(0...44)) { "\($0)" }
            unitGlyph("lb")
            wheel("Ounces", $oz, Array(0...15)) { "\($0)" }
            unitGlyph("oz")
          }
        }
        .frame(height: 216)
      }
    }
  }

  private var current: Double {
    unit == .kg ? Format.kgPartsToGrams(kg: kg, tenths: tenths) : Format.lbOzToGrams(lb: lb, oz: oz)
  }

  private func load(_ grams: Double?, into unit: WeightUnit) {
    let g = (grams ?? 0) > 0 ? grams! : 3400
    if unit == .kg {
      let parts = Format.gramsToKgParts(g)
      kg = min(20, parts.kg)
      tenths = parts.tenths
    } else {
      let parts = Format.gramsToLbOz(g)
      lb = min(44, parts.lb)
      oz = parts.oz
    }
  }

  private func switchUnit(_ next: WeightUnit) {
    guard next != unit else { return }
    let g = current
    unit = next
    load(g, into: next)
  }

  private func apply() {
    let g = current
    if g > 0 { grams = g }
  }
}

// MARK: - Height

struct HeightField: View {
  @Binding var cm: Double?
  var label: LocalizedStringKey = "Height (optional)"

  @State private var open = false
  @State private var unit = DisplayFormat.current.heightUnit
  @State private var whole = 50
  @State private var tenths = 0
  @State private var ft = 1
  @State private var inch = 8

  var body: some View {
    PickerTrigger(label: label, value: cm.map { Format.height($0, unit: unit) } ?? String(localized: "Pick a height"), placeholder: cm == nil) {
      load(cm, into: unit)
      open = true
    }
    .sheet(isPresented: $open, onDismiss: apply) {
      PickerSheet(confirm: "Use this height", onConfirm: { open = false }) {
        HStack(spacing: 8) {
          Pill(label: "Centimetres", selected: unit == .cm) { switchUnit(.cm) }
          Pill(label: "Feet & in", selected: unit == .inches, tint: C.skySoft, ink: C.sky) { switchUnit(.inches) }
        }
        HStack(spacing: 4) {
          if unit == .cm {
            wheel("Centimetres", $whole, Array(40...130)) { "\($0)" }
            wheel("Tenths", $tenths, Array(0...9)) { ".\($0)" }
            unitGlyph("cm")
          } else {
            wheel("Feet", $ft, Array(1...5)) { "\($0)" }
            unitGlyph("ft")
            wheel("Inches", $inch, Array(0...11)) { "\($0)" }
            unitGlyph("in")
          }
        }
        .frame(height: 216)
      }
    }
  }

  private var current: Double {
    unit == .cm ? Format.cmPartsToCm(whole: whole, tenths: tenths) : Format.ftInToCm(ft: ft, inch: inch)
  }

  private func load(_ cm: Double?, into unit: HeightUnit) {
    let value = (cm ?? 0) > 0 ? cm! : 50
    if unit == .cm {
      let parts = Format.cmToParts(value)
      whole = min(130, max(40, parts.whole))
      tenths = parts.tenths
    } else {
      let parts = Format.cmToFtIn(value)
      ft = min(5, max(1, parts.ft))
      inch = parts.inch
    }
  }

  private func switchUnit(_ next: HeightUnit) {
    guard next != unit else { return }
    let value = current
    unit = next
    load(value, into: next)
  }

  private func apply() {
    let value = current
    if value > 0 { cm = value }
  }
}

// MARK: - Shared wheel bits

func wheel(_ label: LocalizedStringKey, _ selection: Binding<Int>, _ values: [Int], text: @escaping (Int) -> String) -> some View {
  Picker(label, selection: selection) {
    ForEach(values, id: \.self) { value in
      Text(text(value)).font(.app(.bold, 20)).tag(value)
    }
  }
  .pickerStyle(.wheel)
  .frame(maxWidth: 96)
  .clipped()
  .accessibilityLabel(label)
}

func unitGlyph(_ text: String) -> some View {
  Text(text).font(.app(.bold, 16)).foregroundStyle(C.tealDark).padding(.horizontal, 2)
}

/// Boy / Girl style toggle pills where tapping the selected one clears it.
struct ToggleRow<Value: Hashable>: View {
  let label: LocalizedStringKey
  let options: [(Value, LocalizedStringKey)]
  @Binding var selection: Value?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      FieldLabel(label)
      HStack(spacing: 8) {
        ForEach(options, id: \.0) { option in
          Pill(label: option.1, selected: selection == option.0) {
            selection = selection == option.0 ? nil : option.0
          }
        }
      }
    }
  }
}
