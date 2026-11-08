import Foundation

/// The bookmarks in a bookmarks file: one per line, the URL first, then the
/// title, then optional `#tags`. Blank lines and lines starting with `;` are
/// skipped, and so are lines whose first word is not a URL with a scheme.
/// A URL that appears twice keeps its first line.
public func bookmarks(from text: String) -> [Item] {
   var seen = Set<URL>()
   return text
      .split(whereSeparator: \.isNewline)
      .compactMap(bookmark)
      .filter { item in
         guard case .openURL(let url) = item.primary else { return false }
         return seen.insert(url).inserted
      }
}

private func bookmark(_ line: Substring) -> Item? {
   let words = line.split(whereSeparator: \.isWhitespace)
   guard let first = words.first, !first.hasPrefix(";"),
         let url = URL(string: String(first)), url.scheme != nil, url.host() != nil
   else { return nil }
   let rest = words.dropFirst()
   let tags = rest.filter { $0.hasPrefix("#") && $0.count > 1 }.map { String($0.dropFirst()) }
   let title = rest.filter { !$0.hasPrefix("#") }.joined(separator: " ")
   let host = shown(url)
   return Item(
      id: "mark:\(url.absoluteString)",
      kind: .bookmark,
      title: title.isEmpty ? host : title,
      subtitle: host,
      keywords: ([host] + tags).joined(separator: " "),
      trailing: "bookmark",
      primary: .openURL(url),
      secondary: .copy(url.absoluteString)
   )
}

/// The URL without its scheme and trailing slash, such as
/// "docs.racket-lang.org" or "arxiv.org/list/cs.PL/recent".
private func shown(_ url: URL) -> String {
   var text = url.absoluteString
   if let scheme = url.scheme, text.hasPrefix(scheme + "://") { text.removeFirst(scheme.count + 3) }
   if text.hasSuffix("/") { text.removeLast() }
   return text
}
