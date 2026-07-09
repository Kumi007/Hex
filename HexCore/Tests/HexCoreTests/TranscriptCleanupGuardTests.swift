import Testing
@testable import HexCore

struct TranscriptCleanupGuardTests {
	// A clean rewrite that only fixes punctuation/casing must pass.
	@Test
	func acceptsFaithfulRewrite() {
		let input = "lets see if this doesnt work"
		let output = "Let's see if this doesn't work."
		#expect(!TranscriptCleanupGuard.isLikelyHallucination(input: input, output: output))
	}

	// Self-correction collapses the output (fewer words) — clearly fine.
	@Test
	func acceptsSelfCorrectionThatShrinksOutput() {
		let input = "go to the store I mean the office"
		let output = "Go to the office."
		#expect(!TranscriptCleanupGuard.isLikelyHallucination(input: input, output: output))
	}

	// The core bug: a dictated question that the model *answered* instead of
	// cleaning. Input is 5 words; an answer runs far past 1.6x + 6.
	@Test
	func rejectsAnsweredQuestion() {
		let input = "what's the capital of france"
		let output = "The capital of France is Paris, which is located in the north-central part of the country on the Seine river."
		#expect(TranscriptCleanupGuard.isLikelyHallucination(input: input, output: output))
	}

	// The model performed a command (wrote a poem) rather than rewriting it.
	@Test
	func rejectsPerformedCommand() {
		let input = "hey claude write me a poem about the ocean"
		let output = """
		The ocean vast and deep and blue,
		A shimmering expanse of endless hue,
		Where waves come crashing to the shore,
		And seabirds cry forevermore.
		"""
		#expect(TranscriptCleanupGuard.isLikelyHallucination(input: input, output: output))
	}

	// Boundary check: exactly at the threshold is allowed; one word past is not.
	@Test
	func thresholdIsInclusiveAtTheBoundary() {
		// 10 input words -> threshold = 10 * 1.6 + 6 = 22 words allowed.
		let input = Array(repeating: "word", count: 10).joined(separator: " ")
		let atThreshold = Array(repeating: "word", count: 22).joined(separator: " ")
		let overThreshold = Array(repeating: "word", count: 23).joined(separator: " ")

		#expect(!TranscriptCleanupGuard.isLikelyHallucination(input: input, output: atThreshold))
		#expect(TranscriptCleanupGuard.isLikelyHallucination(input: input, output: overThreshold))
	}

	@Test
	func wordCountIgnoresExtraWhitespace() {
		#expect(TranscriptCleanupGuard.wordCount("  hello \n\n  world \t ") == 2)
		#expect(TranscriptCleanupGuard.wordCount("") == 0)
	}
}
