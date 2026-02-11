import Foundation
import SwiftUI

@MainActor
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    func load(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                image = uiImage
            }
        } catch {
            image = nil
        }
    }
}
