#if DEBUG || STAGING
    import DataLayer
    import DesignSystem
    import SwiftUI

    /// What a developer or tester needs without Xcode: how the app is
    /// configured, the session, the connection, flags, every state of the
    /// sample screen, and a way to try a link or a notification tap. Built into
    /// Debug and Staging builds only.
    struct DebugMenuView: View {
        let coordinator: AppCoordinator

        @State private var scenario: DebugScenario?
        /// Changes when a flag is switched, so the toggles redraw.
        @State private var flagChanges = 0

        private var container: DependencyContainer {
            coordinator.container
        }

        private var scheme: String {
            DeepLinkRouter().scheme
        }

        var body: some View {
            List {
                Section {
                    row("Accounts", value: String(describing: container.features.authentication))
                    row("Onboarding", value: container.features.onboarding ? "on" : "off")
                    row(
                        "Onboarding placement",
                        value: String(describing: container.features.onboardingPlacement)
                    )
                } header: {
                    DSSectionHeader("Launch settings")
                } footer: {
                    Text(
                        "Change them for one run with launch arguments, for example -feature-auth required."
                    )
                }
                .dsListRows()

                Section {
                    row(
                        "Signed in as",
                        value: coordinator.session.user?.name ?? coordinator.session.user?.id ?? "nobody (guest)"
                    )
                    row("Connection", value: coordinator.isOnline ? "online" : "offline")
                } header: {
                    DSSectionHeader("State")
                }
                .dsListRows()

                Section {
                    ForEach(FeatureFlag.all, id: \.key) { flag in
                        Toggle(flag.key, isOn: binding(for: flag))
                    }
                } header: {
                    DSSectionHeader("Feature flags")
                } footer: {
                    Text(
                        "Overrides stay until you remove the app. A screen already open changes when it next appears."
                    )
                }
                .dsListRows()
                .id(flagChanges)

                Section {
                    ForEach(DebugScenario.allCases) { scenario in
                        Button(scenario.title) { self.scenario = scenario }
                    }
                } header: {
                    DSSectionHeader("Screen states")
                }
                .dsListRows()

                Section {
                    Button("Open item 3 as a link") { open("\(scheme)://items/3") }
                    Button("Simulate a notification tap (item 2)") {
                        coordinator.handlePushTap(link: "\(scheme)://items/2")
                    }
                } header: {
                    DSSectionHeader("Links and notifications")
                }
                .dsListRows()
            }
            .dsList()
            .navigationTitle("Debug menu")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $scenario) { scenario in
                SampleListView(viewModel: scenario.makeViewModel(), path: .constant([]))
            }
        }

        private func row(_ title: LocalizedStringKey, value: String) -> some View {
            LabeledContent {
                Text(verbatim: value).textRole(.body)
            } label: {
                Text(title).textRole(.body)
            }
        }

        private func open(_ text: String) {
            if let url = URL(string: text) {
                coordinator.handle(url: url)
            }
        }

        private func binding(for flag: FeatureFlag) -> Binding<Bool> {
            let flags = container.services.flags
            return Binding(
                get: { flags.isEnabled(flag) },
                set: { value in
                    (flags as? LocalFeatureFlags)?.setOverride(value, for: flag)
                    flagChanges += 1
                }
            )
        }
    }

    /// The sample screen with a fixed server reply, so each state can be seen.
    enum DebugScenario: String, CaseIterable, Identifiable {
        case loading
        case empty
        case error
        case offline

        var id: String {
            rawValue
        }

        var title: LocalizedStringKey {
            switch self {
            case .loading: "Loading"
            case .empty: "Empty"
            case .error: "Error"
            case .offline: "Offline"
            }
        }

        @MainActor
        func makeViewModel() -> SampleListViewModel {
            let client = StubHTTPClient { _ in
                switch self {
                case .loading:
                    try await Task.sleep(for: .seconds(3600))
                    return .json("[]")
                case .empty: return .json("[]")
                case .error: return .json("{}", status: 500)
                case .offline: throw NetworkError.noConnection
                }
            }
            return SampleListViewModel(api: SampleAPI(client: client))
        }
    }
#endif
