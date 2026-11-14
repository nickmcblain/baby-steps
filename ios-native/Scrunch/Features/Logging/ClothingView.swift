import ScrunchCore
import SwiftUI

/// Port of temp.tsx: room temperature → TOG and layers.
struct ClothingView: View {
  let babyId: BabyID

  @Environment(ConvexService.self) private var convex
  @State private var baby = Live<Baby>()
  @State private var fahrenheit = false
  @State private var tempC = Clothing.defaultTempC
  @State private var hydrated = false

  var body: some View {
    ScreenScaffold {
      ScreenTitle("Clothing")

      HStack(spacing: 8) {
        Pill(label: "°C", selected: !fahrenheit) { fahrenheit = false }
        Pill(label: "°F", selected: fahrenheit, tint: C.peachSoft, ink: C.peach) { fahrenheit = true }
      }
      .frame(maxWidth: .infinity)

      VStack(spacing: 18) {
        (Text(Clothing.formatTemp(tempC, fahrenheit: fahrenheit))
          .font(.app(.displayBold, 56))
          .foregroundStyle(C.ink)
          + Text(fahrenheit ? " °F" : " °C").font(.app(.bold, 22)).foregroundStyle(C.muted))
          .tracking(-1)
          .contentTransition(.numericText(value: tempC))
          .animation(.snappy, value: tempC)
        HStack(spacing: 20) {
          arrow("chevron.left", "Decrease temperature") { tempC = Clothing.nudge(tempC, by: -Clothing.stepC) }
          Text("±0.5°C").font(.app(.medium, 13)).foregroundStyle(C.muted).frame(minWidth: 56)
          arrow("chevron.right", "Increase temperature") { tempC = Clothing.nudge(tempC, by: Clothing.stepC) }
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 28)
      .padding(.horizontal, 20)
      .background(C.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
      .cardShadow()
      .accessibilityElement(children: .contain)
      .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: tempC = Clothing.nudge(tempC, by: Clothing.stepC)
        case .decrement: tempC = Clothing.nudge(tempC, by: -Clothing.stepC)
        @unknown default: break
        }
      }

      if let baby = baby.value {
        let advice = Clothing.advice(tempC: tempC, dateOfBirth: baby.dateOfBirth, weightGrams: baby.weightGrams, now: Date().epochMs)
        Card {
          Text(advice.tog).font(.app(.displayBold, 28)).foregroundStyle(C.tealDark)
          ForEach(advice.layers, id: \.self) { layer in
            HStack(spacing: 10) {
              Circle().fill(C.teal).frame(width: 10, height: 10)
              Text(layer).font(.app(.medium, 16)).foregroundStyle(C.ink)
            }
          }
          Text(advice.why).font(.app(.body, 15)).foregroundStyle(C.muted).padding(.top, 8)
          if advice.overheat {
            Text(Clothing.overheatCheck)
              .font(.app(.bold, 15))
              .foregroundStyle(C.peach)
              .padding(12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(C.peachSoft, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
          }
        }
      }
      Text(Clothing.finePrint).font(.app(.body, 13)).foregroundStyle(C.muted)
    }
    .task { await baby.bind(API.babies.get(babyId), convex) }
    .onChange(of: baby.value) { _, value in
      guard let value, !hydrated else { return }
      tempC = value.lastRoomTempC ?? Clothing.defaultTempC
      hydrated = true
    }
    .task(id: hydrated ? tempC : nil) {
      // Persist quietly (debounced) for the next visit and Ask context.
      guard hydrated else { return }
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled else { return }
      _ = try? await convex.mutation(API.babies.saveRoomTemp(babyId: babyId, tempC: tempC))
    }
  }

  private func arrow(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(C.tealDark)
        .frame(width: 52, height: 52)
        .background(C.tealSoft, in: Circle())
    }
    .buttonStyle(PressScale())
    .accessibilityLabel(label)
  }
}
