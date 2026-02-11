import SwiftUI

struct OrderLookupView: View {
    @EnvironmentObject private var apiClient: ApiClient
    @StateObject private var viewModel = OrderLookupViewModel()

    var body: some View {
        Form {
            Section("Lookup") {
                TextField("Order Number", text: $viewModel.orderNumber)
                TextField("Phone", text: $viewModel.phone)
                    .keyboardType(.phonePad)
                Button("Find Order") {
                    Task { await viewModel.lookup(apiClient: apiClient) }
                }
            }

            if let result = viewModel.result {
                Section("Order") {
                    Text(result.orderNumber)
                        .font(.title2.bold())
                    Text(result.customerName.uppercased())
                    Text("Status: \(result.status.displayName)")
                    Text("Estimated total: \(result.estimatedTotalCents.usd)")
                    if let finalTotal = result.finalTotalCents {
                        Text("Final total: \(finalTotal.usd)")
                    }
                    if let receipt = result.receiptUrl {
                        Link("Open Receipt", destination: receipt)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
