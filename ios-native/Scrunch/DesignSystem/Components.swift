import SwiftUI

// Port of components/ui.tsx and components/Screen.tsx.

struct Card<Content: View>: View {
  var padding: CGFloat = 20
  var spacing: CGFloat = 12
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: spacing) { content }
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(C.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
      .cardShadow()
  }
}

struct ScreenTitle: View {
  let text: Text
  init(_ key: LocalizedStringKey) { text = Text(key) }
  init(verbatim: String) { text = Text(verbatim: verbatim) }

  var body: some View {
    text
      .font(.app(.displayBold, 34, relativeTo: .largeTitle))
      .tracking(-0.6)
      .foregroundStyle(C.ink)
      .accessibilityAddTraits(.isHeader)
  }
}

struct Subtitle: View {
  let text: LocalizedStringKey
  init(_ text: LocalizedStringKey) { self.text = text }

  var body: some View {
    Text(text)
      .font(.app(.body, 16))
      .foregroundStyle(C.muted)
      .lineSpacing(4)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct FieldLabel: View {
  let text: LocalizedStringKey
  init(_ text: LocalizedStringKey) { self.text = text }

  var body: some View {
    Text(text)
      .font(.app(.medium, 13, relativeTo: .footnote))
      .foregroundStyle(C.muted)
      .padding(.leading, 8)
  }
}

struct Pill: View {
  let label: LocalizedStringKey
  var selected = false
  var tint: Color = C.tealSoft
  var ink: Color = C.tealDark
  var selectedTint: Color = C.ink
  var selectedInk: Color = C.onInk
  let action: () -> Void

  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if selected && differentiateWithoutColor {
          Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
        }
        Text(label).font(.app(.bold, 15))
      }
      .foregroundStyle(selected ? selectedInk : ink)
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(selected ? selectedTint : tint, in: Capsule())
    }
    .buttonStyle(PressScale())
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// Teal pill button. An async action shows a spinner and blocks double taps.
struct PrimaryButton: View {
  let label: LocalizedStringKey
  var disabled = false
  var tint: Color = C.teal
  let action: () async -> Void

  @State private var busy = false

  var body: some View {
    Button {
      guard !busy, !disabled else { return }
      busy = true
      Task {
        await action()
        busy = false
      }
    } label: {
      ZStack {
        if busy {
          ProgressView().tint(C.onAccent)
        } else {
          Text(label).font(.app(.bold, 17)).foregroundStyle(C.onAccent)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 56)
      .padding(.horizontal, 22)
      .background(tint, in: Capsule())
      .opacity(disabled || busy ? 0.45 : 1)
    }
    .buttonStyle(PressScale())
    .disabled(disabled || busy)
    .accessibilityLabel(label)
    .accessibilityValue(busy ? "Saving" : "")
  }
}

struct SecondaryButton: View {
  let label: LocalizedStringKey
  var ink: Color = C.ink
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.app(.bold, 16))
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(C.card, in: Capsule())
        .cardShadow()
    }
    .buttonStyle(PressScale())
  }
}

/// 44pt white circle with a shadow (RN `IconButton`).
struct CircleIconButton: View {
  let systemImage: String
  let label: LocalizedStringKey
  /// Extra names Voice Control accepts, e.g. "Add" for a plus.
  var spokenNames: [LocalizedStringKey] = []
  var ink: Color = C.ink
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(ink)
        .frame(width: 44, height: 44)
        .background(C.card, in: Circle())
        .cardShadow()
    }
    .buttonStyle(PressScale())
    .accessibilityLabel(label)
    .accessibilityInputLabels([label] + spokenNames)
    .accessibilityShowsLargeContentViewer {
      Label(label, systemImage: systemImage)
    }
  }
}

