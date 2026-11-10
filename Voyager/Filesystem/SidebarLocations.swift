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

func sidebarSections(home: URL, volumes: [URL]) -> [SidebarSection] {
    let places = [home] + ["Desktop", "Documents", "Downloads"].map {
        home.appending(path: $0, directoryHint: .isDirectory)
    }

    var sections = [SidebarSection(title: "Places", locations: places)]

    if !volumes.isEmpty {
        sections.append(SidebarSection(title: "Volumes", locations: volumes))
    }

    return sections
}
