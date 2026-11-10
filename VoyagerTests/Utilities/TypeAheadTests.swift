//
//  TypeAheadTests.swift
//  VoyagerTests
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation
import Testing
@testable import Voyager

@Suite("TypeAhead", .timeLimit(.minutes(1)))
struct TypeAheadTests {

    private static let items = ["Desktop", "Documents", "Downloads", "Écoles"].map { name in
        FileItem(
            url: URL(filePath: "/Users/someone/\(name)"), name: name, size: nil, modified: nil,
            kind: "", type: nil, isDirectory: true, isPackage: false
        )
    }

    @Test("GIVEN a lowercase prefix WHEN matching THEN the first name starting with it is chosen")
    func prefix() {
        #expect(typeAheadMatch("do", in: Self.items) == Self.items[1].id)
    }

    @Test("GIVEN a prefix without accents WHEN matching THEN accented names still match")
    func diacritics() {
        #expect(typeAheadMatch("eco", in: Self.items) == Self.items[3].id)
    }

    @Test("GIVEN a prefix nothing starts with WHEN matching THEN there is no match")
    func noMatch() {
        #expect(typeAheadMatch("zzz", in: Self.items) == nil)
    }

    @Test("GIVEN a key typed within a second WHEN extending the buffer THEN it appends, otherwise it restarts")
    func buffer() {
        let start = Date(timeIntervalSince1970: 0)
        var typeAhead = TypeAhead()

        #expect(typeAhead.append("d", at: start) == "d")
        #expect(typeAhead.append("o", at: start.addingTimeInterval(0.5)) == "do")
        #expect(typeAhead.append("e", at: start.addingTimeInterval(2)) == "e")
    }
}
