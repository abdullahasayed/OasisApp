import Foundation

protocol PaymentClient {
    func prepareCheckout(clientSecret: String) async throws
    func completeCheckout() async throws
}

final class StripePaymentClient: PaymentClient {
    func prepareCheckout(clientSecret: String) async throws {
        // Hook Stripe PaymentSheet setup here.
        // The backend returns `paymentClientSecret` from POST /v1/orders.
        _ = clientSecret
    }

    func completeCheckout() async throws {
        // Hook Stripe PaymentSheet presentation/completion here.
    }
}
