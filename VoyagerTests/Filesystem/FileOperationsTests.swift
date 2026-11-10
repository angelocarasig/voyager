//
//  FileOperationsTests.swift
//  VoyagerTests
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation
import Testing
@testable import Voyager

@Suite("FileOperations", .timeLimit(.minutes(1)))
struct FileOperationsTests {

    private func names(in folder: URL) throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)))
    }

    @Test("GIVEN a file WHEN duplicating it twice THEN the copies are named copy and copy 2")
    func duplicateNames() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let file = try temp.file("notes.txt", contents: "hi")

        // act
        let first = try await FileOperations.duplicate([file])
        let second = try await FileOperations.duplicate([file])

        // assert
        #expect(first.map(\.lastPathComponent) == ["notes copy.txt"])
        #expect(second.map(\.lastPathComponent) == ["notes copy 2.txt"])
        #expect(try String(contentsOf: second[0], encoding: .utf8) == "hi")
    }

    @Test("GIVEN an untitled folder already exists WHEN creating a new folder THEN it is numbered")
    func newFolderName() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        try temp.folder("untitled folder")

        // act
        let folder = try await FileOperations.newFolder(in: temp.url)

        // assert
        #expect(folder.lastPathComponent == "untitled folder 2")
        #expect(try names(in: temp.url) == ["untitled folder", "untitled folder 2"])
    }

    @Test("GIVEN a name that is already used WHEN renaming THEN it fails and nothing moves")
    func renameTaken() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let file = try temp.file("a.txt")
        try temp.file("b.txt")

        // act, assert
        await #expect(throws: FileOperationError.nameTaken("b.txt")) {
            try await FileOperations.rename(file, to: "b.txt")
        }
        #expect(try names(in: temp.url) == ["a.txt", "b.txt"])
    }

    @Test("GIVEN an invalid name WHEN renaming THEN it fails", arguments: ["", "  ", ".hidden", "a/b", "a:b"])
    func renameInvalid(name: String) async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let file = try temp.file("a.txt")

        // act, assert
        await #expect(throws: FileOperationError.invalidName) {
            try await FileOperations.rename(file, to: name)
        }
    }

    @Test("GIVEN a file WHEN renaming it with only a case change THEN the new casing is kept")
    func renameCaseOnly() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let file = try temp.file("readme.md")

        // act
        let renamed = try await FileOperations.rename(file, to: "README.md")

        // assert
        #expect(renamed.lastPathComponent == "README.md")
        #expect(try names(in: temp.url) == ["README.md"])
    }

    @Test("GIVEN a name clash WHEN pasting a copy THEN both files are kept")
    func pasteCopyClash() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let source = try temp.file("from/a.txt", contents: "new")
        let target = try temp.folder("to")
        try temp.file("to/a.txt", contents: "old")

        // act
        let pasted = try await FileOperations.paste([source], into: target, move: false)

        // assert
        #expect(pasted.map(\.lastPathComponent) == ["a copy.txt"])
        #expect(try names(in: target) == ["a.txt", "a copy.txt"])
        #expect(FileManager.default.fileExists(atPath: source.path(percentEncoded: false)))
    }

    @Test("GIVEN a cut file WHEN pasting it elsewhere THEN it moves")
    func pasteMove() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let source = try temp.file("from/a.txt")
        let target = try temp.folder("to")

        // act
        _ = try await FileOperations.paste([source], into: target, move: true)

        // assert
        #expect(try names(in: target) == ["a.txt"])
        #expect(!FileManager.default.fileExists(atPath: source.path(percentEncoded: false)))
    }

    @Test("GIVEN a cut file WHEN pasting it into its own folder THEN nothing changes")
    func pasteMoveSameFolder() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let source = try temp.file("a.txt")

        // act
        let pasted = try await FileOperations.paste([source], into: temp.url, move: true)

        // assert
        #expect(pasted == [source])
        #expect(try names(in: temp.url) == ["a.txt"])
    }

    @Test("GIVEN a folder WHEN pasting it into its own subfolder THEN it fails")
    func pasteIntoItself() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let folder = try temp.folder("outer")
        let inner = try temp.folder("outer/inner")

        // act, assert
        await #expect(throws: FileOperationError.pasteIntoItself) {
            try await FileOperations.paste([folder], into: inner, move: false)
        }
    }

    @Test("GIVEN one item and then two WHEN compressing THEN the archives are named after the item and Archive")
    func compressNames() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let a = try temp.file("a.txt", contents: "a")
        let b = try temp.file("b.txt", contents: "b")

        // act
        let single = try await FileOperations.compress([a])
        let several = try await FileOperations.compress([a, b])

        // assert
        #expect(single.lastPathComponent == "a.txt.zip")
        #expect(several.lastPathComponent == "Archive.zip")
        #expect(try names(in: temp.url) == ["a.txt", "b.txt", "a.txt.zip", "Archive.zip"])
    }
}
