import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject private var appState: AppState

    let product: Product
    @State private var quantity: Double = 1

    var body: some View {
        Form {
            Section {
                Text(product.name)
                    .font(.title2.bold())
                Text(product.description)
                    .font(.body)
                Text(product.priceLabel)
                    .font(.headline)
            }

            Section(product.unit == .lb ? "Estimated Weight (lb)" : "Quantity") {
                Stepper(value: $quantity, in: 1...100, step: product.unit == .lb ? 0.25 : 1) {
                    Text("\(quantity, specifier: product.unit == .lb ? "%.2f" : "%.0f")")
                }
            }

            Section {
                Button("Add to Cart") {
                    appState.addToCart(product: product, quantity: quantity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Product")
    }
}
