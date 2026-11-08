import AppKit
import JunkdrawerCore

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
   private var index = Index()
   private var icons: [String: CGImage] = [:]
   private var rows: [Row] = []
   private var selection = Selection(count: 0, visible: LauncherPanel.visibleRows)

   init(usage: UsageStore) {
      self.usage = usage
      super.init()
      panel.delegate = self
      panel.query.delegate = self
      panel.onCancel = { [unowned self] in hide() }
      panel.onSecondary = { [unowned self] in run(\.secondary) }
   }

   /// New data from the loaders. The selection stays on the same item when
   /// it is still there.
   func update(items: [Item], icons: [String: CGImage]) {
      index.items = items
      self.icons = icons
      let selected = rows.indices.contains(selection.index) ? rows[selection.index].item.id : nil
      refresh(keeping: selected)
   }

   func toggle() {
      if panel.isVisible { hide() } else { show() }
   }

   /// Without activating the app, so an insert later lands in the app that
   /// was in front, and hiding needs no focus hand-back.
   func show() {
      place()
      panel.makeKeyAndOrderFront(nil)
      panel.makeFirstResponder(panel.query)
      panel.invalidateShadow()
   }

   func hide() {
      guard panel.isVisible else { return }
      panel.orderOut(nil)
      clear()
      // Reopening from Finder activates the app; hiding it hands focus back.
      if NSApp.isActive { NSApp.hide(nil) }
   }

   func windowDidResignKey(_ notification: Notification) {
      hide()
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
   /// over nothing. Dictionary look-ups and quitting are not picks.
   private func run(_ key: KeyPath<Item, Action>) {
      guard rows.indices.contains(selection.index) else { return }
      let item = rows[selection.index].item
      let action = item[keyPath: key]
      if item.kind != .dictionary, action != .command(.quit) { usage.record(item) }
      hide()
      perform(item, action)
   }

   private func clear() {
      panel.query.stringValue = ""
      refresh(keeping: nil)
   }

   /// Ranks the query again and selects `id`, or the first row.
   private func refresh(keeping id: String?) {
      rows = JunkdrawerCore.rows(for: Query(panel.query.stringValue), in: index, usage: usage.usage, now: Date())
      let position = id.flatMap { id in rows.firstIndex { $0.item.id == id } } ?? 0
      selection = Selection(count: rows.count, visible: LauncherPanel.visibleRows).moved(by: position)
      render()
   }

   private func render() {
      let raw = panel.query.stringValue
      let window = selection.window
      panel.list.show(rows[window], selected: selection.index - window.lowerBound, icons: icons)
      let current = rows.indices.contains(selection.index) ? rows[selection.index].item : nil
      let hints: [(key: String, action: String)] = current.map { [("↵", $0.primaryHint), ("⌘↵", $0.secondaryHint)] } ?? []
      panel.footer.show(mode: Query(raw).label, counter: selection.counter, hints: hints + [("esc", "clear")])
      panel.fit(expanded: !raw.isEmpty)
   }

   /// Centred on the screen under the pointer, near the top.
   private func place() {
      let mouse = NSEvent.mouseLocation
      guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
      let visible = screen.visibleFrame
      let size = panel.frame.size
      let top = visible.maxY - Self.topOffset * visible.height
      panel.setFrameOrigin(NSPoint(x: (visible.midX - size.width / 2).rounded(), y: (top - size.height).rounded()))
   }
}
