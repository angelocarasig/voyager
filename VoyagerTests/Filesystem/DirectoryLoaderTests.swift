//
//  DirectoryLoaderTests.swift
//  VoyagerTests
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation
import Testing
@testable import Voyager

@Suite("DirectoryLoader", .timeLimit(.minutes(1)))
struct DirectoryLoaderTests {

    @Test("GIVEN files and a folder WHEN loaded THEN folders come first and names sort as Finder does")
    func order() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        try temp.file("b.txt")
        try temp.file("a10.txt")
        try temp.file("a2.txt")
        try temp.folder("zeta")

        // act
        let items = try await DirectoryLoader.load(temp.url, showingHidden: false)

        // assert
        #expect(items.map(\.name) == ["zeta", "a2.txt", "a10.txt", "b.txt"])
    }

    @Test("GIVEN a hidden file WHEN loaded THEN it is skipped")
    func hidden() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        try temp.file(".hidden")
        try temp.file("shown.txt")

        // act
        let items = try await DirectoryLoader.load(temp.url, showingHidden: false)

        // assert
        #expect(items.map(\.name) == ["shown.txt"])
    }

    @Test("GIVEN a five byte file WHEN loaded THEN its size and date are read and it opens as a file")
    func attributes() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        try temp.file("five.txt", contents: "12345")

        // act
        let item = try #require(try await DirectoryLoader.load(temp.url, showingHidden: false).first)

        // assert
        #expect(item.size == 5)
        #expect(item.modified != nil)
        #expect(item.opensAsFolder == false)
    }

    @Test("GIVEN an app bundle WHEN loaded THEN it is a package that does not open as a folder")
    func package() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        try temp.file("Thing.app/Contents/Info.plist")

        // act
        let item = try #require(try await DirectoryLoader.load(temp.url, showingHidden: false).first)

        // assert
        #expect(item.isDirectory)
        #expect(item.isPackage)
        #expect(item.opensAsFolder == false)
    }

    @Test("GIVEN a symlink to a folder WHEN loaded THEN it opens as a folder and keeps the link's URL")
    func symlink() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let real = try temp.folder("real")
        let link = try temp.link("link", to: real)

        // act
        let items = try await DirectoryLoader.load(temp.url, showingHidden: false)
        let item = try #require(items.first { $0.name == "link" })

        // assert
        #expect(item.opensAsFolder)
        #expect(item.url.lastPathComponent == link.lastPathComponent)
    }

    @Test("GIVEN a broken symlink WHEN loaded THEN the folder still loads and the link opens as a file")
    func brokenSymlink() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        try temp.link("dangling", to: temp.url.appending(path: "missing"))
        try temp.file("ok.txt")

        // act
        let items = try await DirectoryLoader.load(temp.url, showingHidden: false)

        // assert
        #expect(items.map(\.name).sorted() == ["dangling", "ok.txt"])
        #expect(items.allSatisfy { !$0.opensAsFolder })
    }

    @Test("GIVEN a folder that does not exist WHEN loaded THEN it throws")
    func missing() async throws {
        // arrange
        let missing = URL(filePath: "/no/such/folder-\(UUID().uuidString)")

        // act, assert
        await #expect(throws: (any Error).self) { try await DirectoryLoader.load(missing, showingHidden: false) }
    }
}
