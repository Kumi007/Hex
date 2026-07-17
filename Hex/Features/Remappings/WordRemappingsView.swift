import ComposableArchitecture
import HexCore
import Inject
import SwiftUI

struct WordRemappingsView: View {
	@ObserveInjection var inject
	@Bindable var store: StoreOf<SettingsFeature>
	@Dependency(\.transcriptCleanup) private var cleanupClient
	@FocusState private var isScratchpadFocused: Bool
	@State private var activeSection: ModificationSection = .dictionary

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				VStack(alignment: .leading, spacing: 6) {
					Text("Transcript Modifications")
						.font(.title2.bold())
					Text("Remove or replace words in every transcript. Removals use regex patterns and match whole words.")
						.font(.callout)
						.foregroundStyle(.secondary)
				}

				GroupBox {
					VStack(alignment: .leading, spacing: 10) {
						HStack(spacing: 12) {
							VStack(alignment: .leading, spacing: 4) {
								Text("Scratchpad")
									.font(.caption.weight(.semibold))
									.foregroundStyle(.secondary)
								TextField("Say something…", text: $store.remappingScratchpadText)
									.textFieldStyle(.roundedBorder)
									.focused($isScratchpadFocused)
									.onChange(of: isScratchpadFocused) { _, newValue in
										store.send(.setRemappingScratchpadFocused(newValue))
									}
							}

							VStack(alignment: .leading, spacing: 4) {
								Text("Preview")
									.font(.caption.weight(.semibold))
									.foregroundStyle(.secondary)
								Text(previewText.isEmpty ? "—" : previewText)
									.font(.body)
									.frame(maxWidth: .infinity, alignment: .leading)
									.padding(.horizontal, 8)
									.padding(.vertical, 6)
									.background(
										RoundedRectangle(cornerRadius: 6)
											.fill(Color(nsColor: .controlBackgroundColor))
									)
							}
						}
					}
					.padding(.vertical, 6)
				}

				aiCleanupSection

