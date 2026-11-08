import Foundation
import JunkdrawerCore
import os

/// The symbol table from the app's resources, parsed off the main thread
/// once at launch. Without the file the symbol modes stay empty.
@MainActor
final class SymbolsSource {
   nonisolated static let defaultFile = Bundle.main.url(forResource: "symbols", withExtension: "tsv")

   private var load: Task<Void, Never>?

   init(file: URL? = defaultFile, publish: @escaping (Symbols) -> Void) {
      guard let file else {
         Logger.app.error("symbols.tsv is missing from the app's resources")
         return
      }
      load = Task {
         let table = await Task.detached { Self.read(file) }.value
         publish(table)
      }
   }

   nonisolated private static func read(_ file: URL) -> Symbols {
      do {
         let start = Date()
         let table = symbols(from: try String(contentsOf: file, encoding: .utf8))
         let elapsed = Int(Date().timeIntervalSince(start) * 1000)
         Logger.app.notice("read \(table.unicode.count, privacy: .public) symbols and \(table.latex.count, privacy: .public) commands in \(elapsed, privacy: .public) ms")
         return table
      } catch {
         Logger.app.error("reading symbols.tsv failed: \(error.localizedDescription, privacy: .public)")
         return Symbols()
      }
   }
}
