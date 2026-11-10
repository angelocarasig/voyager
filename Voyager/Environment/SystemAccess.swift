//
//  SystemAccess.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import Observation
import UniformTypeIdentifiers

// full disk access and the default file manager both live in macOS, so they are re-read
// whenever voyager comes to the front instead of being stored
@MainActor
@Observable
final class SystemAccess {
    static let shared = SystemAccess()

    private(set) var hasFullDiskAccess = false
    private(set) var isDefaultFileManager = false
    private(set) var failure: String?

    private static let fileViewerKey = "NSFileViewer" as CFString
    private static let finder = URL(filePath: "/System/Library/CoreServices/Finder.app", directoryHint: .isDirectory)

    private init() {
        refresh()

        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { SystemAccess.shared.refresh() }
        }
    }

    func refresh() {
        hasFullDiskAccess = Self.canReadProtectedFile()
        isDefaultFileManager = Self.fileViewer() == Bundle.main.bundleIdentifier
    }

    // the list only holds apps added to it, so finder shows voyager ready to drag in
    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }

        NSWorkspace.shared.open([Bundle.main.bundleURL.deletingLastPathComponent()], withApplicationAt: Self.finder, configuration: NSWorkspace.OpenConfiguration())
        NSWorkspace.shared.open(url)
    }

    // launch services rejects any new folder handler (paramErr), so only reveals can move to voyager
    func makeDefault() {
        setFileViewer(Bundle.main.bundleIdentifier)
    }

    func restoreFinder() {
        setFileViewer(nil)
    }

    private func setFileViewer(_ bundleIdentifier: String?) {
        CFPreferencesSetValue(Self.fileViewerKey, bundleIdentifier as CFString?, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)

        let saved = CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        failure = saved ? nil : "The file viewer setting could not be saved."

        refresh()
    }

    // safari's folder sits behind full disk access, and trying it is what lists voyager under
    // full disk access in system settings; it never shows a prompt
    private static func canReadProtectedFile() -> Bool {
        let safari = URL.homeDirectory.appending(path: "Library/Safari", directoryHint: .isDirectory)

        return (try? FileManager.default.contentsOfDirectory(atPath: safari.path(percentEncoded: false))) != nil
    }

    private static func fileViewer() -> String? {
        CFPreferencesCopyAppValue(fileViewerKey, kCFPreferencesAnyApplication) as? String
    }
}
