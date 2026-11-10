//
//  OpenRequests.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import Observation

// folders and files other apps ask voyager to show, waiting for the front window to take them
@MainActor
@Observable
final class OpenRequests {
    static let shared = OpenRequests()

    private(set) var pending: [[URL]] = []

    func add(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        pending.append(urls)
    }

    func take() -> [URL]? {
        pending.isEmpty ? nil : pending.removeFirst()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // swiftui answers open events itself, so voyager takes them over before launch finishes;
    // the reveal event comes from apps that show files in whichever app NSFileViewer names
    func applicationWillFinishLaunching(_ notification: Notification) {
        installHandlers()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installHandlers()
    }

    private func installHandlers() {
        let events = NSAppleEventManager.shared()

        for (eventClass, eventID) in [(kCoreEventClass, kAEOpenDocuments), (kAEMiscStandards, kAEMakeObjectsVisible)] {
            events.setEventHandler(self, andSelector: #selector(open(_:reply:)), forEventClass: AEEventClass(eventClass), andEventID: AEEventID(eventID))
        }
    }

    @objc private func open(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let items = event.paramDescriptor(forKeyword: keyDirectObject) else { return }

        let descriptors = items.numberOfItems == 0 ? [items] : (1...items.numberOfItems).compactMap(items.atIndex)

        OpenRequests.shared.add(descriptors.compactMap(\.fileURLValue))
    }
}
