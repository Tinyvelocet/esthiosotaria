import SwiftUI
import RecallKit

/// Entry view: routes between onboarding and the main recall list.
struct RootView: View {
    @EnvironmentObject var settings: UserSettingsStore

    var body: some View {
        Group {
            if settings.isOnboardingComplete {
                RecallListView()
            } else {
                OnboardingView()
            }
        }
        .background(Design.Paper.background)
        #if os(macOS)
        // Floor for .windowResizability(.contentMinSize): keeps the window
        // resizable while preventing unusably small sizes.
        .frame(minWidth: 720, minHeight: 520)
        #endif
    }
}
