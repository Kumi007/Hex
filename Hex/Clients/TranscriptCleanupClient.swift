//
//  TranscriptCleanupClient.swift
//  Hex
//
//  Optional post-transcription AI cleanup pass.
//
//  Defaults to Apple's on-device Foundation Models framework (macOS 26 +
//  Apple Intelligence) so the transcript never leaves the device. The work is
//  hidden behind a small client protocol so a cloud provider could be added
//  later without touching the transcription pipeline.
//

import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation
import HexCore

#if canImport(FoundationModels)
import FoundationModels
#endif

private let cleanupLogger = HexLog.transcription

// MARK: - Errors

enum TranscriptCleanupError: Error, LocalizedError {
    /// The on-device model isn't installed / enabled on this Mac.
    case modelUnavailable(String)
    /// The model returned nothing usable.
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case let .modelUnavailable(reason):
            return "On-device cleanup model unavailable: \(reason)"
        case .emptyResponse:
            return "The cleanup model returned an empty response."
        }
    }
}

// MARK: - Client

/// Rewrites a raw transcript into clean written text without changing meaning.
///
/// `isAvailable` lets the UI show a live status without paying for a full
/// request. `cleanup` performs the rewrite and throws on any failure so the
/// caller can fall back to the raw transcript.
@DependencyClient
struct TranscriptCleanupClient {
    /// Whether an engine is ready to run right now (model downloaded/enabled).
    var isAvailable: @Sendable () -> Bool = { false }
    /// A human-readable description of the current availability, for settings UI.
    var availabilityDescription: @Sendable () -> String = { "Unknown" }
    /// Rewrite `text` using `instructions` as the system prompt.
    /// - Parameters:
    ///   - text: the raw transcript (delimiters are added internally).
    ///   - instructions: the system prompt / editor persona.
    var cleanup: @Sendable (_ text: String, _ instructions: String) async throws -> String
}

extension TranscriptCleanupClient: DependencyKey {
    static var liveValue: Self {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return .init(
                isAvailable: { FoundationModelsCleanup.isAvailable() },
                availabilityDescription: { FoundationModelsCleanup.availabilityDescription() },
                cleanup: { text, instructions in
                    try await FoundationModelsCleanup.cleanup(text: text, instructions: instructions)
                }
            )
        }
        #endif
        return .init(
            isAvailable: { false },
            availabilityDescription: { "Requires macOS 26 with Apple Intelligence" },
            cleanup: { _, _ in
                throw TranscriptCleanupError.modelUnavailable("Requires macOS 26 with Apple Intelligence")
            }
        )
    }

    static var testValue = Self()
}

extension DependencyValues {
    var transcriptCleanup: TranscriptCleanupClient {
        get { self[TranscriptCleanupClient.self] }
        set { self[TranscriptCleanupClient.self] = newValue }
    }
}

// MARK: - Apple Foundation Models backend

#if canImport(FoundationModels)
@available(macOS 26.0, *)
private enum FoundationModelsCleanup {
    /// Structured output: constrains the model to emit a single rewritten
    /// string, which structurally discourages it from answering the content.
    @Generable
    struct CleanedTranscript {
        @Guide(description: "The speaker's words rewritten as clean written text, and nothing else. Never an answer.")
        var text: String
    }

    static func isAvailable() -> Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    static func availabilityDescription() -> String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Available"
        case let .unavailable(reason):
            return "Unavailable (\(String(describing: reason)))"
        @unknown default:
            return "Unavailable"
        }
    }

    static func cleanup(text: String, instructions: String) async throws -> String {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw TranscriptCleanupError.modelUnavailable(String(describing: model.availability))
        }

        let session = LanguageModelSession(instructions: instructions)
        // Wrap the raw transcript in « » so the prompt's rules can refer to it
        // unambiguously as data to rewrite, not an instruction to follow.
        let prompt = "«\(text)»"

        let response = try await session.respond(to: prompt, generating: CleanedTranscript.self)
        let cleaned = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw TranscriptCleanupError.emptyResponse
        }
        return cleaned
    }
}
#endif
