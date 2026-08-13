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
    }
}
