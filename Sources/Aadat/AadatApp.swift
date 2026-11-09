import AppKit
import SwiftUI

@main
struct AadatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Launch at login and the data folder need a real app bundle with an Info.plist.
        guard Bundle.main.bundleIdentifier != nil else {
            FileHandle.standardError.write(Data("Aadat must run from Aadat.app. Build it with scripts/build-app.sh.\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(controller: appDelegate.controller)
        } label: {
            MenuBarLabel(controller: appDelegate.controller)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = BoardController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier, isAnotherInstanceRunning(bundleID: bundleID) {
            Log.app.notice("Another instance is already running; exiting")
            NSApp.terminate(nil)
            return
        }
        controller.start()
    }

    private func isAnotherInstanceRunning(bundleID: String) -> Bool {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0.processIdentifier != currentPID }
    }
}
