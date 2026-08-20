import SwiftUI
import CoreLocation
import RecallKit
#if canImport(AppKit)
import AppKit
#endif

// ---------------------------------------------------------------------------
// Screenshot generator — renders each key screen at iPhone frame size to a
// clean PNG (no simulator chrome) for design hand-off to Figma.
//
// Build + run:
//   xcodegen generate
//   xcodebuild -scheme EsthioSotaria_ScreenshotGen -configuration Release build
//   ./build-out/EsthioSotaria_ScreenshotGen        (run from the repo root)
//
// Output: docs/screenshots/*.png  (light appearance only).
// ---------------------------------------------------------------------------

@main
struct ScreenshotRunner {
    static let frame = CGSize(width: 393, height: 852) // iPhone 15 logical

    @MainActor
    static func main() {
        let settings = UserSettingsStore.designState()
        let vm = RecallListViewModel.designState()

        // Onboarding
        render("01-onboarding-welcome", OnboardingWelcomeView(onStart: {}))
        render("02-onboarding-locating", OnboardingLocatingView(isDenied: false, onManualEntry: {}))
        render("03-onboarding-location-denied", OnboardingLocatingView(isDenied: true, onManualEntry: {}))
        render("04-onboarding-manual-entry", OnboardingManualEntryView(
            text: .constant("Palo Alto, CA"),
            errorMessage: nil,
            onSearch: {}, onBack: {}))

        // Store discovery + picker (list + map)
        render("05-onboarding-store-picker", OnboardingStorePickerView(
            stores: MockData.discoveryStores,
            selectedStores: [MockData.costco, MockData.piazzas],
            source: .overpass,
            isLoading: false,
            errorMessage: nil,
            searchCenter: CLLocationCoordinate2D(latitude: 37.4419, longitude: -122.1430),
            radiusMiles: .constant(15),
            onRadiusCommit: {}, onToggle: { _ in }, onDone: {}),
            centered: false)

        // Store dashboard (severity-ranked stores + serious regional section)
        let dashboard = NavigationStack {
            StoreDashboardView(
                stores: MockData.fourStores,
                chainMatches: vm.chainMatches,
                regionalMatches: vm.regionalMatches,
                isLoading: false, fsisUnavailable: false, lastUpdated: Date(),
                onRefresh: {})
        }
        .environmentObject(settings)
        render("06-dashboard", dashboard, centered: false)

        // Scan result — a non-favorite store with a chain match
        let scanStore = Store(name: "Lakeside Grocer", chain: nil, latitude: 37.40, longitude: -122.13)
        let scanResult = ScanLocationService.Result(
            store: scanStore,
            chainMatches: MockData.items(for: [MockData.wontonWrappers], stores: [scanStore]),
            regionalMatches: MockData.items(for: [MockData.romaineLettuce], stores: [scanStore]),
            lastUpdated: Date())
        let scanView = ScanResultView(result: scanResult) {}
            .environmentObject(settings)
        render("06b-scan-result", scanView, centered: false)

        // Recall detail — Class I chain match
        let chainItem = MockData.items(for: [MockData.kirklandMadeleines], stores: MockData.fourStores)[0]
        let detail = NavigationStack { RecallDetailView(item: chainItem) }
            .environmentObject(settings)
        render("07-recall-detail", detail, centered: false)

        // Settings
        let settingsView = NavigationStack { SettingsView() }
            .environmentObject(settings)
        render("08-settings", settingsView, centered: false)

        // Area list (regional feed)
        let area = NavigationStack {
            AreaListView(items: vm.regionalMatches, isLoading: false,
                         fsisUnavailable: false, lastUpdated: Date(), onRefresh: {})
        }
        .environmentObject(settings)
        render("09-area-list", area, centered: false)

        print("Done. Check docs/screenshots/")
    }

    @MainActor
    private static func render<Content: View>(_ name: String, _ content: Content, centered: Bool = true) {
        let paper = Design.Paper.background
        let canvas: AnyView
        if centered {
            canvas = AnyView(
                ZStack { paper; content }
                    .frame(width: frame.width, height: frame.height))
        } else {
            canvas = AnyView(
                ZStack(alignment: .topLeading) { paper; content }
                    .frame(width: frame.width, height: frame.height))
        }

        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 3
        renderer.isOpaque = true
        guard let image = renderer.nsImage else {
            FileHandle.standardError.write(Data("FAILED to render \(name)\n".utf8))
            return
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("FAILED to encode \(name)\n".utf8))
            return
        }

        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent("\(name).png")
        do {
            try png.write(to: out, options: .atomic)
            print("WROTE \(out.path)")
        } catch {
            FileHandle.standardError.write(Data("FAILED to write \(name): \(error)\n".utf8))
        }
    }
}