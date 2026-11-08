extension Mode {
   /// Shown at the left of the footer.
   public var label: String {
      switch self {
      case .plain: "apps · bookmarks"
      case .latex: "latex"
      case .unicode: "unicode"
      case .dictionary: "dictionary"
      }
   }
}

extension Item {
   /// What ↵ does, after its key in the footer.
   public var primaryHint: String { hint(primary) }

   /// What ⌘↵ does, after its key in the footer.
   public var secondaryHint: String { hint(secondary) }

   private func hint(_ action: Action) -> String {
      switch (kind, action) {
      case (_, .openApp): "open"
      case (_, .reveal): "reveal in Finder"
      case (_, .openURL): "open in default browser"
      case (_, .insert(let string)): "insert \(string)"
      case (.bookmark, .copy): "copy url"
      case (.dictionary, .copy): "copy definition"
      case (_, .copy(let string)): "copy \(string)"
      case (_, .openDefinition): "open in Dictionary"
      case (_, .setQuery): "look up"
      case (_, .command): "run"
      }
   }
}
