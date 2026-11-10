//
//  TypeAhead.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

struct TypeAhead {
    private var buffer = ""
    private var lastKey = Date.distantPast

    mutating func append(_ characters: String, at now: Date = .now) -> String {
        if now.timeIntervalSince(lastKey) > 1 {
            buffer = ""
        }

        buffer += characters
        lastKey = now

        return buffer
    }
}

func typeAheadMatch(_ prefix: String, in items: [FileItem]) -> FileItem.ID? {
    items.first {
        $0.name.range(of: prefix, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
    }?.id
}
