import AppKit
import CoreServices
import JunkdrawerCore
import os

/// Looks words up in the macOS dictionary off the main thread. Each look-up
/// cancels the one before, so typing never waits on the dictionary.
@MainActor
final class DictionarySource {
   /// Completions defined per look-up.
   nonisolated static let completionLimit = 20

   private var task: Task<Void, Never>?

   /// Calls `then` on the main actor with what was found for `text`, unless
   /// another look-up started in the meantime.
   func lookUp(_ text: String, then: @escaping @MainActor ([Lookup]) -> Void) {
      task?.cancel()
      task = Task {
         let found = await Task.detached(priority: .userInitiated) { Self.lookups(text) }.value
         guard !Task.isCancelled, let found else { return }
         then(found)
      }
   }

   func cancel() {
      task?.cancel()
      task = nil
   }

   /// The query's own entry, then the completions' entries, and guesses
   /// only when neither found anything. Nil when cancelled on the way.
   /// Dictionary Services finds the entry of an inflected word itself, so
   /// "launched" gives "launch".
   nonisolated static func lookups(_ text: String) -> [Lookup]? {
      let start = Date()
      var found = definition(of: text).map { [Lookup(word: text, text: $0, source: .query)] } ?? []
      let isWord = !text.contains(" ")
      if isWord {
         let completions = checked(text) { $0.completions(forPartialWordRange: $1, in: text, language: nil, inSpellDocumentWithTag: 0) }
         if Task.isCancelled { return nil }
         found += completions
            .filter { !$0.contains("'") && $0 != text }
            .prefix(completionLimit)
            .compactMap { word in definition(of: word).map { Lookup(word: word, text: $0, source: .completion) } }
      }
      if found.isEmpty, isWord {
         if Task.isCancelled { return nil }
         let guesses = checked(text) { $0.guesses(forWordRange: $1, in: text, language: nil, inSpellDocumentWithTag: 0) }
         found = guesses.compactMap { word in definition(of: word).map { Lookup(word: word, text: $0, source: .guess) } }
      }
      let elapsed = Int(Date().timeIntervalSince(start) * 1000)
      Logger.app.debug("looked up \(text, privacy: .public): \(found.count, privacy: .public) entries in \(elapsed, privacy: .public) ms")
      return Task.isCancelled ? nil : found
   }

   /// A spell-checker call over the whole of `text`.
   nonisolated private static func checked(_ text: String, _ call: (NSSpellChecker, NSRange) -> [String]?) -> [String] {
      call(NSSpellChecker.shared, NSRange(location: 0, length: (text as NSString).length)) ?? []
   }

   /// The text of the entry Dictionary Services finds for `word`, if any.
   nonisolated private static func definition(of word: String) -> String? {
      let length = (word as NSString).length
      guard length > 0 else { return nil }
      return DCSCopyTextDefinition(nil, word as CFString, CFRange(location: 0, length: length))?.takeRetainedValue() as String?
   }
}