struct FormField: View {
  let label: LocalizedStringKey
  @Binding var text: String
  var placeholder: LocalizedStringKey = ""
  var axis: Axis = .horizontal
  var keyboard: UIKeyboardType = .default

  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    // Text fields grow downwards instead of clipping at larger text sizes.
    let axis: Axis = keyboard == .default || typeSize.isAccessibilitySize ? .vertical : axis
    VStack(alignment: .leading, spacing: 8) {
      FieldLabel(label).accessibilityHidden(true)
      TextField(placeholder, text: $text, axis: axis)
        .font(.app(.medium, 16))
        .foregroundStyle(C.ink)
        .keyboardType(keyboard)
        .lineLimit(axis == .vertical ? (self.axis == .vertical ? 3...6 : 1...4) : 1...1)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(C.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .cardShadow()
        .accessibilityLabel(label)
    }
  }
}

struct PressScale: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    PressScaleLabel(label: configuration.label, isPressed: configuration.isPressed)
  }
}

/// Reduce Motion swaps the press shrink for a dim.
private struct PressScaleLabel<Label: View>: View {
  let label: Label
  let isPressed: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    label
      .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1)
      .opacity(isPressed && reduceMotion ? 0.7 : 1)
      .animation(.easeOut(duration: 0.12), value: isPressed)
  }
}

