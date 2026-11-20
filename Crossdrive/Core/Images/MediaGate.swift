import Foundation

/// Holds a screen back until its main media is ready, but never longer than a
/// deadline, so a slow network cannot block it.
enum MediaGate {
    /// Runs every load together. Calls `reveal` once all have finished, or when
    /// `deadline` returns first; the loads keep going after a deadline reveal.
    /// Everything runs inside the caller's task, so leaving the screen cancels it.
    @MainActor
    static func reveal(
        after loads: [@Sendable () async -> Void],
        deadline: @escaping @Sendable () async -> Void,
        reveal: @MainActor () -> Void
    ) async {
        guard !loads.isEmpty else {
            reveal()
            return
        }
        await withTaskGroup(of: Bool.self) { group in
            for load in loads {
                group.addTask {
                    await load()
                    return true
                }
            }
            group.addTask {
                await deadline()
                return false
            }
            var remaining = loads.count
            for await isLoad in group {
                if isLoad {
                    remaining -= 1
                    if remaining == 0 {
                        reveal()
                        group.cancelAll()
                    }
                } else {
                    reveal()
                }
            }
        }
    }
}
