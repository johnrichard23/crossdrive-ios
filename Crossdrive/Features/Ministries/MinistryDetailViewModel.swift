import DataLayer
import DesignSystem
import Observation
import UIKit

/// One ministry's page: what it is, photos, updates, how to pray and what is
/// needed. Holds its loading state until the top photo is ready.
@Observable @MainActor
final class MinistryDetailViewModel {
    private(set) var state: LoadState<MinistryDetail> = .loading
    /// The ministry is gone or was taken down (the server said not found).
    private(set) var isUnavailable = false
    /// The top photo, loaded before the page shows so it never pops in.
    private(set) var heroImage: UIImage?
    /// This person said they prayed, on this visit.
    private(set) var hasPrayed = false
    var toast: DSToast?
    /// Set by the screen from the connection; "I prayed" waits for one.
    var isOnline = true

    private let api: MinistriesAPI
    private let reporter: any CrashReporter
    private let imageLoader: any ImageLoading
    private let mediaDeadline: @Sendable () async -> Void
    private let ministryID: Ministry.ID
    private var loadToken = 0
    private var isSendingPrayer = false

    init(
        api: MinistriesAPI,
        ministryID: Ministry.ID,
        imageLoader: any ImageLoading,
        reporter: any CrashReporter = NoCrashReporter(),
        mediaDeadline: @escaping @Sendable () async -> Void = {
            try? await Task.sleep(for: .seconds(3))
        }
    ) {
        self.api = api
        self.ministryID = ministryID
        self.imageLoader = imageLoader
        self.reporter = reporter
        self.mediaDeadline = mediaDeadline
    }

    /// Loads the ministry. With `heroPixels`, the loading state stays up until
    /// the top photo is ready too, but never longer than `mediaDeadline`.
    func load(heroPixels: Int? = nil, forceReload: Bool = false) async {
        if case .loaded = state, !forceReload {
            return
        }

        loadToken += 1
        let token = loadToken
        if state.value == nil {
            state = .loading
        }
        isUnavailable = false

        do {
            let detail = try await api.ministry(id: ministryID)
            guard token == loadToken else { return }
            if let heroPixels, let url = detail.ministry.heroURL, state.value == nil {
                await revealWithPhoto(detail, url: url, pixels: heroPixels, token: token)
            } else {
                state = .loaded(detail)
            }
        } catch {
            guard token == loadToken, !Self.isCancellation(error) else { return }
            report(error)
            if (error as? NetworkError)?.statusCode == 404 {
                isUnavailable = true
                state = .failed(error.userMessage)
            } else {
                state = error.isOffline ? .offline : .failed(error.userMessage)
            }
        }
    }

    /// The device is back online: retry what failed because it wasn't.
    func connectionRestored(heroPixels: Int? = nil) async {
        switch state {
        case .offline, .failed: await load(heroPixels: heroPixels)
        case .loading, .loaded: break
        }
    }

    /// "I prayed": counts one more at once and tells the server. A second tap
    /// does nothing; if the server says no, the count goes back with a toast.
    func pray() async {
        guard !hasPrayed, !isSendingPrayer, let prayer = state.value?.prayer else { return }
        guard isOnline else {
            toast = .info(String(localized: "Connect to the internet to say you prayed."))
            return
        }
        isSendingPrayer = true
        defer { isSendingPrayer = false }
        hasPrayed = true
        changePrayedCount(by: 1)
        do {
            try await api.markPrayed(prayer.id, ministry: ministryID)
        } catch {
            hasPrayed = false
            changePrayedCount(by: -1)
            toast = .error(String(localized: "Couldn't save. Try again."))
        }
    }

    // MARK: - Private

    private func changePrayedCount(by change: Int) {
        guard var detail = state.value, var prayer = detail.prayer else { return }
        prayer.prayedCount = max(prayer.prayedCount + change, 0)
        detail.prayer = prayer
        state = .loaded(detail)
    }

    /// Too slow: the page shows at the deadline and the photo keeps loading.
    private func revealWithPhoto(
        _ detail: MinistryDetail,
        url: URL,
        pixels: Int,
        token: Int
    ) async {
        let imageLoader = imageLoader
        await MediaGate.reveal(
            after: [{ [weak self] in
                let image = await imageLoader.image(for: url, maxPixels: pixels)
                await self?.showHero(image)
            }],
            deadline: mediaDeadline
        ) { [weak self] in
            guard let self, token == loadToken, state.value == nil else { return }
            state = .loaded(detail)
        }
    }

    private func showHero(_ image: UIImage?) {
        if let image {
            heroImage = image
        }
    }

    private func report(_ error: any Error) {
        if let error = error as? NetworkError, case .decoding = error {
            reporter.record(error, context: "Loading a ministry")
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .cancelled
    }
}
