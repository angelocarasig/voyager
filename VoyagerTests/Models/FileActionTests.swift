//
//  FileActionTests.swift
//  VoyagerTests
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI
import Testing
@testable import Voyager

@Suite("FileAction")
struct FileActionTests {

    private static func item(_ name: String, folder: Bool = false, package: Bool = false) -> FileItem {
        FileItem(
            url: URL(filePath: "/a/\(name)", directoryHint: folder ? .isDirectory : .notDirectory), name: name,
            size: nil, modified: nil, kind: "", type: nil, isDirectory: folder || package, isPackage: package
        )
    }

    private static func actions(_ items: [FileItem], pinned: Bool = false, canPaste: Bool = false) -> [FileAction] {
        FileAction.groups(for: items, isPinned: { _ in pinned }, canPaste: canPaste).flatMap(\.self)
    }

    @Test("GIVEN one file WHEN building the menu THEN it offers open with and rename but no folder actions")
    func singleFile() {
        // act
        let actions = Self.actions([Self.item("a.txt")], canPaste: true)

        // assert
        #expect(actions.contains(.openWith))
        #expect(actions.contains(.rename))
        #expect(!actions.contains(.openInTerminal))
        #expect(!actions.contains(.paste))
        #expect(!actions.contains(.pin))
    }

    @Test("GIVEN one folder and files on the clipboard WHEN building the menu THEN it offers terminal, paste and pin")
    func singleFolder() {
        // act
        let actions = Self.actions([Self.item("b", folder: true)], canPaste: true)

        // assert
        #expect(actions.contains(.openInTerminal))
        #expect(actions.contains(.paste))
        #expect(actions.contains(.pin))
        #expect(!actions.contains(.openWith))
    }

    @Test("GIVEN a pinned folder WHEN building the menu THEN it offers unpin instead of pin")
    func pinnedFolder() {
        // act
        let actions = Self.actions([Self.item("b", folder: true)], pinned: true)

        // assert
        #expect(actions.contains(.unpin))
        #expect(!actions.contains(.pin))
    }

    @Test("GIVEN an app package WHEN building the menu THEN it is treated as a file")
    func package() {
        // act
        let actions = Self.actions([Self.item("App.app", package: true)])

        // assert
        #expect(actions.contains(.openWith))
        #expect(!actions.contains(.pin))
    }

    @Test("GIVEN a file and a folder WHEN building the menu THEN single-item and folder-only actions are left out")
    func mixedSelection() {
        // act
        let actions = Self.actions([Self.item("a.txt"), Self.item("b", folder: true)], canPaste: true)

        // assert
        #expect(!actions.contains(.rename))
        #expect(!actions.contains(.openWith))
        #expect(!actions.contains(.pin))
        #expect(!actions.contains(.paste))
        #expect(actions.contains(.compress))
        #expect(actions.contains(.moveToTrash))
    }

    @Test("GIVEN empty space WHEN building the menu THEN it offers paste only when there is something to paste", arguments: [true, false])
    func emptySpace(canPaste: Bool) {
        // act
        let actions = Self.actions([], canPaste: canPaste)

        // assert
        #expect(actions.contains(.newFolder))
        #expect(actions.contains(.reload))
        #expect(actions.contains(.paste) == canPaste)
        #expect(!actions.contains(.moveToTrash))
    }

    @Test("GIVEN every action WHEN reading its shortcut THEN no two actions share one, except pin and unpin")
    func shortcutsAreUnique() {
        // act
        let keys = FileAction.allCases
            .filter { $0 != .unpin }
            .compactMap(\.shortcut)
            .map { "\($0.key.character)-\($0.modifiers.rawValue)" }

        // assert
        #expect(Set(keys).count == keys.count)
    }

    @Test("GIVEN every action WHEN reading its icon THEN each one has its own")
    func symbolsAreUnique() {
        // act
        let symbols = FileAction.allCases.map(\.symbol)

        // assert
        #expect(Set(symbols).count == symbols.count)
        #expect(!symbols.contains(""))
    }
}
