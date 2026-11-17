import Foundation

/// Which source a query searches, picked by its first character.
public enum Mode: Hashable, Sendable, CaseIterable {
   case plain
   case latex
   case unicode
   case dictionary
   case files

   /// The character that selects the mode, or nil for the plain mode.
   public var prefix: Character? {
      switch self {
      case .plain: nil
      case .latex: "\\"
      case .unicode: ":"
      case .dictionary: "?"
      case .files: "/"
      }
   }
}

/// A query as typed, split into its mode and the text after the prefix.
public struct Query: Hashable, Sendable {
   public let mode: Mode
   /// The text without the prefix, trimmed of surrounding whitespace.
   public let text: String

   public init(_ raw: String) {
      let mode = Mode.allCases.first { $0.prefix != nil && $0.prefix == raw.first } ?? .plain
      let body = mode == .plain ? raw : String(raw.dropFirst())
      self.mode = mode
      self.text = body.trimmingCharacters(in: .whitespaces)
   }

   /// True for an empty plain query, which lists recent picks.
   public var isEmpty: Bool { mode == .plain && text.isEmpty }
}
