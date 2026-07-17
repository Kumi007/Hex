import Testing
@testable import HexCore

struct DictionaryApplierTests {
	private func entries(_ terms: [String], enabled: Bool = true) -> [DictionaryEntry] {
		terms.map { DictionaryEntry(isEnabled: enabled, term: $0) }
	}

	@Test
	func correctsMultiWordMisHearingAndKeepsPunctuation() {
		let result = DictionaryApplier.apply(
			"Let's try hex maps today.",
			entries: entries(["Hex Max"])
		)
		#expect(result == "Let's try Hex Max today.")
	}

	@Test
	func canonicalizesCasingOnExactMatch() {
		let result = DictionaryApplier.apply("i love hex max", entries: entries(["Hex Max"]))
		#expect(result == "i love Hex Max")
	}

	@Test
	func correctsSingleWordNearMiss() {
		let result = DictionaryApplier.apply(
			"we use kubernetis daily",
			entries: entries(["Kubernetes"])
		)
		#expect(result == "we use Kubernetes daily")
	}

	@Test
	func leavesOrdinaryWordsAlone() {
		// "atrophic" is a real word that must not become "Anthropic".
		let input = "the therapy was atrophic"
		#expect(DictionaryApplier.apply(input, entries: entries(["Anthropic"])) == input)
	}

	@Test
	func ignoresDisabledEntries() {
		let input = "hex maps"
		#expect(DictionaryApplier.apply(input, entries: entries(["Hex Max"], enabled: false)) == input)
	}

	@Test
	func noEntriesIsNoOp() {
		let input = "nothing to change here"
		#expect(DictionaryApplier.apply(input, entries: []) == input)
	}

	@Test
	func biasPromptBuildsGlossary() {
		let prompt = DictionaryBiasPrompt.build(from: entries(["Hex Max", "Anthropic"]))
		#expect(prompt == "Glossary: Hex Max, Anthropic.")
		#expect(DictionaryBiasPrompt.build(from: []) == nil)
	}
}
