//
//  SettingsStore.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import Observation

// settings.json is the source of truth: edits made in any editor apply live, and the
// settings window writes back only when one of its controls changes
@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore(file: URL.homeDirectory.appending(path: ".config/voyager/settings.json"))

    var settings = AppSettings()
    private(set) var loadError: String?

    let file: URL

    @ObservationIgnored private var folderWatch: DispatchSourceFileSystemObject?
    @ObservationIgnored private var fileWatch: DispatchSourceFileSystemObject?

    init(file: URL) {
        self.file = file

        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        reload()

        // editors that save by replacing the file only show up as a change to the folder
        folderWatch = watch(file.deletingLastPathComponent(), for: .write)
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        do {
            try encoder.encode(settings).write(to: file, options: .atomic)
            loadError = nil
        } catch {
            loadError = "Could not save settings.json: \(error.localizedDescription)"
        }
    }

    func openFile() {
        if !FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            save()
        }

        NSWorkspace.shared.open(file)
    }

    private func reload() {
        // watching again before reading means a write landing mid-reload still triggers another one
        fileWatch?.cancel()
        fileWatch = watch(file, for: [.write, .extend, .delete, .rename])

        guard let data = try? Data(contentsOf: file) else {
            settings = AppSettings()
            loadError = nil
            return
        }

        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true

        // a broken file keeps the last good settings so a half-typed edit changes nothing
        do {
            let loaded = data.isEmpty ? AppSettings() : try decoder.decode(AppSettings.self, from: data)

            if loaded != settings {
                settings = loaded
            }

            loadError = nil
        } catch {
            loadError = Self.describe(error)
        }
    }

    private func watch(_ url: URL, for events: DispatchSource.FileSystemEvent) -> DispatchSourceFileSystemObject? {
        let descriptor = open(url.path(percentEncoded: false), O_EVTONLY)

        guard descriptor >= 0 else { return nil }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: events, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.reload() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()

        return source
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case DecodingError.dataCorrupted(let context):
            let detail = (context.underlyingError as NSError?)?.userInfo[NSDebugDescriptionErrorKey] as? String

            return "settings.json is not valid JSON. \(detail ?? context.debugDescription)"
        case DecodingError.typeMismatch(_, let context):
            let key = context.codingPath.map(\.stringValue).joined(separator: ".")

            return "\u{201C}\(key)\u{201D} in settings.json has the wrong type. \(context.debugDescription)"
        default:
            return "settings.json could not be read. \(error.localizedDescription)"
        }
    }
}
