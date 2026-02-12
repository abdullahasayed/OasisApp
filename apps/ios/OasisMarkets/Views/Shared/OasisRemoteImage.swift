import SwiftUI

struct OasisRemoteImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: Placeholder
    let contentMode: ContentMode

    @StateObject private var loader = ImageLoader()

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                placeholder
            }
        }
        .task(id: url) {
            await loader.load(from: url)
        }
    }
}
