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
        CircleIconButton(systemImage: "figure.and.child.holdinghands", label: "Join a partner") { joinOpen = true }
        CircleIconButton(systemImage: "plus", label: "Add baby") { router.path.append(.newBaby) }
          .padding(.leading, 8)
      }

      if babies.isLoading {
        LoadingView(label: "Connecting…").frame(minHeight: 240)
      } else {
        let now = Date().epochMs
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
          ForEach(babies.value ?? []) { baby in
            Button { open(baby.id) } label: {
              VStack(alignment: .leading, spacing: 8) {
                Text(baby.name.prefix(1).uppercased())
                  .font(.app(.displayBold, 20))
                  .foregroundStyle(C.purple)
                  .frame(width: 44, height: 44)
                  .background(C.purpleSoft, in: Circle())
                Text(baby.name).font(.app(.bold, 18)).foregroundStyle(C.ink).lineLimit(1)
                Text("\(Format.age(dateOfBirth: baby.dateOfBirth, now: now)) · \(Format.kg(baby.weightGrams))")
                  .font(.app(.body, 13)).foregroundStyle(C.muted)
                Text("Code \(baby.inviteCode)")
                  .font(.app(.medium, 12)).foregroundStyle(C.purple).padding(.top, 2)
              }
              .padding(16)
              .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
              .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
              .cardShadow()
            }
            .buttonStyle(PressScale())
          }
        }
      }
    }
    .task { await babies.bind(API.babies.list(), convex, cacheKey: API.babies.list().key) }
    .sheet(isPresented: $joinOpen) {
      JoinPartnerSheet { id in
        joinOpen = false
        open(id)
      }
      .presentationDetents([.height(260)])
      .presentationDragIndicator(.visible)
      .presentationCornerRadius(32)
      .presentationBackground(C.bg)
    }
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
      Text("Join a partner").font(.app(.bold, 22)).foregroundStyle(C.ink)
      Text("Enter their 6-character invite code.").font(.app(.body, 15)).foregroundStyle(C.muted).padding(.bottom, 8)
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
        .accessibilityLabel("Invite code")
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
