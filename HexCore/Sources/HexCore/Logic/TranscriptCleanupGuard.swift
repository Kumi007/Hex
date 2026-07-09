import Foundation

/// Deterministic backstop for the optional AI transcript cleanup pass.
///
/// A cleanup model is only ever supposed to *rewrite* the words that were
/// spoken. When it instead answers a dictated question or command (e.g. the
/// speaker says "what's the capital of France" and the model replies "Paris,
/// the capital of France, is…"), the output balloons well past the input.
///
/// This guard catches that failure mode by comparing word counts: if the
/// cleaned output is dramatically longer than the raw transcript it is treated
/// as a hallucination and the caller should discard it in favour of the raw
/// (deterministic-only) transcript.
public enum TranscriptCleanupGuard {
	/// Multiplier applied to the input word count before the additive slack.
	public static let growthMultiplier: Double = 1.6
	/// Fixed number of extra words tolerated on top of the multiplied count.
	/// Keeps very short utterances from tripping the guard when punctuation or
	/// a legitimately expanded contraction adds a word or two.
	public static let additiveSlack: Int = 6

	/// Returns `true` when `output` looks like the model answered/expanded the
	/// transcript rather than merely cleaning it.
	///
	/// The threshold is `inputWords * growthMultiplier + additiveSlack`; an
	/// output whose word count strictly exceeds that is rejected.
	public static func isLikelyHallucination(input: String, output: String) -> Bool {
		let inputWords = wordCount(input)
		let outputWords = wordCount(output)

		// An empty input can't meaningfully bound the output; let the caller's
		// separate empty-output check handle those edge cases.
		guard inputWords > 0 else { return outputWords > additiveSlack }

		let threshold = Double(inputWords) * growthMultiplier + Double(additiveSlack)
		return Double(outputWords) > threshold
	}

	/// Counts whitespace-separated word tokens, ignoring empty runs.
	public static func wordCount(_ text: String) -> Int {
		text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
	}
}
