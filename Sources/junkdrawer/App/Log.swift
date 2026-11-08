import os

extension Logger {
   /// Shown by `just log`. `NSLog` does not reach the unified log on
   /// macOS 27, so lines from a bundled launch would be lost.
   static let app = Logger(subsystem: "junkdrawer.junkdrawer", category: "app")
}
