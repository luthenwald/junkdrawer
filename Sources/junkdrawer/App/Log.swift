import os

extension Logger {
   /// Shown by `el log`. `NSLog` does not reach the unified log on
   /// macOS 27, so lines from a bundled launch would be lost.
   static let app = Logger(subsystem: "junkdrawer.junkdrawer", category: "app")
}

extension ContinuousClock.Instant {
   /// The time since this instant in milliseconds, for timing lines.
   var millisecondsAgo: Double {
      let elapsed = duration(to: .now).components
      return Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
   }
}
