//
//  PathInputTests.swift
//  VoyagerTests
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation
import Testing
@testable import Voyager

@Suite("PathInput", .timeLimit(.minutes(1)))
struct PathInputTests {

    @Test("GIVEN a tilde WHEN resolving THEN it expands to the home folder")
    func tilde() throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let documents = try temp.folder("Documents")

        // act, assert
        #expect(resolvePath("~", home: temp.url)?.path == temp.url.path)
        #expect(resolvePath("~/Documents", home: temp.url)?.path == documents.path)
    }

    @Test("GIVEN surrounding whitespace and a trailing slash WHEN resolving THEN the folder is found")
    func trailingSlash() throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let folder = try temp.folder("work")

        // act
        let resolved = resolvePath("  \(folder.path(percentEncoded: false)) \n", home: temp.url)

        // assert
        #expect(resolved?.path == folder.path)
    }

    @Test("GIVEN a path that does not exist WHEN resolving THEN there is no result")
    func missing() {
        #expect(resolvePath("/no/such/folder-\(UUID().uuidString)", home: URL(filePath: "/")) == nil)
    }

    @Test("GIVEN a path to a file WHEN resolving THEN there is no result")
    func file() throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let file = try temp.file("notes.txt")

        // act, assert
        #expect(resolvePath(file.path(percentEncoded: false), home: temp.url) == nil)
    }

    @Test("GIVEN a NAS share path WHEN building breadcrumbs THEN they run from the root to the folder")
    func breadcrumbTrail() {
        let trail = breadcrumbs(for: URL(filePath: "/mnt/NAS/Media", directoryHint: .isDirectory))

        #expect(trail.map { $0.path(percentEncoded: false) } == ["/", "/mnt/", "/mnt/NAS/", "/mnt/NAS/Media/"])
    }

    @Test("GIVEN the root WHEN building breadcrumbs THEN there is one crumb")
    func rootTrail() {
        #expect(breadcrumbs(for: URL(filePath: "/")).map { $0.path(percentEncoded: false) } == ["/"])
    }
}
