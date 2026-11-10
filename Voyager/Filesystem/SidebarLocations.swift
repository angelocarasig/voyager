//
//  SidebarLocations.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

struct SidebarSection: Identifiable, Hashable {
    let title: String
    let locations: [URL]

    var id: String { title }
}

func sidebarSections(
    home: URL,
    nasRoot: URL = URL(filePath: "/mnt/NAS", directoryHint: .isDirectory),
    volumes: [URL]
) -> [SidebarSection] {
    let places = [home] + ["Desktop", "Documents", "Downloads"].map {
        home.appending(path: $0, directoryHint: .isDirectory)
    }

    let shares = ((try? FileManager.default.contentsOfDirectory(
        at: nasRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
    )) ?? [])
        .filter { (try? $0.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

    // the shares are symlinks into /Volumes, so their mounts would otherwise show twice
    let shareTargets = Set(shares.map { $0.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false) })
    let others = volumes.filter {
        !shareTargets.contains($0.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false))
    }

    var sections = [SidebarSection(title: "Places", locations: places)]

    if !shares.isEmpty {
        sections.append(SidebarSection(title: "NAS", locations: shares))
    }

    if !others.isEmpty {
        sections.append(SidebarSection(title: "Volumes", locations: others))
    }

    return sections
}
