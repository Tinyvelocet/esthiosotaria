import SwiftUI
import RecallKit

@main
struct EsthiosotariaApp: App {
    @StateObject private var settings = UserSettingsStore()

    var body: some Scene {
        WindowGroup {
            if DesignGalleryView.showAtLaunch {
                NavigationStack {
                    DesignGalleryView()
                }
            } else {
                RootView()
                    .environmentObject(settings)
            }
        }
    }
}
