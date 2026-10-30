import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct FEFOTraceabilityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    @StateObject private var api: APIService

    private let repository: APIRepository

    init() {
        let service = APIService()
        _api = StateObject(wrappedValue: service)
        repository = APIRepository(apiService: service)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(api: api, repository: repository)
                .environmentObject(api)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
    }
}
