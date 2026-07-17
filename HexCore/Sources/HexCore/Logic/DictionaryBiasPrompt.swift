import Foundation

/// Builds the initial-prompt biasing text handed to Whisper's decoder so it is
/// primed to produce the user's dictionary terms. Whisper treats the prompt as
/// prior context, which nudges spelling of proper nouns and jargon.
public enum DictionaryBiasPrompt {
	/// Soft cap so the prompt never crowds out the decoder's context budget.
	public static let maxTerms = 100

	/// Returns a glossary-style prompt string, or nil when there are no terms.
	public static func build(from entries: [DictionaryEntry]) -> String? {
		let terms = DictionaryEntry.activeTerms(from: entries)
		guard !terms.isEmpty else { return nil }

		// De-duplicate case-insensitively while preserving order and canonical casing.
		var seen = Set<String>()
		var unique: [String] = []
		for term in terms {
			let key = term.lowercased()
			if seen.insert(key).inserted {
				unique.append(term)
			}
		}

		let limited = unique.prefix(maxTerms)
		return "Glossary: " + limited.joined(separator: ", ") + "."
	}
}
