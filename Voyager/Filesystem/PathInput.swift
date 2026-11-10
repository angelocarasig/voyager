//
//  PathInput.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

func resolvePath(_ input: String, home: URL) -> URL? {
    guard let url = expandedURL(input, home: home), isFolder(url) else { return nil }

    return url
}

// a typed path to a file opens its folder with the file selected
func resolveFile(_ input: String, home: URL) -> URL? {
    guard let url = expandedURL(input, home: home),
          FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
          !isFolder(url)
    else { return nil }

    return url
}

// one matching folder completes with a trailing slash; several extend to the prefix they share
func completePath(_ input: String, home: URL) -> String? {
    guard let path = expandedPath(input, home: home), let slash = path.lastIndex(of: "/") else { return nil }

    let parent = String(path[...slash])
    let partial = String(path[path.index(after: slash)...])
    let names = (try? FileManager.default.contentsOfDirectory(atPath: parent)) ?? []

    let matches = names
        .filter { partial.hasPrefix(".") || !$0.hasPrefix(".") }
        .filter { $0.lowercased().hasPrefix(partial.lowercased()) }
        .filter { isFolder(URL(filePath: parent + $0, directoryHint: .isDirectory)) }
        .sorted()

    guard let first = matches.first else { return nil }

    if matches.count == 1 {
        return parent + first + "/"
    }

    let shared = matches.reduce(first) { prefix, name in
        String(zip(prefix, name).prefix { $0.lowercased() == $1.lowercased() }.map(\.0))
    }

    return shared.count > partial.count ? parent + shared : nil
}

private func expandedPath(_ input: String, home: URL) -> String? {
    var path = input.trimmingCharacters(in: .whitespacesAndNewlines)

    if path == "~" || path.hasPrefix("~/") {
        path = home.path(percentEncoded: false) + "/" + path.dropFirst()
    }

    return path.hasPrefix("/") ? path : nil
}

private func expandedURL(_ input: String, home: URL) -> URL? {
    expandedPath(input, home: home).map { URL(filePath: $0, directoryHint: .isDirectory).standardizedFileURL }
}

// packages such as apps are files to the browser, so they are not folders here either
func isFolder(_ url: URL) -> Bool {
    let values = try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])

    return values?.isDirectory == true && values?.isPackage != true
}

func breadcrumbs(for url: URL) -> [URL] {
    var trail = [URL(filePath: "/", directoryHint: .isDirectory)]

    for component in url.standardizedFileURL.pathComponents.dropFirst() {
        trail.append(trail[trail.count - 1].appending(path: component, directoryHint: .isDirectory))
    }

    return trail
}
