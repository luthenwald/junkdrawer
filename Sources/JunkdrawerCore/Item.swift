import Foundation

/// What a row does, as plain data. The shell interprets it; the core only
/// builds it.
public enum Action: Hashable, Sendable {
   case openApp(URL)
   case reveal(URL)
   case openURL(URL)
   case insert(String)
   case copy(String)
   case openDefinition(String)
   case setQuery(String)
   case command(Command)
}

/// Where an item comes from, which decides its left cell and small
/// ranking differences.
public enum Kind: Hashable, Sendable {
   case app
   case bookmark
   case latex
   case unicode
   case dictionary
   case command
   case setting
}

/// One thing the list can show.
public struct Item: Identifiable, Hashable, Sendable {
   /// A stable key, such as "app:/Applications/Safari.app" or "tex:alpha",
   /// used for frecency.
   public let id: String
   public let kind: Kind
   public let title: String
   public let subtitle: String
   /// Searched besides the title at a lower weight, such as a bookmark's
   /// host and tags.
   public let keywords: String
   /// The character shown in the left cell for symbols.
   public let glyph: String?
   /// The right label, such as "amssymb · U+2115".
   public let trailing: String
   public let primary: Action
   public let secondary: Action

   public init(
      id: String, kind: Kind, title: String, subtitle: String, keywords: String = "",
      glyph: String? = nil, trailing: String, primary: Action, secondary: Action
   ) {
      self.id = id
      self.kind = kind
      self.title = title
      self.subtitle = subtitle
      self.keywords = keywords
      self.glyph = glyph
      self.trailing = trailing
      self.primary = primary
      self.secondary = secondary
   }
}

/// An item as ranked for a query, with the title's matched characters.
public struct Row: Hashable, Sendable {
   public let item: Item
   /// Character offsets in the title, set in a heavier weight.
   public let matched: [Int]
   public let score: Double

   public init(item: Item, matched: [Int], score: Double) {
      self.item = item
      self.matched = matched
      self.score = score
   }
}
