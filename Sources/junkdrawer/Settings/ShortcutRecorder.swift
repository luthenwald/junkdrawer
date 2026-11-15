import AppKit
import Carbon.HIToolbox
import SwiftUI

/// How a recording ended.
enum Recording {
   case recorded(Shortcut), cleared, cancelled
}

/// A button that shows a shortcut and, once clicked, records the next key
/// combination typed. Esc cancels, as does leaving the window, and Delete
/// removes the shortcut when it may be left empty. The global shortcut is released while recording, so
/// typing it is recorded too.
struct ShortcutRecorder: View {
   let current: Shortcut?
   var notice: String? = nil
   var clearable = false
   let hotKey: GlobalShortcut
   /// Returns why a recorded shortcut was refused, shown until the next recording.
   let record: (Recording) -> String?
   @State private var monitor: Any?
   @State private var refusal: String?

   var body: some View {
      HStack {
         if let text = refusal ?? notice {
            Text(text)
               .font(.caption)
               .fixedSize()
               .foregroundStyle(.secondary)
         }
         Button {
            if monitor == nil { start() } else { stop(.cancelled) }
         } label: {
            Text(monitor == nil ? current?.description ?? "None" : "Type shortcut")
               .monospacedDigit()
               .frame(minWidth: 64)
         }
         .help(clearable ? "Esc cancels, Delete removes the shortcut" : "Esc cancels")
      }
      .onDisappear { stop(.cancelled) }
      // Leaving the window ends a recording too, by switching to another
      // app or by closing it; the global shortcut would stay released.
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in stop(.cancelled) }
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in stop(.cancelled) }
   }

   private func start() {
      refusal = nil
      hotKey.pause()
      // Every key goes to the recorder, key equivalents included.
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
         MainActor.assumeIsolated {
            let code = Int(event.keyCode)
            let plain = event.modifierFlags.isDisjoint(with: [.control, .option, .command])
            if code == kVK_Escape {
               stop(.cancelled)
            } else if clearable, plain, [kVK_Delete, kVK_ForwardDelete].contains(code) {
               stop(.cleared)
            } else if let recorded = Shortcut(event) {
               stop(.recorded(recorded))
            }
         }
         return nil
      }
   }

   private func stop(_ result: Recording) {
      guard let monitor else { return }
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
      hotKey.resume()
      refusal = record(result)
   }
}

extension Shortcut: CustomStringConvertible {
   private static let symbols: [(carbon: Int, symbol: String)] = [
      (controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘"),
   ]

   private static let keyNames: [Int: String] = {
      let named = [
         kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
         kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
         kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
      ]
      let functionKeys = [
         kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
      ]
      return functionKeys.enumerated().reduce(into: named) { names, item in names[item.element] = "F\(item.offset + 1)" }
   }()

   /// A key with at least one of Control, Option or Command, since a plain
   /// or shifted key would take over typing everywhere.
   init?(_ event: NSEvent) {
      let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      guard !flags.isDisjoint(with: [.control, .option, .command]) else { return nil }
      let code = Int(event.keyCode)
      guard let key = Self.keyNames[code] ?? event.characters(byApplyingModifiers: [])?.uppercased(), !key.isEmpty else { return nil }
      self.init(keyCode: UInt32(code), modifiers: flags.carbon, key: key)
   }

   /// For example `⌃⇧J`.
   var description: String {
      Self.symbols.filter { modifiers & UInt32($0.carbon) != 0 }.map(\.symbol).joined() + key
   }
}

extension NSEvent.ModifierFlags {
   /// The Carbon modifier bits a hotkey registers with.
   var carbon: UInt32 {
      [(NSEvent.ModifierFlags.control, controlKey), (.option, optionKey), (.shift, shiftKey), (.command, cmdKey)]
         .reduce(0) { contains($1.0) ? $0 | UInt32($1.1) : $0 }
   }
}
