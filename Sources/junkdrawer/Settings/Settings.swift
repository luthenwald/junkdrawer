import AppKit
import Observation

/// The choices of the settings window, stored in `UserDefaults` as JSON
/// strings. Every change is saved at once.
@MainActor @Observable
final class Settings {
   var shortcut = stored(.shortcut, default: Shortcut.toggle) { didSet { store(shortcut, as: .shortcut) } }
   var appearance = stored(.appearance, default: Appearance.system) { didSet { store(appearance, as: .appearance) } }
}

enum Appearance: String, Codable, CaseIterable {
   case system, light, dark

   /// `nil` follows the system.
   var nsAppearance: NSAppearance? {
      switch self {
      case .system: nil
      case .light: NSAppearance(named: .aqua)
      case .dark: NSAppearance(named: .darkAqua)
      }
   }
}

private enum Key: String {
   case shortcut = "Shortcut"
   case appearance = "Appearance"
}

private func stored<Value: Decodable>(_ key: Key, default value: Value) -> Value {
   UserDefaults.standard.string(forKey: key.rawValue)
      .flatMap { try? JSONDecoder().decode(Value.self, from: Data($0.utf8)) } ?? value
}

private func store<Value: Encodable>(_ value: Value, as key: Key) {
   guard let data = try? JSONEncoder().encode(value) else { return }
   UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: key.rawValue)
}

/// Runs `apply` now and again after every change of an observable property
/// it read, for keeping AppKit objects in step with the settings.
@MainActor
func track(_ apply: @escaping @MainActor () -> Void) {
   withObservationTracking(apply) {
      // Called before the change takes effect, so apply it on the next turn.
      Task { @MainActor in track(apply) }
   }
}
