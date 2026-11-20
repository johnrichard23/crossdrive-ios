import SafariServices
import SwiftUI

/// The system web view, for a page that lives on the web (a film). UIKit is
/// used here because SwiftUI has no web view with the system's own controls.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_: SFSafariViewController, context _: Context) {}
}
