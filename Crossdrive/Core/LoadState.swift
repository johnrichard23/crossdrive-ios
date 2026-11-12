/// What a screen that loads data is showing. Empty is `loaded` with an empty
/// collection, so a screen has four states to design: loading, loaded,
/// failed and offline.
enum LoadState<Value: Sendable>: Sendable {
    case loading
    case loaded(Value)
    case failed(String)
    case offline

    var value: Value? {
        if case let .loaded(value) = self {
            value
        } else {
            nil
        }
    }
}

extension LoadState: Equatable where Value: Equatable {}
