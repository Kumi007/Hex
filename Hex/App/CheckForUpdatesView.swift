import Combine
import ComposableArchitecture
import Inject
import Sparkle
import SwiftUI

@Observable
@MainActor
final class CheckForUpdatesViewModel {
	init() {
		// Disable silent background updates. Sparkle must never swap in a
		// differently-signed build on its own; updates are manual-only via the
		// "Check for Updates…" button. Setting these here overrides any value a
		// user previously persisted by answering Sparkle's first-run prompt, so
		// the Info.plist defaults (SUEnableAutomaticChecks/SUAutomaticallyUpdate
		// = false) can't be undone by stale UserDefaults.
		controller.updater.automaticallyChecksForUpdates = false
		controller.updater.automaticallyDownloadsUpdates = false

		anyCancellable = controller.updater.publisher(for: \.canCheckForUpdates)
			.sink(receiveValue: { self.canCheckForUpdates = $0 })
	}

	static let shared = CheckForUpdatesViewModel()

	let controller = SPUStandardUpdaterController(
		startingUpdater: true,
		updaterDelegate: nil,
		userDriverDelegate: nil
	)

	var anyCancellable: AnyCancellable?

	var canCheckForUpdates = false

	func checkForUpdates() {
		controller.updater.checkForUpdates()
	}
}

struct CheckForUpdatesView: View {
	@State var viewModel = CheckForUpdatesViewModel.shared
	@ObserveInjection var inject

	var body: some View {
		Button("Check for Updates…", action: viewModel.checkForUpdates)
			.disabled(!viewModel.canCheckForUpdates)
			.enableInjection()
	}
}
