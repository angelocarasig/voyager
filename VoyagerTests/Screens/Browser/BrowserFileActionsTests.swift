//
//  BrowserFileActionsTests.swift
//  VoyagerTests
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import Testing
@testable import Voyager

@MainActor
@Suite("Browser file actions", .timeLimit(.minutes(1)))
struct BrowserFileActionsTests {

    private let clipboard = FileClipboard(pasteboard: NSPasteboard(name: NSPasteboard.Name("voyagerTests-\(UUID().uuidString)")))

    @Test("GIVEN a folder WHEN creating a new folder THEN it is selected and ready to rename")
    func newFolderStartsRename() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let vm = BrowserViewModel(start: temp.url, clipboard: clipboard)
        await vm.reload()

        // act
        await vm.newFolder()

        // assert
        #expect(vm.items.map(\.name) == ["untitled folder"])
        #expect(vm.selectedItems.map(\.name) == ["untitled folder"])
        #expect(vm.renaming?.name == "untitled folder")
    }

    @Test("GIVEN a cut file WHEN pasting into the current folder THEN it moves, is selected and the cut is used up")
    func pasteCut() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        let source = try temp.file("from/a.txt")
        let target = try temp.folder("to")
        let vm = BrowserViewModel(start: target, clipboard: clipboard)
        await vm.reload()
        clipboard.cut([source])

        // act
        await vm.paste(into: target)

        // assert
        #expect(vm.items.map(\.name) == ["a.txt"])
        #expect(vm.selectedItems.map(\.name) == ["a.txt"])
        #expect(!clipboard.canPaste)
    }

    @Test("GIVEN a name already used WHEN renaming THEN the failure is shown and the item keeps its name")
    func renameFailure() async throws {
        // arrange
        let temp = try TempFolder()
        defer { temp.remove() }
        try temp.file("a.txt")
        try temp.file("b.txt")
        let vm = BrowserViewModel(start: temp.url, clipboard: clipboard)
        await vm.reload()
        let item = try #require(vm.items.first { $0.name == "a.txt" })

        // act
        await vm.rename(item, to: "b.txt")

        // assert
        #expect(vm.operationFailure == FileOperationError.nameTaken("b.txt").errorDescription)
        #expect(Set(vm.items.map(\.name)) == ["a.txt", "b.txt"])
    }
}
