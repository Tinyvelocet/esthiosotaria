import SwiftUI

@main
struct EsthiosotariaApp: App {
    @StateObject private var settings = UserSettingsStore()
    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { _, newPhase in
            #if os(iOS)
            if newPhase == .background {
                BackgroundRefresh.schedule()
            }
            #endif
        }
    }

    init() {
        #if os(iOS)
        BackgroundRefresh.register()
        #endif
    }
}
