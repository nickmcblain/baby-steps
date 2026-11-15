import ScrunchCore
import SwiftUI

/// Port of app/(app)/(tabs)/kids.tsx.
struct KidsView: View {
  @Environment(ConvexService.self) private var convex
  @Environment(AppRouter.self) private var router
  @Environment(ActiveBabyStore.self) private var activeBaby
  @State private var babies = Live<[Baby]>()
  @State private var joinOpen = false

  var body: some View {
    ScreenScaffold(showsBack: false, clearDock: true) {
      HStack {
        ScreenTitle("Kids")
        Spacer()
        Button { joinOpen = true } label: {
          Text("Join with a code")
            .font(.app(.bold, 13))
            .foregroundStyle(C.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(C.card, in: Capsule())
            .cardShadow()
        }
        .buttonStyle(PressScale())
        CircleIconButton(systemImage: "plus", label: "Add a baby") { router.path.append(.newBaby) }
          .padding(.leading, 8)
      }

      if babies.isLoading {
        LoadingView(label: "Connecting…").frame(minHeight: 240)
      } else if let list = babies.value, list.isEmpty {
        EmptyState(
          symbol: "heart.fill",
          tint: C.rose,
          title: "No babies yet",
          message: "Add your baby, or join your partner’s with the share code from their app.",
          actionLabel: "Add a baby",
          action: { router.path.append(.newBaby) },
          secondaryLabel: "Join with a code",
          secondaryAction: { joinOpen = true }
        )
      } else {
        let now = Date().epochMs
        VStack(spacing: 12) {
          ForEach(babies.value ?? []) { baby in
            babyRow(baby, now: now)
          }
        }
        if !(babies.value ?? []).isEmpty {
          Text(PartnerInvite.howTo).font(.app(.body, 13)).foregroundStyle(C.muted)
        }
      }
    }
    .task { await babies.bind(API.babies.list(), convex) }
    .sheet(isPresented: $joinOpen) {
      JoinPartnerSheet { id in
        joinOpen = false
        open(id)
      }
      .presentationDetents([.height(300)])
      .presentationDragIndicator(.visible)
      .presentationCornerRadius(32)
      .presentationBackground(C.bg)
    }
  }

  private func babyRow(_ baby: Baby, now: EpochMs) -> some View {
    VStack(spacing: 0) {
      Button { open(baby.id) } label: {
        HStack(spacing: 14) {
          Text(baby.name.prefix(1).uppercased())
            .font(.app(.displayBold, 22))
            .foregroundStyle(C.purple)
            .frame(width: 52, height: 52)
            .background(C.purpleSoft, in: Circle())
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 3) {
            Text(baby.name)
              .font(.app(.bold, 18))
              .foregroundStyle(C.ink)
              .fixedSize(horizontal: false, vertical: true)
            Text("\(Format.age(dateOfBirth: baby.dateOfBirth, now: now)) · \(Format.kg(baby.weightGrams))")
              .font(.app(.body, 14))
              .foregroundStyle(C.muted)
          }
          Spacer(minLength: 8)
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(C.muted)
            .accessibilityHidden(true)
        }
        .padding(16)
        .contentShape(Rectangle())
      }
      .buttonStyle(PressScale())
      .accessibilityElement(children: .combine)
      .accessibilityHint("Opens \(baby.name)’s home")

      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Share code: invite a partner")
            .font(.app(.medium, 13))
            .foregroundStyle(C.muted)
          Text(baby.inviteCode)
            .font(.app(.displayBold, 18))
            .tracking(2)
            .foregroundStyle(C.ink)
            .accessibilityLabel(baby.inviteCode.map(String.init).joined(separator: " "))
        }
        Spacer(minLength: 8)
        ShareLink(item: PartnerInvite.message(babyName: baby.name, code: baby.inviteCode)) {
          Label("Share", systemImage: "square.and.arrow.up")
            .font(.app(.bold, 15))
            .foregroundStyle(C.purple)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(C.purpleSoft, in: Capsule())
        }
        .buttonStyle(PressScale())
        .accessibilityHint("Shares code \(baby.inviteCode) with a friendly message")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
    }
    .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    .cardShadow()
  }

  private func open(_ id: BabyID) {
    activeBaby.select(id)
    router.popToRoot(tab: .home)
  }
}

struct JoinPartnerSheet: View {
  let onJoined: (BabyID) -> Void

  @Environment(ConvexService.self) private var convex
  @State private var code = ""
  @State private var error: String?
  @State private var busy = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Join with a code").font(.app(.bold, 22)).foregroundStyle(C.ink)
      Text("Enter the 6-character code your partner sent. You'll both see the same feeds, sleeps and nappies.")
        .font(.app(.body, 15)).foregroundStyle(C.muted).padding(.bottom, 8)
        .fixedSize(horizontal: false, vertical: true)
      InviteCodeField(code: $code, editable: !busy)
        .onChange(of: code) { _, next in
          error = nil
          if next.count == InviteCode.length { Task { await join(next) } }
        }
      if busy {
        ProgressView().tint(C.teal).padding(.top, 12).frame(maxWidth: .infinity)
      } else if let error {
        Text(error).font(.app(.medium, 14)).foregroundStyle(C.danger).padding(.top, 12)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 20)
    .padding(.top, 28)
  }

  private func join(_ next: String) async {
    guard !busy else { return }
    busy = true
    do {
      let id = try await convex.mutation(API.babies.joinByCode(next))
      onJoined(id)
    } catch {
      self.error = UserMessage.from(error, fallback: "Check the code.")
      busy = false
    }
  }
}

/// Port of components/InviteCodeBoxes.tsx: six boxes over a hidden text field.
struct InviteCodeField: View {
  @Binding var code: String
  var editable = true
  @FocusState private var focused: Bool

  var body: some View {
    ZStack {
      TextField("", text: Binding(get: { code }, set: { code = InviteCode.sanitize($0) }))
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
        .keyboardType(.asciiCapable)
        .focused($focused)
        .disabled(!editable)
        .opacity(0.02)
        .accessibilityLabel("Share code")
      HStack(spacing: 8) {
        ForEach(0..<InviteCode.length, id: \.self) { index in
          let chars = Array(code)
          let active = chars.count == index && editable
          Text(index < chars.count ? String(chars[index]) : "")
            .font(.app(.displayBold, 22))
            .foregroundStyle(C.ink)
            .frame(maxWidth: 48)
            .aspectRatio(0.85, contentMode: .fit)
            .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile - 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.tile - 8, style: .continuous).stroke(active ? C.teal : C.line, lineWidth: 2))
            .frame(maxWidth: .infinity)
        }
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
    .contentShape(Rectangle())
    .onTapGesture { focused = true }
    .task {
      try? await Task.sleep(for: .milliseconds(360))
      focused = true
    }
  }
}
