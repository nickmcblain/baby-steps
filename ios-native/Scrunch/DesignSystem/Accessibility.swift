import ScrunchCore
import SwiftUI

/// HStack that becomes a leading-aligned VStack at accessibility text sizes.
struct AdaptiveStack<Content: View>: View {
  var alignment: VerticalAlignment = .center
  var spacing: CGFloat = 8
  @ViewBuilder var content: Content

  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let layout = typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
      : AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
    layout { content }
  }
}

private struct AdaptiveDetents: ViewModifier {
  let detents: Set<PresentationDetent>
  @Environment(\.dynamicTypeSize) private var typeSize

  func body(content: Content) -> some View {
    content.presentationDetents(typeSize.isAccessibilitySize ? [.large] : detents)
  }
}

private struct MotionSafeAnimation<V: Equatable>: ViewModifier {
  let animation: Animation?
  let value: V
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content.animation(reduceMotion ? nil : animation, value: value)
  }
}

private struct NumericTextTransition: ViewModifier {
  var value: Double?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    if reduceMotion {
      content.contentTransition(.identity)
    } else if let value {
      content.contentTransition(.numericText(value: value))
    } else {
      content.contentTransition(.numericText())
    }
  }
}

extension View {
  /// Fixed-height sheets clip at accessibility sizes, so those get a full-height sheet.
  func adaptiveDetents(_ detents: Set<PresentationDetent>) -> some View {
    modifier(AdaptiveDetents(detents: detents))
  }

  func motionSafeAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
    modifier(MotionSafeAnimation(animation: animation, value: value))
  }

  func numericTextTransition(value: Double? = nil) -> some View {
    modifier(NumericTextTransition(value: value))
  }
}

extension WeekMarkerKind {
  /// Shape cue for the week chart when Differentiate Without Colour is on.
  var symbol: String {
    switch self {
    case .feed: "drop.fill"
    case .nappy: "circle.grid.2x2.fill"
    case .weight: "scalemass.fill"
    case .height: "ruler.fill"
    case .custom: "calendar"
    case .pump: "drop.halffull"
    case .medicine: "pills.fill"
    case .potty: "toilet.fill"
    case .activity: "figure.play"
    }
  }
}
