import Foundation

/// Links that leave the app from a trip: Apple Maps and the dialler.
enum TripLinks {
    /// CrossDrive's Facebook page on Messenger.
    static let messenger = URL(string: "https://m.me/61555548324105")

    /// Apple Maps over HTTPS; no location permission is needed to open it.
    static func maps(latitude: Double?, longitude: Double?, name: String) -> URL? {
        guard let latitude, let longitude else { return nil }
        var parts = URLComponents(string: "https://maps.apple.com/")
        parts?.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: name),
        ]
        return parts?.url
    }

    /// Only digits and a leading plus reach the dialler.
    static func call(_ phone: String?) -> URL? {
        guard let phone else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(digits)")
    }
}
