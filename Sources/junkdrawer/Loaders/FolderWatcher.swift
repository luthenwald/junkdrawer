import CoreServices
import Foundation

/// Calls back on the main queue when anything inside the folders changes,
/// a second after the last change of a burst, with the folders that
/// changed.
@MainActor
final class FolderWatcher {
   private let onChange: ([String]) -> Void
   // Also released in `deinit`, which is not isolated to the main actor.
   // Watchers are made and dropped on the main thread, so that never races.
   nonisolated(unsafe) private var stream: FSEventStreamRef?

   init(paths: [String], onChange: @escaping ([String]) -> Void) {
      self.onChange = onChange
      let existing = paths.filter { FileManager.default.fileExists(atPath: $0) }
      var context = FSEventStreamContext(
         version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil
      )
      let callback: FSEventStreamCallback = { _, info, _, paths, _, _ in
         guard let info else { return }
         // CFStrings, since the stream uses CF types.
         let changed = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String] ?? []
         // The stream runs on the main queue.
         MainActor.assumeIsolated {
            Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().onChange(changed)
         }
      }
      guard let stream = FSEventStreamCreate(
         nil, callback, &context, existing as CFArray,
         FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0,
         FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes)
      ) else { return }
      FSEventStreamSetDispatchQueue(stream, .main)
      FSEventStreamStart(stream)
      self.stream = stream
   }

   deinit {
      guard let stream else { return }
      FSEventStreamStop(stream)
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
   }
}
