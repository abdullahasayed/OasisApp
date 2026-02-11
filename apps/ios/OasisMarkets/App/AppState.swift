import Foundation
import Combine

enum AppMode {
    case shopper
    case admin
}

@MainActor
final class AppState: ObservableObject {
    @Published var appMode: AppMode = .shopper
    @Published var cartItems: [CartItem] = []
    @Published var adminAccessToken: String?
    @Published var adminRefreshToken: String?

    func addToCart(product: Product, quantity: Double) {
        guard quantity > 0 else { return }
        if let index = cartItems.firstIndex(where: { $0.product.id == product.id }) {
            cartItems[index].quantity += quantity
        } else {
            cartItems.append(CartItem(product: product, quantity: quantity))
        }
    }

    func removeFromCart(item: CartItem) {
        cartItems.removeAll { $0.id == item.id }
    }

    func clearCart() {
        cartItems.removeAll()
    }

    var estimatedCartTotalCents: Int {
        cartItems.reduce(0) { partial, item in
            partial + Int((Double(item.product.priceCents) * item.quantity).rounded())
        }
    }
}