				Picker("Modification Type", selection: $activeSection) {
					ForEach(ModificationSection.allCases) { section in
						Text(section.title).tag(section)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()

				switch activeSection {
				case .dictionary:
					dictionarySection
				case .removals:
					removalsSection
				case .remappings:
					remappingsSection
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding()
		}
		.onDisappear {
			store.send(.setRemappingScratchpadFocused(false))
		}
		.enableInjection()
	}

	private var aiCleanupSection: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 10) {
				Toggle(
					"Enable AI Cleanup",
					isOn: Binding(
						get: { store.hexSettings.aiCleanupEnabled },
						set: { store.send(.setAICleanupEnabled($0)) }
					)
				)
				.toggleStyle(.checkbox)

				availabilityStatus

				if store.hexSettings.aiCleanupEnabled {
					Divider()

					VStack(alignment: .leading, spacing: 6) {
						HStack {
							Text("Instructions")
								.font(.caption.weight(.semibold))
								.foregroundStyle(.secondary)
							Spacer()
							Button("Reset to recommended") {
								store.send(.resetAICleanupPrompt)
							}
							.buttonStyle(.borderless)
							.font(.caption)
						}

						TextEditor(
							text: Binding(
								get: { store.hexSettings.aiCleanupPrompt },
								set: { store.send(.setAICleanupPrompt($0)) }
							)
						)
						.font(.system(.callout, design: .monospaced))
						.frame(minHeight: 140, maxHeight: 220)
						.padding(6)
						.background(
							RoundedRectangle(cornerRadius: 6)
								.fill(Color(nsColor: .textBackgroundColor))
						)
						.overlay(
							RoundedRectangle(cornerRadius: 6)
								.stroke(Color(nsColor: .separatorColor))
						)

						Text("The transcript is sent wrapped in « » so the model rewrites your words instead of answering them.")
							.settingsCaption()
					}
				}
			}
			.padding(.vertical, 4)
		} label: {
			VStack(alignment: .leading, spacing: 4) {
				Text("AI Cleanup")
					.font(.headline)
				Text("Polish each transcript with Apple's on-device model: spoken punctuation, self-corrections, filler removal — fully private, never leaves your Mac.")
					.settingsCaption()
			}
		}
	}

	@ViewBuilder
	private var availabilityStatus: some View {
		let available = cleanupClient.isAvailable()
		HStack(spacing: 6) {
			Image(systemName: available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
				.foregroundStyle(available ? Color.green : Color.orange)
			Text(available
				? "On-device model ready"
				: "On-device model unavailable — \(cleanupClient.availabilityDescription()). Transcripts paste uncleaned.")
				.font(.caption)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
	}

	private var dictionarySection: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 10) {
				Toggle(
					"Enable Dictionary",
					isOn: Binding(
						get: { store.hexSettings.dictionaryEnabled },
						set: { store.send(.setDictionaryEnabled($0)) }
					)
				)
				.toggleStyle(.checkbox)

				dictionaryColumnHeaders

				LazyVStack(alignment: .leading, spacing: 6) {
					ForEach(store.hexSettings.dictionaryEntries) { entry in
						DictionaryRow(entry: dictionaryBinding(for: entry)) {
							store.send(.removeDictionaryEntry(entry.id))
						}
					}
				}

				HStack {
					Button {
						store.send(.addDictionaryEntry)
					} label: {
						Label("Add Word", systemImage: "plus")
					}
					Spacer()
				}
			}
			.padding(.vertical, 4)
		} label: {
			VStack(alignment: .leading, spacing: 4) {
				Text("Dictionary")
					.font(.headline)
				Text("Teach Hex special words — names, brands, jargon. On Whisper models it biases recognition up front; on every engine it snaps close-sounding mis-hearings onto your spelling.")
					.settingsCaption()
			}
		}
	}

	private var dictionaryColumnHeaders: some View {
		HStack(spacing: 8) {
			Text("On")
				.frame(width: Layout.toggleColumnWidth, alignment: .leading)
			Text("Word or phrase")
				.frame(maxWidth: .infinity, alignment: .leading)
			Spacer().frame(width: Layout.deleteColumnWidth)
		}
		.font(.caption)
		.foregroundStyle(.secondary)
		.padding(.horizontal, Layout.rowHorizontalPadding)
	}

	private func dictionaryBinding(for entry: DictionaryEntry) -> Binding<DictionaryEntry> {
		return Binding(
			get: {
				store.hexSettings.dictionaryEntries.first { $0.id == entry.id } ?? entry
			},
			set: { store.send(.updateDictionaryEntry($0)) }
		)
	}

	private var removalsSection: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 10) {
				Toggle(
					"Enable Word Removals",
					isOn: Binding(
						get: { store.hexSettings.wordRemovalsEnabled },
						set: { store.send(.setWordRemovalsEnabled($0)) }
					)
				)
					.toggleStyle(.checkbox)

				removalsColumnHeaders

				LazyVStack(alignment: .leading, spacing: 6) {
					ForEach(store.hexSettings.wordRemovals) { removal in
						RemovalRow(removal: removalBinding(for: removal)) {
							store.send(.removeWordRemoval(removal.id))
						}
					}
				}

				HStack {
					Button {
						store.send(.addWordRemoval)
					} label: {
						Label("Add Removal", systemImage: "plus")
					}
					Spacer()
				}
			}
			.padding(.vertical, 4)
		} label: {
			VStack(alignment: .leading, spacing: 4) {
				Text("Word Removals")
					.font(.headline)
				Text("Remove filler words using case-insensitive regex patterns.")
					.settingsCaption()
			}
		}
	}

	private var remappingsSection: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 10) {
				remappingsColumnHeaders

				LazyVStack(alignment: .leading, spacing: 6) {
					ForEach(store.hexSettings.wordRemappings) { remapping in
						RemappingRow(remapping: remappingBinding(for: remapping)) {
							store.send(.removeWordRemapping(remapping.id))
						}
					}
				}

				HStack {
					Button {
						store.send(.addWordRemapping)
					} label: {
						Label("Add Remapping", systemImage: "plus")
					}
					Spacer()
				}
			}
			.padding(.vertical, 4)
		} label: {
			VStack(alignment: .leading, spacing: 4) {
				Text("Word Remappings")
					.font(.headline)
				Text("Replace specific words in every transcript. Matches whole words, case-insensitive, in order.")
					.settingsCaption()
			}
		}
	}

	private var removalsColumnHeaders: some View {
		HStack(spacing: 8) {
			Text("On")
				.frame(width: Layout.toggleColumnWidth, alignment: .leading)
			Text("Pattern")
				.frame(maxWidth: .infinity, alignment: .leading)
			Spacer().frame(width: Layout.deleteColumnWidth)
		}
		.font(.caption)
		.foregroundStyle(.secondary)
		.padding(.horizontal, Layout.rowHorizontalPadding)
	}

	private var remappingsColumnHeaders: some View {
		HStack(spacing: 8) {
			Text("On")
				.frame(width: Layout.toggleColumnWidth, alignment: .leading)
			Text("Match")
				.frame(maxWidth: .infinity, alignment: .leading)
			Image(systemName: "arrow.right")
				.font(.caption)
				.foregroundStyle(.secondary)
				.frame(width: Layout.arrowColumnWidth)
			Text("Replace")
				.frame(maxWidth: .infinity, alignment: .leading)
			Spacer().frame(width: Layout.deleteColumnWidth)
		}
		.font(.caption)
		.foregroundStyle(.secondary)
		.padding(.horizontal, Layout.rowHorizontalPadding)
	}

	private func removalBinding(for removal: WordRemoval) -> Binding<WordRemoval> {
		return Binding(
			get: {
				store.hexSettings.wordRemovals.first { $0.id == removal.id } ?? removal
			},
			set: { store.send(.updateWordRemoval($0)) }
		)
	}

	private func remappingBinding(for remapping: WordRemapping) -> Binding<WordRemapping> {
		return Binding(
			get: {
				store.hexSettings.wordRemappings.first { $0.id == remapping.id } ?? remapping
			},
			set: { store.send(.updateWordRemapping($0)) }
		)
	}

	private var previewText: String {
		var output = store.remappingScratchpadText
		// Mirror the live pipeline order: dictionary → removals → remappings.
		if store.hexSettings.dictionaryEnabled {
			output = DictionaryApplier.apply(output, entries: store.hexSettings.dictionaryEntries)
		}
		if store.hexSettings.wordRemovalsEnabled {
			output = WordRemovalApplier.apply(output, removals: store.hexSettings.wordRemovals)
		}
		output = WordRemappingApplier.apply(output, remappings: store.hexSettings.wordRemappings)
		return output
	}
}

