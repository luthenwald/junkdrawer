/// The selected row and the window of rows that shows it.
public struct Selection: Hashable, Sendable {
   public let count: Int
   /// How many rows show at once.
   public let visible: Int
   public private(set) var index = 0
   /// The first row that shows.
   public private(set) var offset = 0

   public init(count: Int, visible: Int) {
      self.count = count
      self.visible = visible
   }

   /// Moved by `step` rows, wrapping at both ends, with the window following.
   public func moved(by step: Int) -> Selection {
      guard count > 0 else { return self }
      var next = self
      next.index = ((index + step) % count + count) % count
      next.offset = min(max(offset, next.index - visible + 1), next.index)
      return next
   }

   /// The rows that show, as positions in the full list.
   public var window: Range<Int> {
      offset..<min(offset + visible, count)
   }

   /// Such as "03/12", or "00/00" with nothing to select.
   public var counter: String {
      count == 0 ? "00/00" : "\(padded(index + 1))/\(padded(count))"
   }

   private func padded(_ number: Int) -> String {
      number < 10 ? "0\(number)" : "\(number)"
   }
}
