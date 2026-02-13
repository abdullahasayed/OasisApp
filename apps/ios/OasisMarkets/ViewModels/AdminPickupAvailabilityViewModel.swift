import Foundation

@MainActor
final class AdminPickupAvailabilityViewModel: ObservableObject {
    @Published var days: [AdminPickupDay] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    func load(apiClient: ApiClient, token: String?) async {
        guard let token else {
            errorMessage = "Missing admin token"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            days = try await apiClient.fetchAdminPickupAvailability(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateRange(
        date: String,
        openHour: Int,
        closeHour: Int,
        apiClient: ApiClient,
        token: String?
    ) async {
        guard let token else {
            errorMessage = "Missing admin token"
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await apiClient.updateAdminPickupDayRange(
                accessToken: token,
                date: date,
                openHour: openHour,
                closeHour: closeHour
            )
            days = try await apiClient.fetchAdminPickupAvailability(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleSlot(
        slotStartIso: String,
        unavailable: Bool,
        apiClient: ApiClient,
        token: String?
    ) async {
        guard let token else {
            errorMessage = "Missing admin token"
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await apiClient.toggleAdminPickupSlotUnavailable(
                accessToken: token,
                slotStartIso: slotStartIso,
                unavailable: unavailable
            )
            days = try await apiClient.fetchAdminPickupAvailability(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
