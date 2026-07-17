import Foundation

/// Phonetic + edit-distance primitives used by the proactive dictionary to
/// decide whether a heard token (or run of tokens) is a mis-hearing of a
/// user-declared term.
///
/// The design goal is to catch mis-hearings of *unfamiliar* words (proper
/// nouns, jargon) while being conservative enough not to corrupt ordinary
/// speech. Two independent signals are combined:
///   1. A Soundex-style phonetic key (are they built from similar sounds?).
///   2. Levenshtein edit distance on the letters-only normalisation.
public enum PhoneticMatcher {
	/// Lowercase, letters only (drops spaces, punctuation, digits, apostrophes).
	public static func normalize(_ text: String) -> String {
		var result = ""
		for character in text.lowercased() where character.isLetter {
			result.append(character)
		}
		return result
	}

	/// Classic Soundex code (first letter + up to three encoded consonants).
	/// Returns an uppercased 4-char code, or "" for input with no letters.
	public static func soundex(_ text: String) -> String {
		let letters = Array(normalize(text))
		guard let first = letters.first else { return "" }

		func code(_ ch: Character) -> Character? {
			switch ch {
			case "b", "f", "p", "v": return "1"
			case "c", "g", "j", "k", "q", "s", "x", "z": return "2"
			case "d", "t": return "3"
			case "l": return "4"
			case "m", "n": return "5"
			case "r": return "6"
			default: return nil // vowels + h, w, y
			}
		}

		var result = String(first).uppercased()
		var previousCode = code(first)

		for ch in letters.dropFirst() {
			let current = code(ch)
			if let current, current != previousCode {
				result.append(current)
				if result.count == 4 { break }
			}
			// h and w do not reset the "previous code" adjacency rule; vowels do.
			if ch != "h", ch != "w" {
				previousCode = current
			}
		}

		if result.count < 4 {
			result += String(repeating: "0", count: 4 - result.count)
		}
		return result
	}

	/// Standard Levenshtein edit distance between two strings.
	public static func levenshtein(_ a: String, _ b: String) -> Int {
		let s = Array(a)
		let t = Array(b)
		if s.isEmpty { return t.count }
		if t.isEmpty { return s.count }

		var previous = Array(0...t.count)
		var current = [Int](repeating: 0, count: t.count + 1)

		for i in 1...s.count {
			current[0] = i
			for j in 1...t.count {
				let cost = s[i - 1] == t[j - 1] ? 0 : 1
				current[j] = min(
					previous[j] + 1,      // deletion
					current[j - 1] + 1,   // insertion
					previous[j - 1] + cost // substitution
				)
			}
			swap(&previous, &current)
		}
		return previous[t.count]
	}

	/// Length of the shared leading run of characters.
	public static func commonPrefixLength(_ a: String, _ b: String) -> Int {
		var count = 0
		var i = a.startIndex
		var j = b.startIndex
		while i < a.endIndex, j < b.endIndex, a[i] == b[j] {
			count += 1
			i = a.index(after: i)
			j = b.index(after: j)
		}
		return count
	}

	/// Whether `heard` is close enough to `term` to be treated as a mis-hearing.
	///
	/// `heard`/`term` may be multi-word; both are reduced to letters-only before
	/// comparison. Exact normalized matches count (so casing/spelling gets
	/// canonicalised). Very short terms are rejected to avoid false positives on
	/// ordinary short words.
	///
	/// The thresholds are deliberately asymmetric to protect precision: a small
	/// distance always matches, but a medium distance only matches when a second
	/// signal agrees — a strong shared prefix or an identical Soundex key. This
	/// is what lets "hex maps" → "Hex Max" through (shared prefix "hexma") while
	/// keeping the real word "atrophic" from being rewritten to "Anthropic".
	public static func isMatch(heard: String, term: String) -> Bool {
		let h = normalize(heard)
		let t = normalize(term)

		// Require some substance in the target term; short words are too risky.
		guard t.count >= 4, h.count >= 3 else { return h == t && !t.isEmpty }

		if h == t { return true }

		// Reject wildly different lengths early (e.g. one token vs a long term).
		let ratio = Double(h.count) / Double(t.count)
		guard ratio >= 0.5, ratio <= 1.8 else { return false }

		let distance = levenshtein(h, t)

		// Small edit distance is enough on its own.
		let tight = max(1, Int((Double(t.count) * 0.25).rounded(.down)))
		if distance <= tight { return true }

		// Medium distance needs corroboration from a second signal.
		let cap = max(2, Int((Double(t.count) * 0.34).rounded(.down)))
		if distance <= cap {
			let strongPrefix = Int((Double(t.count) * 0.5).rounded(.up))
			if commonPrefixLength(h, t) >= strongPrefix { return true }
			if soundex(h) == soundex(t) { return true }
		}

		return false
	}
}
