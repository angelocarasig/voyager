//
//  SidebarLocationsTests.swift
//  VoyagerTests
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation
import Testing
@testable import Voyager

@Suite("SidebarLocations", .timeLimit(.minutes(1)))
struct SidebarLocationsTests {

    private static let home = URL(filePath: "/Users/someone", directoryHint: .isDirectory)
    private static let missingNas = URL(filePath: "/no/such/nas-\(UUID().uuidString)", directoryHint: .isDirectory)
    private static let backup = URL(filePath: "/Volumes/Backup", directoryHint: .isDirectory)

    @Test("GIVEN a home folder WHEN building sections THEN places lists home, Desktop, Documents and Downloads")
    func places() {
        // act
        let sections = sidebarSections(home: Self.home, nasRoot: Self.missingNas, volumes: [])

        // assert
        #expect(sections.first?.title == "Places")
        #expect(sections.first?.locations.map(\.lastPathComponent) == ["someone", "Desktop", "Documents", "Downloads"])
    }

    @Test("GIVEN share folders and links under the NAS root WHEN building sections THEN NAS lists them sorted, hidden ones skipped")
    func nas() throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let target = try temp.folder("targets/torrents")
        try temp.folder("nas/Media")
        try temp.folder("nas/archive")
        try temp.folder("nas/.hidden")
        try temp.link("nas/torrents", to: target)

        // act
        let sections = sidebarSections(home: Self.home, nasRoot: temp.url.appending(path: "nas"), volumes: [])
        let nas = try #require(sections.first { $0.title == "NAS" })

        // assert
        #expect(nas.locations.map(\.lastPathComponent) == ["archive", "Media", "torrents"])
    }

    @Test("GIVEN no NAS root and no volumes WHEN building sections THEN only places shows")
    func missingSections() {
        // act
        let sections = sidebarSections(home: Self.home, nasRoot: Self.missingNas, volumes: [])

        // assert
        #expect(sections.map(\.title) == ["Places"])
    }

    @Test("GIVEN a volume that a NAS link points at WHEN building sections THEN it shows under NAS only")
    func duplicateVolume() throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let mounted = try temp.folder("Volumes/Media")
        try temp.folder("nas")
        try temp.link("nas/Media", to: mounted)

        // act
        let sections = sidebarSections(home: Self.home, nasRoot: temp.url.appending(path: "nas"), volumes: [mounted, Self.backup])

        // assert
        #expect(sections.map(\.title) == ["Places", "NAS", "Volumes"])
        #expect(sections.last?.locations == [Self.backup])
    }
}
