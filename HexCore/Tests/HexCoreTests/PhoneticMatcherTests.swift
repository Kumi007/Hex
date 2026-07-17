import Testing
@testable import HexCore

struct PhoneticMatcherTests {
	@Test
	func normalizeStripsNonLetters() {
		#expect(PhoneticMatcher.normalize("Hex-Max, v2!") == "hexmaxv")
		#expect(PhoneticMatcher.normalize("  It's  ") == "its")
	}

	@Test
	func soundexMatchesClassicExamples() {
		#expect(PhoneticMatcher.soundex("Robert") == "R163")
		#expect(PhoneticMatcher.soundex("Rupert") == "R163")
		#expect(PhoneticMatcher.soundex("Tymczak") == "T522")
	}

	@Test
	func levenshteinBasics() {
		#expect(PhoneticMatcher.levenshtein("kitten", "sitting") == 3)
		#expect(PhoneticMatcher.levenshtein("same", "same") == 0)
		#expect(PhoneticMatcher.levenshtein("", "abc") == 3)
	}

	@Test
	func matchesNearMisses() {
		// Shared-prefix path: last sound wrong, strong common start "hexma".
		#expect(PhoneticMatcher.isMatch(heard: "hex maps", term: "Hex Max"))
		// Tight-distance path: two small internal edits.
		#expect(PhoneticMatcher.isMatch(heard: "and tropic", term: "Anthropic"))
		// Single-letter slip in a long term.
		#expect(PhoneticMatcher.isMatch(heard: "kubernetis", term: "Kubernetes"))
	}

	@Test
	func canonicalizesExactButDifferentCasing() {
		#expect(PhoneticMatcher.isMatch(heard: "anthropic", term: "Anthropic"))
		#expect(PhoneticMatcher.isMatch(heard: "hex max", term: "Hex Max"))
	}

	@Test
	func rejectsUnrelatedAndRiskyWords() {
		// Real word that merely rhymes — must not be swallowed.
		#expect(!PhoneticMatcher.isMatch(heard: "atrophic", term: "Anthropic"))
		// Ordinary short words never match a longer term.
		#expect(!PhoneticMatcher.isMatch(heard: "the", term: "Anthropic"))
		#expect(!PhoneticMatcher.isMatch(heard: "hello", term: "Kubernetes"))
	}

	@Test
	func shortTermsRequireExactMatch() {
		// Terms under 4 letters only match exactly (avoids corrupting speech).
		#expect(PhoneticMatcher.isMatch(heard: "max", term: "Max"))
		#expect(!PhoneticMatcher.isMatch(heard: "mac", term: "Max"))
	}
}
