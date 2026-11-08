extension Query {
   /// Shown at the left of the footer.
   public var label: String {
      switch mode {
      case .plain: text.isEmpty ? "recent" : "apps · bookmarks"
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

   /// The confirmation line after `action` ran, or nil when there is
   /// nothing to say, as after quitting.
   public func confirmation(for action: Action) -> String? {
      switch action {
      case .openApp: "opened \(title)"
      case .reveal(let url): "revealed \(url.lastPathComponent) in Finder"
      case .openURL: "opened \(subtitle) in the default browser"
      case .insert(let string): "inserted \(string)"
      case .copy(let string): kind == .dictionary ? "copied the definition of “\(title)”" : "copied \(string)"
      case .openDefinition: "opened “\(title)” in Dictionary"
      case .setQuery: nil
      case .command(.reload): "reloaded apps and bookmarks"
      case .command(.editBookmarks): "opened the bookmarks file"
      case .command(.showLogs): "opened the log"
      case .command(.quit): nil
      }
   }
}
