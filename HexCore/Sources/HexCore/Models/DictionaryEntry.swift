import Foundation

/// A word or phrase the user has taught Hex — a proper noun, brand name, or
/// piece of jargon (e.g. "Hex Max", "Kubernetes", "Anthropic").
///
/// Unlike `WordRemapping` (which replaces an *exact* string the user already
/// knows the recognizer gets wrong), a dictionary entry is proactive: Hex
/// biases recognition toward the term where the engine allows it, and — on
/// every engine — snaps phonetically-similar mis-hearings back onto the
/// canonical spelling. So a never-before-heard word doesn't get frozen as the
/// recognizer's best guess at its sound.
public struct DictionaryEntry: Codable, Equatable, Identifiable, Sendable {
	public var id: UUID
	public var isEnabled: Bool
	/// The canonical spelling/casing Hex should produce.
	public var term: String

	public init(
		id: UUID = UUID(),
		isEnabled: Bool = true,
		term: String
	) {
		self.id = id
		self.isEnabled = isEnabled
		self.term = term
	}

	/// Enabled entries with a non-empty, trimmed term.
	public static func activeTerms(from entries: [DictionaryEntry]) -> [String] {
		entries
			.filter(\.isEnabled)
			.map { $0.term.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
	}
}
