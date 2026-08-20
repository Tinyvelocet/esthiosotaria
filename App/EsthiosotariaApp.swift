import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct EsthiosotariaApp: App {
    @StateObject private var settings = UserSettingsStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if DesignGalleryView.showAtLaunch {
                    DesignGalleryView()
                } else {
                    RootView()
                        .environmentObject(settings)
                }
            }
            .tint(Design.Accent.brand)
        }
        #if os(macOS)
        // Free resizing with a sane floor. (.contentSize would lock the
        // window to the content's ideal size — the "not resizable" bug.)
        .defaultSize(width: 980, height: 680)
        .windowResizability(.contentMinSize)
        // This app has no use for multiple windows: onboarding and
        // settings state live in per-window @State, so a second window
        // runs its own independent onboarding flow (duplicate location
        // prompts, duplicate store-discovery requests, inconsistent
        // results). Removing "New Window" also stops macOS from having
        // more than one window to resume on next launch.
        .commands {
            // Replacing (not removing) .newItem drops "New Window" but
            // keeps the File menu around — an empty replacement makes
            // SwiftUI drop the whole menu, taking ⌘W "Close" with it.
            CommandGroup(replacing: .newItem) {
                Button("Close") {
                    NSApp.keyWindow?.performClose(nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }
        #endif
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
