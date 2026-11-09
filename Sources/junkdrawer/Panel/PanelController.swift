import AppKit
import JunkdrawerCore
import os

/// Shows and hides the panel, ranks the query and moves the selection. It
/// opens empty on the screen under the pointer and hides on Esc, on focus
/// loss, on the hotkey and after an action.
@MainActor
final class PanelController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
   /// Where the panel's top edge sits, as a share of the visible height
   /// measured from the top.
   private static let topOffset: CGFloat = 0.22

   /// Carries out an action of a row, after the panel hid.
   var perform: (Item, Action) -> Void = { _, _ in }
   private let panel = LauncherPanel()
   private let usage: UsageStore
   private let settings: Settings
   private let dictionary = DictionarySource()
   /// The screen the panel last showed on, for the confirmation line.
   private(set) var screen: NSScreen?
   private var index = Index()
   private var icons: [String: CGImage] = [:]
   private var rows: [Row] = []
   /// The dictionary entries of the rows, by item id, for the pane.
   private var definitions: [String: Definition] = [:]
   /// Shown in place of rows when there are none.
   private var emptyText = ""
   /// True while the rows are a dictionary answer, which stays until the
   /// next one arrives.
   private var showsLookup = false
   private var warmUp = WarmUp.pending
   /// When a warm-up that waits for the dictionary gives up.
   private static let warmUpLimit = 2.0
   /// One query per mode, so each mode's fonts and first ranking are paid
   /// for before the first real use.
   private static let warmUpQueries = ["saf", "launch", "\\alpha", ":heart", ":a"]

   private enum WarmUp { case pending, running, done }
   private var selection = Selection(count: 0, visible: LauncherPanel.visibleRows)

   init(usage: UsageStore, settings: Settings) {
      self.usage = usage
      self.settings = settings
      super.init()
      panel.delegate = self
      panel.query.delegate = self
      panel.onCancel = { [unowned self] in hide() }
      panel.onSecondary = { [unowned self] in run(\.secondary) }
      panel.onCommand = { [unowned self] command in
         hide(handingBack: !command.opensWindow)
         perform(command.item, .command(command))
      }
   }

   /// New data from the loaders. The selection stays on the same item when
   /// it is still there.
   func update(index: Index, icons: [String: CGImage]) {
      self.index = index
      self.icons = icons
      if warmUp == .pending, !index.symbols.unicode.isEmpty {
         warm()
         return
      }
      let selected = rows.indices.contains(selection.index) ? rows[selection.index].item.id : nil
      refresh(keeping: selected)
   }

   func toggle() {
      if panel.isVisible, warmUp != .running { hide() } else { show() }
   }

   /// Without activating the app, so an insert later lands in the app that
   /// was in front, and hiding needs no focus hand-back.
   func show() {
      let start = ContinuousClock.now
      endWarmUp()
      place()
      panel.makeKeyAndOrderFront(nil)
      panel.makeFirstResponder(panel.query)
      panel.invalidateShadow()
      // Committed to the window server; the next turn of the main queue
      // comes after the panel drew.
      CATransaction.flush()
      DispatchQueue.main.async {
         Logger.app.debug("panel shown in \(start.millisecondsAgo, format: .fixed(precision: 1), privacy: .public) ms")
      }
   }

   /// Hiding the app hands the focus back, unless the settings window is
   /// open or a command is about to open it. The app counts as active while
   /// the panel is key, also when another app is in front.
   func hide(handingBack: Bool = true) {
      guard panel.isVisible else { return }
      panel.orderOut(nil)
      clear()
      guard handingBack, NSApp.isActive, !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) else { return }
      NSApp.hide(nil)
   }

   func windowDidResignKey(_ notification: Notification) {
      hide()
   }

   /// Remembers where the user dragged the panel, for that screen. Back at
   /// the default spot, within 2 pt, it forgets it.
   func windowDidMove(_ notification: Notification) {
      guard !panel.movesItself, warmUp != .running, let screen = panel.screen, let key = screen.displayKey else { return }
      self.screen = screen
      let visible = screen.visibleFrame
      let spot = Spot(x: panel.frame.minX - visible.minX, y: visible.maxY - panel.frame.maxY)
      let standard = Self.defaultTopLeft(on: visible)
      let isDefault = abs(panel.frame.minX - standard.x) <= 2 && abs(panel.frame.maxY - standard.y) <= 2
      let stored = isDefault ? nil : spot
      if settings.positions[key] != stored { settings.positions[key] = stored }
   }

   func controlTextDidChange(_ notification: Notification) {
      refresh(keeping: nil)
   }

   /// Keys from the query field. Esc clears the query, and on an empty query
   /// hides the panel; the field editor would otherwise take it for
   /// completion. ⌃N and ⌃P arrive as moveDown and moveUp.
   func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
      switch selector {
      case #selector(NSResponder.moveDown(_:)): move(by: 1)
      case #selector(NSResponder.moveUp(_:)): move(by: -1)
      case #selector(NSResponder.insertNewline(_:)): run(\.primary)
      case #selector(NSResponder.cancelOperation(_:)):
         if panel.query.stringValue.isEmpty { hide() } else { clear() }
      default: return false
      }
      return true
   }

   private func move(by step: Int) {
      selection = selection.moved(by: step)
      render()
   }

   /// Records the pick, then hides, so an app that opens comes to the front
   /// over nothing. Dictionary look-ups and some commands are not picks. The
   /// Define row sets the query instead and keeps the panel open.
   private func run(_ key: KeyPath<Item, Action>) {
      guard rows.indices.contains(selection.index) else { return }
      let item = rows[selection.index].item
      let action = item[keyPath: key]
      if case .setQuery(let text) = action {
         setQuery(text)
         return
      }
      let isPick = if case .command(let command) = action { command.isPick } else { item.kind != .dictionary }
      let opensWindow = if case .command(let command) = action { command.opensWindow } else { false }
      if isPick { usage.record(item) }
      hide(handingBack: !opensWindow)
      perform(item, action)
   }

   private func clear() {
      setQuery("")
   }

   /// With the caret at the end, as if typed.
   private func setQuery(_ text: String) {
      panel.query.stringValue = text
      panel.query.currentEditor()?.selectedRange = NSRange(location: (text as NSString).length, length: 0)
      refresh(keeping: nil)
   }

   /// Ranks the query again and selects `id`, or the first row. In the
   /// dictionary mode the rows come once the look-up answers; until then
   /// the previous ones stay, so typing does not flicker.
   private func refresh(keeping id: String?) {
      let start = ContinuousClock.now
      let raw = panel.query.stringValue
      let query = Query(raw)
      guard query.mode == .dictionary else {
         dictionary.cancel()
         show(JunkdrawerCore.rows(for: query, in: index, usage: usage.usage, now: Date()), [:], empty: raw.isEmpty ? "No recent picks" : "No matches", keeping: id)
         Logger.app.debug("\(query.label, privacy: .public), \(query.text.count, privacy: .public) characters: \(self.rows.count, privacy: .public) rows in \(start.millisecondsAgo, format: .fixed(precision: 1), privacy: .public) ms")
         return
      }
      guard !query.text.isEmpty else {
         dictionary.cancel()
         show([], [:], empty: "Type a word to look it up", keeping: nil)
         return
      }
      if !showsLookup { show([], [:], empty: "", keeping: nil) }
      dictionary.lookUp(query.text) { [weak self] found in
         guard let self, Query(panel.query.stringValue) == query else { return }
         let result = dictionaryRows(query.text, found)
         show(result.rows, result.definitions, empty: "No entry for “\(query.text)”", keeping: id, lookup: true)
         Logger.app.debug("dictionary, \(query.text.count, privacy: .public) characters: \(result.rows.count, privacy: .public) rows answered in \(start.millisecondsAgo, format: .fixed(precision: 1), privacy: .public) ms")
         if warmUp == .running { endWarmUp() }
      }
   }

   /// Draws the panel once at launch, invisible and without taking focus,
   /// with a query in each mode and then a dictionary entry, so the first
   /// ⌘Space after login does not pay for building layers, loading fonts
   /// and the first look-up: 72 to 100 ms before, 11 to 16 ms after.
   private func warm() {
      warmUp = .running
      let start = ContinuousClock.now
      place()
      panel.alphaValue = 0
      panel.ignoresMouseEvents = true
      panel.orderFrontRegardless()
      _ = panel.fieldEditor(true, for: panel.query)
      for query in Self.warmUpQueries {
         panel.query.stringValue = query
         refresh(keeping: nil)
         panel.displayIfNeeded()
      }
      CATransaction.flush()
      Logger.app.debug("warmed up the modes in \(start.millisecondsAgo, format: .fixed(precision: 1), privacy: .public) ms")
      // Ends when the entry has drawn, or after the limit.
      panel.query.stringValue = "?ephemeral"
      refresh(keeping: nil)
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.warmUpLimit) { [weak self] in self?.endWarmUp() }
   }

   /// Puts the panel away as if it never showed. Showing it for real ends
   /// a warm-up that is still running.
   private func endWarmUp() {
      guard warmUp == .running else { return }
      warmUp = .done
      panel.displayIfNeeded()
      CATransaction.flush()
      panel.orderOut(nil)
      panel.alphaValue = 1
      panel.ignoresMouseEvents = false
      clear()
   }

   private func show(_ rows: [Row], _ definitions: [String: Definition], empty: String, keeping id: String?, lookup: Bool = false) {
      showsLookup = lookup
      self.rows = rows
      self.definitions = definitions
      emptyText = empty
      let position = id.flatMap { id in rows.firstIndex { $0.item.id == id } } ?? 0
      selection = Selection(count: rows.count, visible: LauncherPanel.visibleRows).moved(by: position)
      render()
   }

   /// The ⌘↵ hint is left out when it does the same as ↵.
   private func render() {
      let raw = panel.query.stringValue
      let window = selection.window
      panel.list.show(rows[window], selected: selection.index - window.lowerBound, icons: icons, empty: emptyText)
      let current = rows.indices.contains(selection.index) ? rows[selection.index].item : nil
      let hints: [(key: String, action: String)] = current.map { item in
         [("↵", item.primaryHint)] + (item.secondary == item.primary ? [] : [("⌘↵", item.secondaryHint)])
      } ?? []
      panel.footer.show(mode: Query(raw).label, counter: selection.counter, hints: hints + [("esc", raw.isEmpty ? "close" : "clear")])
      let definition = current.flatMap { definitions[$0.id] }
      if let definition { panel.definition.show(definition) }
      panel.fit(legend: raw.isEmpty, definition: definition != nil)
   }

   /// On the screen under the pointer, where it was dragged to on that
   /// screen, kept so the whole panel is on screen, or else centred near
   /// the top.
   private func place() {
      let mouse = NSEvent.mouseLocation
      guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
      self.screen = screen
      let visible = screen.visibleFrame
      let topLeft = screen.displayKey.flatMap { settings.positions[$0] }.map { spot in
         NSPoint(
            x: min(max(visible.minX + spot.x, visible.minX), visible.maxX - LauncherPanel.width).rounded(),
            y: min(max(visible.maxY - spot.y, visible.minY + panel.frame.height), visible.maxY).rounded()
         )
      }
      panel.move(topLeft: topLeft ?? Self.defaultTopLeft(on: visible))
   }

   private static func defaultTopLeft(on visible: NSRect) -> NSPoint {
      NSPoint(x: (visible.midX - LauncherPanel.width / 2).rounded(), y: (visible.maxY - topOffset * visible.height).rounded())
   }
}

extension NSScreen {
   /// The display's UUID, which stays the same across restarts and
   /// rearrangements.
   var displayKey: String? {
      guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
            let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
      return CFUUIDCreateString(nil, uuid) as String
   }
}
