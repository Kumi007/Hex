import Foundation

/// Applies the proactive dictionary to a transcript on any engine: it scans for
/// runs of words that are phonetically close to a user-declared term and snaps
/// them onto the canonical spelling. This is the universal safety net that makes
/// the dictionary effective even on engines that can't be biased up front.
public enum DictionaryApplier {
	private struct WordToken {
		let range: Range<String.Index>
		let text: String
	}

	private struct Candidate {
		let wordStart: Int
		let wordCount: Int
		let charRange: Range<String.Index>
		let term: String
	}

	public static func apply(_ text: String, entries: [DictionaryEntry]) -> String {
		let terms = DictionaryEntry.activeTerms(from: entries)
		guard !terms.isEmpty, !text.isEmpty else { return text }

		let words = tokenize(text)
		guard !words.isEmpty else { return text }

		var candidates: [Candidate] = []

		for term in terms {
			let termWordCount = max(1, term.split(whereSeparator: { $0.isWhitespace }).count)
			// Window sizes to try: same word count as the term, and (for multi-word
			// terms) a single blob token that swallowed the whole phrase.
			var windowSizes: Set<Int> = [termWordCount]
			if termWordCount > 1 { windowSizes.insert(1) }

			for size in windowSizes where size <= words.count {
				for start in 0...(words.count - size) {
					let window = words[start..<(start + size)]
					let joined = window.map(\.text).joined(separator: " ")
					guard PhoneticMatcher.isMatch(heard: joined, term: term) else { continue }

					let charRange = window.first!.range.lowerBound..<window.last!.range.upperBound
					// Skip if the span is already exactly the canonical term.
					if String(text[charRange]) == term { continue }

					candidates.append(
						Candidate(wordStart: start, wordCount: size, charRange: charRange, term: term)
					)
				}
			}
		}

		guard !candidates.isEmpty else { return text }

		// Resolve overlaps greedily: earliest first, preferring longer coverage.
		let ordered = candidates.sorted {
			if $0.wordStart != $1.wordStart { return $0.wordStart < $1.wordStart }
			return $0.wordCount > $1.wordCount
		}

		var accepted: [Candidate] = []
		var nextFreeWord = 0
		for candidate in ordered where candidate.wordStart >= nextFreeWord {
			accepted.append(candidate)
			nextFreeWord = candidate.wordStart + candidate.wordCount
		}

		// Rebuild by slicing the original text between accepted (non-overlapping,
		// left-to-right) ranges, so only the original string's own indices are used.
		var output = ""
		var cursor = text.startIndex
		for candidate in accepted.sorted(by: { $0.charRange.lowerBound < $1.charRange.lowerBound }) {
			guard candidate.charRange.lowerBound >= cursor else { continue }
			output.append(contentsOf: text[cursor..<candidate.charRange.lowerBound])
			output.append(candidate.term)
			cursor = candidate.charRange.upperBound
		}
		output.append(contentsOf: text[cursor..<text.endIndex])
		return output
	}

	/// Splits into word tokens (letters/digits/apostrophes), keeping the original
	/// ranges so surrounding punctuation and spacing are preserved on replace.
	private static func tokenize(_ text: String) -> [WordToken] {
		var tokens: [WordToken] = []
		var index = text.startIndex

		func isWordScalar(_ ch: Character) -> Bool {
			ch.isLetter || ch.isNumber || ch == "'" || ch == "\u{2019}"
		}

		while index < text.endIndex {
			if isWordScalar(text[index]) {
				let start = index
				while index < text.endIndex, isWordScalar(text[index]) {
					index = text.index(after: index)
				}
				tokens.append(WordToken(range: start..<index, text: String(text[start..<index])))
			} else {
				index = text.index(after: index)
			}
		}
		return tokens
	}
}
