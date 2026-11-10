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

    @Test("GIVEN a home folder WHEN building sections THEN places lists home, Desktop, Documents and Downloads")
    func places() {
        // act
        let sections = sidebarSections(home: Self.home, volumes: [])

        // assert
        #expect(sections.first?.title == "Places")
        #expect(sections.first?.locations.map(\.lastPathComponent) == ["someone", "Desktop", "Documents", "Downloads"])
    }

    @Test("GIVEN no volumes WHEN building sections THEN only places shows")
    func missingSections() {
        // act
        let sections = sidebarSections(home: Self.home, volumes: [])

        // assert
        #expect(sections.map(\.title) == ["Places"])
    }
}
