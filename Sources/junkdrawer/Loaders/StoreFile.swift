import Foundation
import os

/// Reading the JSON files the app keeps its own state in.
enum StoreFile {
   /// The value in `file`, or nil when there is no file or it cannot be
   /// read as one. A file that cannot be read is moved aside as
   /// `<name>.broken`, replacing an earlier one, so the next write does not
   /// destroy what it held.
   static func load<Value: Decodable>(_ file: URL, dates: JSONDecoder.DateDecodingStrategy = .deferredToDate) -> Value? {
      guard let data = try? Data(contentsOf: file) else { return nil }
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = dates
      do {
         return try decoder.decode(Value.self, from: data)
      } catch {
         let name = file.lastPathComponent
         Logger.app.error("reading \(name, privacy: .public) failed, keeping it as \(name, privacy: .public).broken: \(error.localizedDescription, privacy: .public)")
         let aside = file.appendingPathExtension("broken")
         try? FileManager.default.removeItem(at: aside)
         try? FileManager.default.moveItem(at: file, to: aside)
         return nil
      }
   }
}