/// RN `Screen`: bg colour, 20pt padding, 16pt gaps, optional floating back button.
struct ScreenScaffold<Content: View, Trailing: View>: View {
  var showsBack = true
  var clearDock = false
  var scrolls = true
  @ViewBuilder var trailing: Trailing
  @ViewBuilder var content: Content

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Group {
      if scrolls {
        ScrollView(showsIndicators: false) { column }
          .scrollDismissesKeyboard(.interactively)
      } else {
        column.frame(maxHeight: .infinity, alignment: .top)
      }
    }
    // An opaque bar, so scrolled text never runs under the floating buttons.
    .safeAreaInset(edge: .top, spacing: 0) {
      if hasChrome {
        HStack {
          if showsBack {
            CircleIconButton(systemImage: "chevron.left", label: "Back") { dismiss() }
          }
          Spacer()
          trailing
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(C.bg)
      }
    }
    .background(C.bg.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
  }

  private var hasChrome: Bool { showsBack || Trailing.self != EmptyView.self }

  private var column: some View {
    VStack(alignment: .leading, spacing: 16) { content }
      .padding(.horizontal, 20)
      .padding(.top, hasChrome ? 8 : 20)
      .padding(.bottom, clearDock ? tabDockInset + 20 : 20)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension ScreenScaffold where Trailing == EmptyView {
  init(showsBack: Bool = true, clearDock: Bool = false, scrolls: Bool = true, @ViewBuilder content: () -> Content) {
    self.init(showsBack: showsBack, clearDock: clearDock, scrolls: scrolls, trailing: { EmptyView() }, content: content)
  }
}

struct LoadingView: View {
  var label: LocalizedStringKey? = nil

  var body: some View {
    VStack(spacing: 12) {
      ProgressView().tint(C.teal)
      if let label {
        Text(label).font(.app(.body, 15)).foregroundStyle(C.muted)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(C.bg.ignoresSafeArea())
  }
}

/// The designed empty / first-run / stale state: icon, a short warm line, and what to do next.
struct EmptyState: View {
  let symbol: String
  var tint: Color = C.teal
  let title: Text
  let message: Text
  var actionLabel: LocalizedStringKey? = nil
  var action: (() -> Void)? = nil
  var secondaryLabel: LocalizedStringKey? = nil
  var secondaryAction: (() -> Void)? = nil

  /// Literal copy, looked up in the String Catalog.
  init(
    symbol: String, tint: Color = C.teal, title: LocalizedStringKey, message: LocalizedStringKey,
    actionLabel: LocalizedStringKey? = nil, action: (() -> Void)? = nil,
    secondaryLabel: LocalizedStringKey? = nil, secondaryAction: (() -> Void)? = nil
  ) {
    self.init(symbol: symbol, tint: tint, title: Text(title), message: Text(message), actionLabel: actionLabel, action: action, secondaryLabel: secondaryLabel, secondaryAction: secondaryAction)
  }

  /// Copy that's already localised, e.g. from ScrunchCore's HomeCopy.
  init<T: StringProtocol, M: StringProtocol>(
    symbol: String, tint: Color = C.teal, title: T, message: M,
    actionLabel: LocalizedStringKey? = nil, action: (() -> Void)? = nil,
    secondaryLabel: LocalizedStringKey? = nil, secondaryAction: (() -> Void)? = nil
  ) {
    self.init(symbol: symbol, tint: tint, title: Text(title), message: Text(message), actionLabel: actionLabel, action: action, secondaryLabel: secondaryLabel, secondaryAction: secondaryAction)
  }

  private init(
    symbol: String, tint: Color, title: Text, message: Text,
    actionLabel: LocalizedStringKey?, action: (() -> Void)?,
    secondaryLabel: LocalizedStringKey?, secondaryAction: (() -> Void)?
  ) {
    self.symbol = symbol
    self.tint = tint
    self.title = title
    self.message = message
    self.actionLabel = actionLabel
    self.action = action
    self.secondaryLabel = secondaryLabel
    self.secondaryAction = secondaryAction
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      IconWell(systemImage: symbol, tint: tint, size: 52)
      VStack(alignment: .leading, spacing: 6) {
        title
          .font(.app(.displayBold, 21, relativeTo: .title3))
          .foregroundStyle(C.ink)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
        message
          .font(.app(.body, 15))
          .foregroundStyle(C.muted)
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
      if actionLabel != nil || secondaryLabel != nil {
        HStack(spacing: 10) {
          if let actionLabel, let action {
            button(actionLabel, fill: tint, ink: C.onAccent, action: action)
          }
          if let secondaryLabel, let secondaryAction {
            button(secondaryLabel, fill: C.bg, ink: C.ink, action: secondaryAction)
          }
        }
        .padding(.top, 2)
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(C.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    .cardShadow()
  }

  private func button(_ label: LocalizedStringKey, fill: Color, ink: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.app(.bold, 15))
        .foregroundStyle(ink)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity, minHeight: 46)
        .padding(.horizontal, 12)
        .background(fill, in: Capsule())
    }
    .buttonStyle(PressScale())
  }
}

/// Text action for the floating header (e.g. "Save"), same height as `CircleIconButton`.
struct HeaderButton: View {
  let label: String
  let action: () async -> Void

  @State private var busy = false

  var body: some View {
    Button {
      guard !busy else { return }
      busy = true
      Task {
        await action()
        busy = false
      }
    } label: {
      ZStack {
        Text(label).opacity(busy ? 0 : 1)
        if busy { ProgressView().tint(C.onAccent) }
      }
      .font(.app(.bold, 16))
      .foregroundStyle(C.onAccent)
      .padding(.horizontal, 20)
      .frame(minHeight: 44)
      .background(C.teal, in: Capsule())
      .cardShadow()
    }
    .buttonStyle(PressScale())
    .disabled(busy)
  }
}

/// Circular icon well used on tiles and the add-log sheet.
struct IconWell: View {
  let systemImage: String
  let tint: Color
  var size: CGFloat = 40
  var ink: Color = C.onInk

  var body: some View {
    Image(systemName: systemImage)
      .font(.system(size: size * 0.45, weight: .semibold))
      .foregroundStyle(ink)
      .frame(width: size, height: size)
      .background(tint, in: Circle())
      .accessibilityHidden(true)
  }
}

/// Hidden navigation bars disable the edge-swipe back gesture; this restores it.
extension UINavigationController: UIGestureRecognizerDelegate {
  override open func viewDidLoad() {
    super.viewDidLoad()
    interactivePopGestureRecognizer?.delegate = self
  }

  public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    viewControllers.count > 1
  }
}