private struct DictionaryRow: View {
	@Binding var entry: DictionaryEntry
	var onDelete: () -> Void

	var body: some View {
		HStack(spacing: 8) {
			Toggle("", isOn: $entry.isEnabled)
				.labelsHidden()
				.toggleStyle(.checkbox)
				.frame(width: Layout.toggleColumnWidth, alignment: .leading)

			TextField("e.g. Hex Max", text: $entry.term)
				.textFieldStyle(.roundedBorder)
				.frame(maxWidth: .infinity, alignment: .leading)

			Button(role: .destructive, action: onDelete) {
				Image(systemName: "trash")
			}
			.buttonStyle(.borderless)
			.frame(width: Layout.deleteColumnWidth)
		}
		.padding(.horizontal, Layout.rowHorizontalPadding)
		.padding(.vertical, Layout.rowVerticalPadding)
		.frame(maxWidth: .infinity)
		.background(
			RoundedRectangle(cornerRadius: Layout.rowCornerRadius)
				.fill(Color(nsColor: .controlBackgroundColor))
		)
	}
}

private struct RemovalRow: View {
	@Binding var removal: WordRemoval
	var onDelete: () -> Void

	var body: some View {
		HStack(spacing: 8) {
			Toggle("", isOn: $removal.isEnabled)
				.labelsHidden()
				.toggleStyle(.checkbox)
				.frame(width: Layout.toggleColumnWidth, alignment: .leading)

			TextField("Regex Pattern", text: $removal.pattern)
				.textFieldStyle(.roundedBorder)

			Button(role: .destructive, action: onDelete) {
				Image(systemName: "trash")
			}
			.buttonStyle(.borderless)
			.frame(width: Layout.deleteColumnWidth)
		}
		.padding(.horizontal, Layout.rowHorizontalPadding)
		.padding(.vertical, Layout.rowVerticalPadding)
		.frame(maxWidth: .infinity)
		.background(
			RoundedRectangle(cornerRadius: Layout.rowCornerRadius)
				.fill(Color(nsColor: .controlBackgroundColor))
		)
	}
}

private struct RemappingRow: View {
	@Binding var remapping: WordRemapping
	var onDelete: () -> Void

	var body: some View {
		HStack(spacing: 8) {
			Toggle("", isOn: $remapping.isEnabled)
				.labelsHidden()
				.toggleStyle(.checkbox)
				.frame(width: Layout.toggleColumnWidth, alignment: .leading)

			TextField("Match", text: $remapping.match)
				.textFieldStyle(.roundedBorder)
				.frame(maxWidth: .infinity, alignment: .leading)

			Image(systemName: "arrow.right")
				.foregroundStyle(.secondary)
				.frame(width: Layout.arrowColumnWidth)

			TextField("Replace", text: $remapping.replacement)
				.textFieldStyle(.roundedBorder)
				.frame(maxWidth: .infinity, alignment: .leading)

			Button(role: .destructive, action: onDelete) {
				Image(systemName: "trash")
			}
			.buttonStyle(.borderless)
			.frame(width: Layout.deleteColumnWidth)
		}
		.padding(.horizontal, Layout.rowHorizontalPadding)
		.padding(.vertical, Layout.rowVerticalPadding)
		.frame(maxWidth: .infinity)
		.background(
			RoundedRectangle(cornerRadius: Layout.rowCornerRadius)
				.fill(Color(nsColor: .controlBackgroundColor))
		)
	}
}

private enum ModificationSection: String, CaseIterable, Identifiable {
	case dictionary
	case removals
	case remappings

	var id: String { rawValue }

	var title: String {
		switch self {
		case .dictionary:
			return "Dictionary"
		case .removals:
			return "Word Removals"
		case .remappings:
			return "Word Remappings"
		}
	}
}

private enum Layout {
	static let toggleColumnWidth: CGFloat = 24
	static let deleteColumnWidth: CGFloat = 24
	static let arrowColumnWidth: CGFloat = 16
	static let rowHorizontalPadding: CGFloat = 10
	static let rowVerticalPadding: CGFloat = 6
	static let rowCornerRadius: CGFloat = 8
}
