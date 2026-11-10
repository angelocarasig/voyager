//
//  ViewLayout.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

enum ViewLayout: String, CaseIterable, Codable, Identifiable {
    case extraLargeIcons, largeIcons, mediumIcons, smallIcons, list, details, tiles, content

    var id: Self { self }

    var title: String {
        switch self {
        case .extraLargeIcons: "Extra large icons"
        case .largeIcons: "Large icons"
        case .mediumIcons: "Medium icons"
        case .smallIcons: "Small icons"
        case .list: "List"
        case .details: "Details"
        case .tiles: "Tiles"
        case .content: "Content"
        }
    }

    var symbol: String {
        switch self {
        case .extraLargeIcons: "square.grid.2x2.fill"
        case .largeIcons: "square.grid.2x2"
        case .mediumIcons: "square.grid.3x3"
        case .smallIcons: "square.grid.4x3.fill"
        case .list: "list.bullet"
        case .details: "list.dash"
        case .tiles: "rectangle.grid.2x2"
        case .content: "text.below.photo"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .extraLargeIcons: "1"
        case .largeIcons: "2"
        case .mediumIcons: "3"
        case .smallIcons: "4"
        case .list: "5"
        case .details: "6"
        case .tiles: "7"
        case .content: "8"
        }
    }

    var defaultIconSize: Double {
        switch self {
        case .extraLargeIcons: 256
        case .largeIcons: 96
        case .mediumIcons: 64
        case .smallIcons, .list, .details: 16
        case .tiles: 48
        case .content: 32
        }
    }

    var isZoomable: Bool {
        switch self {
        case .extraLargeIcons, .largeIcons, .mediumIcons: true
        default: false
        }
    }
}
