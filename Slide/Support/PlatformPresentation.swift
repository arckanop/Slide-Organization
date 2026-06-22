import SwiftUI

extension View {
    /// `fullScreenCover` doesn't exist on macOS; falls back to `.sheet` there
    /// so the same call site works on every platform this app targets.
    @ViewBuilder
    func platformCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(macOS)
        sheet(item: item, content: content)
        #else
        fullScreenCover(item: item, content: content)
        #endif
    }
}
