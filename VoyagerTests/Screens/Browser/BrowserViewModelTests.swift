//
//  BrowserViewModelTests.swift
//  VoyagerTests
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation
import Testing
@testable import Voyager

@MainActor
@Suite("BrowserViewModel", .timeLimit(.minutes(1)))
struct BrowserViewModelTests {

    private nonisolated static let root = URL(filePath: "/", directoryHint: .isDirectory)
    private nonisolated static let folderA = URL(filePath: "/a", directoryHint: .isDirectory)
    private nonisolated static let folderB = URL(filePath: "/a/b", directoryHint: .isDirectory)

    private nonisolated static func entry(_ name: String, in folder: URL, folder isFolder: Bool = false) -> FileItem {
        FileItem(
            url: folder.appending(path: name), name: name, size: isFolder ? nil : 1, modified: nil,
            kind: "", type: nil, isDirectory: isFolder, isPackage: false
        )
    }

    private nonisolated static func listing(_ folder: URL) -> [FileItem] {
        [entry("\(folder.lastPathComponent)1", in: folder)]
    }

    @Test("GIVEN a selection WHEN navigating THEN the new folder's items load and the selection clears")
    func navigate() async {
        // arrange
        let vm = BrowserViewModel(start: Self.folderA) { Self.listing($0) }
        await vm.reload()
        vm.selection = [Self.folderA.appending(path: "a1")]

        // act
        await vm.navigate(to: Self.folderB)

        // assert
        #expect(vm.current == Self.folderB)
        #expect(vm.items.map(\.name) == ["b1"])
        #expect(vm.selection.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test("GIVEN two folders visited WHEN going back, forward and up THEN each lands on the expected folder")
    func history() async {
        // arrange
        let vm = BrowserViewModel(start: Self.folderA) { Self.listing($0) }
        await vm.navigate(to: Self.folderB)

        // act, assert
        await vm.goBack()
        #expect(vm.current == Self.folderA)
        #expect(vm.canGoForward)

        await vm.goForward()
        #expect(vm.current == Self.folderB)
        #expect(vm.canGoForward == false)

        await vm.goUp()
        #expect(vm.current == Self.folderA)
        #expect(vm.canGoBack)
    }

    @Test("GIVEN a folder that cannot be read WHEN navigating THEN the list empties and a failure shows")
    func failure() async {
        // arrange
        let vm = BrowserViewModel(start: Self.folderA) { folder in
            if folder == Self.folderB {
                throw CocoaError(.fileReadNoPermission)
            }

            return Self.listing(folder)
        }
        await vm.reload()

        // act
        await vm.navigate(to: Self.folderB)

        // assert
        #expect(vm.current == Self.folderB)
        #expect(vm.items.isEmpty)
        #expect(vm.failure != nil)
        #expect(vm.isLoading == false)
    }

    @Test("GIVEN a slow folder still loading WHEN another folder is opened THEN the slow listing never replaces it")
    func staleLoad() async {
        // arrange
        let slow = URL(filePath: "/slow", directoryHint: .isDirectory)
        let fast = URL(filePath: "/fast", directoryHint: .isDirectory)
        let (gate, open) = AsyncStream<Void>.makeStream()
        let vm = BrowserViewModel(start: Self.root) { folder in
            if folder == slow {
                for await _ in gate { break }
            }

            return Self.listing(folder)
        }
        let slowNavigation = Task { await vm.navigate(to: slow) }
        await until { vm.current == slow }

        // act
        await vm.navigate(to: fast)
        open.yield()
        open.finish()
        await slowNavigation.value

        // assert
        #expect(vm.current == fast)
        #expect(vm.items.map(\.name) == ["fast1"])
        #expect(vm.isLoading == false)
    }

    @Test("GIVEN the root folder WHEN going up THEN nothing changes")
    func upAtRoot() async {
        // arrange
        let vm = BrowserViewModel(start: Self.root) { Self.listing($0) }

        // act
        await vm.goUp()

        // assert
        #expect(vm.current == Self.root)
        #expect(vm.canGoBack == false)
    }

    @Test("GIVEN a folder and a file WHEN sorted by name descending THEN the folder still comes first")
    func sorting() async {
        // arrange
        let vm = BrowserViewModel(start: Self.folderA) { folder in
            [
                Self.entry("apple.txt", in: folder),
                Self.entry("zebra.txt", in: folder),
                Self.entry("music", in: folder, folder: true),
            ]
        }
        await vm.reload()

        // act
        vm.sortOrder = [KeyPathComparator(\FileItem.name, comparator: .localizedStandard, order: .reverse)]

        // assert
        #expect(vm.items.map(\.name) == ["music", "zebra.txt", "apple.txt"])
    }
}
