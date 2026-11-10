//
//  GroupField.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

enum GroupField: String, CaseIterable, Codable, Identifiable {
    case none, kind, modified, size, name

    var id: Self { self }

    var title: String {
        switch self {
        case .none: "None"
        case .kind: "Type"
        case .modified: "Date modified"
        case .size: "Size"
        case .name: "Name"
        }
    }
}
