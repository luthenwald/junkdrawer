import Foundation

/// A file or folder found under one of the folders the `/` mode searches.
public struct FileEntry: Hashable, Sendable {
   /// The absolute path.
   public let path: String
   /// The chosen folder it was found in.
   public let root: String
   public let isFolder: Bool

   public init(path: String, root: String, isFolder: Bool) {
      self.path = path
      self.root = root
      self.isFolder = isFolder
   }
}

/// The files of the `/` mode as items, with their names and paths
/// lowercased once, as UTF-8 bytes, for matching.
public struct Files: Sendable {
   /// The folders searched; empty when none are chosen.
   public let roots: [String]
   public let items: [Item]
   /// Lowercased names, by item position.
   let names: [[UInt8]]
   /// Lowercased paths below the chosen folder, by item position.
   let paths: [[UInt8]]
   /// Path lengths in bytes, by item position, for ties.
   let lengths: [Int]
   /// The item position by item id, for the recent list.
   let positions: [String: Int]

   public init(roots: [String] = [], entries: [FileEntry] = [], home: String = "") {
      self.roots = roots
      items = entries.map { fileItem($0, home: home) }
      names = items.map { Array($0.title.lowercased().utf8) }
      paths = entries.map { Array(relative($0.path, to: $0.root).lowercased().utf8) }
      lengths = entries.map(\.path.utf8.count)
      positions = Dictionary(items.enumerated().map { ($1.id, $0) }) { first, _ in first }
   }

   public func item(id: String) -> Item? {
      positions[id].map { items[$0] }
   }
}

/// The row for one file or folder: the name, its folder with `~` for the
/// home folder, "folder" or the extension on the right.
public func fileItem(_ entry: FileEntry, home: String) -> Item {
   let url = URL(fileURLWithPath: entry.path, isDirectory: entry.isFolder)
   let folder = url.deletingLastPathComponent().path
   let shown = !home.isEmpty && (folder == home || folder.hasPrefix(home + "/")) ? "~" + folder.dropFirst(home.count) : folder
   let ext = url.pathExtension.lowercased()
   return Item(
      id: "file:\(entry.path)",
      kind: .file,
      title: url.lastPathComponent,
      subtitle: shown,
      trailing: entry.isFolder ? "folder" : ext.isEmpty ? "file" : ext,
      primary: .open(url),
      secondary: .reveal(url),
      tertiary: .copy(entry.path)
   )
}

/// The path below `root`, or the whole path when it is not below it.
private func relative(_ path: String, to root: String) -> String {
   path.hasPrefix(root + "/") ? String(path.dropFirst(root.count + 1)) : path
}

/// What `/` with nothing chosen shows: one row that opens Settings.
let chooseFoldersItem = Item(
   id: "cmd:settings", kind: .command, title: "Choose folders to search", subtitle: "in Settings, under Files",
   trailing: "command", primary: .command(.settings), secondary: .command(.settings)
)

/// The `/` mode: the name score, or half the score on the path below the
/// chosen folder when that is better, plus the frecency bonus; folders a
/// little ahead of files. Ties put shorter paths first. Scores come from
/// the bytes; the matched characters only for the rows returned.
func fileRows(_ text: String, in files: Files, usage: Usage, now: Date) -> [Row] {
   let needle = Array(text.lowercased().utf8)
   let letters = needle.filter { $0 != UInt8(ascii: " ") }
   // Few files were ever picked, so the bonus is worked out for those only.
   let bonus = Dictionary(uniqueKeysWithValues: usage.picks.keys.compactMap { id in
      files.positions[id].map { ($0, usage.bonus(for: id, now: now)) }
   })
   let scored = files.items.indices.compactMap { index -> (index: Int, score: Double, byName: Bool)? in
      // The path below the folder holds the name, so a file whose path
      // lacks the letters in order matches neither.
      guard holds(letters, in: files.paths[index]) else { return nil }
      let name = match(needle, in: files.names[index])?.score
      let path = match(needle, in: files.paths[index]).map { 0.5 * $0.score }
      let best: (score: Double, byName: Bool)? = switch (name, path) {
      case let (name?, path?) where path > name: (path, false)
      case let (name?, _): (name, true)
      case let (nil, path?): (path, false)
      case (nil, nil): nil
      }
      let extra = (files.items[index].trailing == "folder" ? 2 : 0) + (bonus[index] ?? 0)
      return best.map { (index, $0.score + extra, $0.byName) }
   }
   return scored
      .sorted { a, b in
         a.score != b.score ? a.score > b.score : files.lengths[a.index] < files.lengths[b.index]
      }
      .prefix(symbolRowLimit)
      .map { found in
         let item = files.items[found.index]
         let matched = found.byName ? match(text, in: item.title)?.indices ?? [] : []
         return Row(item: item, matched: matched, score: found.score)
      }
}

/// Whether `hay` holds the bytes of `needle` in order, a quick test
/// before scoring.
private func holds(_ needle: [UInt8], in hay: [UInt8]) -> Bool {
   var rest = needle[...]
   for byte in hay where byte == rest.first {
      rest = rest.dropFirst()
      if rest.isEmpty { return true }
   }
   return rest.isEmpty
}

/// An empty `/`: the recent file picks, or the row that opens Settings
/// when no folder is chosen.
func recentFileRows(in files: Files, usage: Usage) -> [Row] {
   guard !files.roots.isEmpty else { return [Row(item: chooseFoldersItem, matched: [], score: 0)] }
   return usage.recent(limit: .max)
      .lazy
      .compactMap(files.item(id:))
      .prefix(recentLimit)
      .map { Row(item: $0, matched: [], score: 0) }
}
