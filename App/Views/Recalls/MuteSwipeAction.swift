import SwiftUI
import RecallKit

extension View {
    /// Trailing swipe action to mute/unmute a recall's brand — attach to
    /// any List row showing a `RecallRowView`. Absent when the recall has
    /// no identifiable brand/firm to mute.
    @ViewBuilder
    func muteSwipeAction(for item: RecallListViewModel.Item, settings: UserSettingsStore) -> some View {
        if let productName = ProductKey.displayName(for: item.recall) {
            let muted = settings.isProductMuted(item.recall)
            swipeActions(edge: .trailing) {
                Button {
                    if muted {
                        settings.unmuteProduct(productName)
                    } else {
                        settings.muteProduct(productName)
                    }
                } label: {
                    if muted {
                        Label("I buy this", systemImage: "bell.fill")
                    } else {
                        Label("Not something I buy", systemImage: "bell.slash.fill")
                    }
                }
                .tint(muted ? Design.Accent.brand : .gray)
            }
        } else {
            self
        }
    }
}
