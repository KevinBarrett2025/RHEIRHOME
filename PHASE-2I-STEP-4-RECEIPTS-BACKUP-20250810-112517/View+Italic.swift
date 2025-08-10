import SwiftUI

// MARK: – Conditional italic modifier
extension View {
  /// Applies `.italic()` when `flag` is true.
  @ViewBuilder
  func conditionalItalic(_ flag: Bool) -> some View {
    if flag {
      self.italic()
    } else {
      self
    }
  }
}
