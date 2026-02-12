import Foundation
import UIKit

actor ImageRepository {
    static let shared = ImageRepository()

    private let cache = NSCache<NSURL, UIImage>()
    private var inflight: [URL: Task<UIImage?, Never>] = [:]

    func image(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        if let running = inflight[url] {
            return await running.value
        }

        let task = Task<UIImage?, Never> {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.cachePolicy = .returnCacheDataElseLoad

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard
                    let http = response as? HTTPURLResponse,
                    (200..<300).contains(http.statusCode),
                    let image = UIImage(data: data)
                else {
                    return nil
                }

                self.store(image: image, for: url)
                return image
            } catch {
                return nil
            }
        }

        inflight[url] = task
        let result = await task.value
        inflight[url] = nil
        return result
    }

    func prefetch(urls: [URL]) {
        for url in urls {
            Task {
                _ = await image(for: url)
            }
        }
    }

    private func store(image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

@MainActor
final class ImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private var loadedURL: URL?
    private var activeRequestID: UUID?

    func load(from url: URL?) async {
        guard let url else {
            activeRequestID = nil
            image = nil
            loadedURL = nil
            return
        }

        if loadedURL == url, image != nil {
            return
        }

        let requestID = UUID()
        activeRequestID = requestID

        if loadedURL != url {
            image = nil
        }

        loadedURL = url
        let loadedImage = await ImageRepository.shared.image(for: url)

        guard activeRequestID == requestID else { return }
        image = loadedImage
    }

    static func prefetch(urls: [URL]) {
        Task {
            await ImageRepository.shared.prefetch(urls: urls)
        }
    }
}
