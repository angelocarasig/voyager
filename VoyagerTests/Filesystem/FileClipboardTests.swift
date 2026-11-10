//
//  FileClipboardTests.swift
//  VoyagerTests
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import Testing
@testable import Voyager

@MainActor
@Suite("FileClipboard", .timeLimit(.minutes(1)))
struct FileClipboardTests {

    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("voyagerTests-\(UUID().uuidString)"))
    private let a = URL(filePath: "/tmp/a.txt")
    private let b = URL(filePath: "/tmp/b.txt")

    @Test("GIVEN files WHEN copying THEN they can be pasted and are not a cut")
    func copy() {
        // arrange
        let clipboard = FileClipboard(pasteboard: pasteboard)

        // act
        clipboard.copy([a, b])

        // assert
        #expect(clipboard.urls == [a, b])
        #expect(clipboard.canPaste)
        #expect(!clipboard.isCut)
    }

    @Test("GIVEN a cut WHEN it is pasted THEN the clipboard empties")
    func cutThenPaste() {
        // arrange
        let clipboard = FileClipboard(pasteboard: pasteboard)
        clipboard.cut([a])
        #expect(clipboard.isCut)

        // act
        clipboard.didPaste()

        // assert
        #expect(!clipboard.canPaste)
        #expect(!clipboard.isCut)
    }

    @Test("GIVEN a copy WHEN it is pasted THEN it stays for another paste")
    func copyThenPaste() {
        // arrange
        let clipboard = FileClipboard(pasteboard: pasteboard)
        clipboard.copy([a])

        // act
        clipboard.didPaste()

        // assert
        #expect(clipboard.urls == [a])
    }

    @Test("GIVEN a cut WHEN copying afterwards THEN it is no longer a cut")
    func copyAfterCut() {
        // arrange
        let clipboard = FileClipboard(pasteboard: pasteboard)
        clipboard.cut([a])

        // act
        clipboard.copy([b])

        // assert
        #expect(!clipboard.isCut)
        #expect(clipboard.urls == [b])
    }

    @Test("GIVEN files on the clipboard WHEN cutting or copying nothing THEN the clipboard is kept")
    func emptyKeepsClipboard() {
        // arrange
        let clipboard = FileClipboard(pasteboard: pasteboard)
        clipboard.copy([a])

        // act
        clipboard.cut([])
        clipboard.copy([])

        // assert
        #expect(clipboard.urls == [a])
        #expect(!clipboard.isCut)
    }

    @Test("GIVEN two files WHEN copying their paths THEN the text is one path per line")
    func copyPaths() {
        // arrange
        let clipboard = FileClipboard(pasteboard: pasteboard)

        // act
        clipboard.copyPaths([a, b])

        // assert
        #expect(pasteboard.string(forType: .string) == "/tmp/a.txt\n/tmp/b.txt")
        #expect(!clipboard.canPaste)
    }
}
