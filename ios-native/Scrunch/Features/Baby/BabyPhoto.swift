import PhotosUI
import ScrunchCore
import SwiftUI
import UIKit

/// The baby's photo, or their initial on a soft circle when there isn't one.
struct BabyAvatar: View {
  let babyId: BabyID
  let name: String
  var size: CGFloat = 44

  @Environment(ConvexService.self) private var convex
  @State private var photo = Live<String?>()

  var body: some View {
    ZStack {
      Circle().fill(C.purpleSoft)
      Text(name.prefix(1).uppercased())
        .font(.app(.displayBold, size * 0.45))
        .foregroundStyle(C.purple)
      if let url = (photo.value ?? nil).flatMap({ URL(string: $0) }) {
        AsyncImage(url: url) { image in
          image.resizable().scaledToFill()
        } placeholder: {
          Color.clear
        }
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .accessibilityHidden(true)
    .task(id: babyId) { await photo.bind(API.babies.photoUrl(babyId), convex) }
  }
}

/// Optional photo on the edit screen. Uses the system picker, so no library permission is needed.
struct BabyPhotoField: View {
  let babyId: BabyID
  let name: String

  @Environment(ConvexService.self) private var convex
  @Environment(SaveFeedback.self) private var saveFeedback
  @State private var photo = Live<String?>()
  @State private var item: PhotosPickerItem?
  @State private var busy = false
  @State private var alert: FormAlert?

  private var hasPhoto: Bool { (photo.value ?? nil) != nil }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      FieldLabel("Photo (optional)")
      HStack(spacing: 16) {
        BabyAvatar(babyId: babyId, name: name, size: 72)
          .overlay {
            if busy { ProgressView().tint(C.teal) }
          }
        VStack(alignment: .leading, spacing: 6) {
          PhotosPicker(selection: $item, matching: .images) {
            Text(hasPhoto ? "Change photo" : "Add a photo")
              .font(.app(.bold, 16))
              .foregroundStyle(C.tealDark)
              .frame(minHeight: 44)
          }
          if hasPhoto {
            Button("Remove photo") { Task { await remove() } }
              .font(.app(.medium, 15))
              .foregroundStyle(C.muted)
              .frame(minHeight: 44)
          }
        }
        .disabled(busy)
        Spacer(minLength: 0)
      }
    }
    .formAlert($alert)
    .task(id: babyId) { await photo.bind(API.babies.photoUrl(babyId), convex) }
    .onChange(of: item) { _, picked in
      guard let picked else { return }
      Task { await upload(picked) }
    }
  }

  private func upload(_ picked: PhotosPickerItem) async {
    busy = true
    defer {
      busy = false
      item = nil
    }
    do {
      guard let data = try await picked.loadTransferable(type: Data.self), let jpeg = Self.jpeg(from: data) else {
        return alert = FormAlert(title: "Couldn’t use that photo", message: "Try a different one.")
      }
      let uploadURL = try await convex.mutation(API.babies.generatePhotoUploadUrl(babyId))
      guard let url = URL(string: uploadURL) else { throw URLError(.badURL) }
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
      let (body, response) = try await URLSession.shared.upload(for: request, from: jpeg)
      guard (response as? HTTPURLResponse)?.statusCode == 200,
            let storageId = try JSONDecoder().decode([String: String].self, from: body)["storageId"]
      else { throw URLError(.badServerResponse) }
      try await convex.mutation(API.babies.setPhoto(babyId: babyId, storageId: storageId))
      saveFeedback.show("Photo saved")
    } catch {
      alert = FormAlert(title: "Couldn’t save the photo", message: UserMessage.from(error, fallback: "Try again"))
    }
  }

  private func remove() async {
    busy = true
    defer { busy = false }
    do {
      try await convex.mutation(API.babies.removePhoto(babyId))
    } catch {
      alert = FormAlert(title: "Couldn’t remove the photo", message: UserMessage.from(error, fallback: "Try again"))
    }
  }

  /// Keeps uploads small: longest side 1024 pt, JPEG at 0.8.
  private static func jpeg(from data: Data) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let longest = max(image.size.width, image.size.height)
    let scale = min(1, 1024 / max(longest, 1))
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    return resized.jpegData(compressionQuality: 0.8)
  }
}
