//
//  Pins.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class Pins {
    static let shared = Pins()

    private(set) var folders: [URL]

    private init() {
        let paths = UserDefaults.standard.stringArray(forKey: Preferences.Key.pins) ?? []

        folders = paths.map { URL(filePath: $0, directoryHint: .isDirectory) }
    }

    func contains(_ url: URL) -> Bool {
        folders.contains { $0.folderKey == url.folderKey }
    }

    func pin(_ urls: [URL]) {
        folders += urls.filter { !contains($0) }
        save()
    }

    func unpin(_ urls: [URL]) {
        let keys = Set(urls.map(\.folderKey))

        folders.removeAll { keys.contains($0.folderKey) }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func save() {
        UserDefaults.standard.set(folders.map(\.folderKey), forKey: Preferences.Key.pins)
    }
}
