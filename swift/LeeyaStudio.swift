// LeeyaStudio.swift — main app entry. Decides WizardView vs MainView based on
// whether the Gemini key + YouTube token both exist in Keychain.

import SwiftUI
import AppKit

@main
struct LeeyaStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup("Leeya Studio") {
            RootView(router: router)
                .frame(minWidth: 640, minHeight: 700)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 760)
    }
}

final class AppRouter: ObservableObject {
    @Published var needsOnboarding: Bool = !Keychain.has(.geminiKey) || !Keychain.has(.youtubeToken)
}

struct RootView: View {
    @ObservedObject var router: AppRouter

    var body: some View {
        ZStack {
            if router.needsOnboarding {
                WizardView(needsOnboarding: $router.needsOnboarding)
            } else {
                MainView(needsOnboarding: $router.needsOnboarding)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}
