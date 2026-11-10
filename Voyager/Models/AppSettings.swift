//
//  AppSettings.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI

struct AppSettings: Equatable {
    var fontFamily = ""
    var fontSize = 13.0
    var backgroundBlur = 20.0
    var backgroundDim = 0.85
    var accent: UInt32 = 0x89B4FA
    var view = ViewSettings()
    // nil until the network shares connected on first launch fill it
    var shares: [String]?

    static let fontSizes = 9.0...24.0
    static let blurs = 0.0...100.0
    static let dims = 0.0...1.0
    static let accents: [UInt32] = [0x89B4FA, 0xB4BEFE, 0xCBA6F7, 0xF5C2E7, 0xF38BA8, 0xFAB387, 0xA6E3A1]

    var isFontInstalled: Bool {
        fontFamily.isEmpty || NSFontManager.shared.availableFontFamilies.contains(fontFamily)
    }

    // swiftui falls back to the system font when the family is not installed
    func font(scale: Double = 1) -> Font {
        let size = (fontSize * scale).rounded()

        return fontFamily.isEmpty ? .system(size: size) : .custom(fontFamily, size: size)
    }
}

// the file only holds what differs from the defaults, nested the way it reads in settings.json
extension AppSettings: Codable {
    private enum Keys: String, CodingKey {
        case font, background, accent, view, shares
    }

    private enum FontKeys: String, CodingKey {
        case family, size
    }

    private enum BackgroundKeys: String, CodingKey {
        case blur, dim
    }

    private enum ViewKeys: String, CodingKey {
        case layout, iconSize, compact, showHidden, showExtensions, previewPane, detailsPane, checkBoxes
        case sort, sortAscending, group
    }

    init(from decoder: Decoder) throws {
        self.init()

        let root = try decoder.container(keyedBy: Keys.self)

        if root.contains(.font) {
            let font = try root.nestedContainer(keyedBy: FontKeys.self, forKey: .font)
            fontFamily = try font.decodeIfPresent(String.self, forKey: .family) ?? fontFamily
            fontSize = try font.decodeIfPresent(Double.self, forKey: .size) ?? fontSize
        }

        if root.contains(.background) {
            let background = try root.nestedContainer(keyedBy: BackgroundKeys.self, forKey: .background)
            backgroundBlur = try background.decodeIfPresent(Double.self, forKey: .blur) ?? backgroundBlur
            backgroundDim = try background.decodeIfPresent(Double.self, forKey: .dim) ?? backgroundDim
        }

        if let hex = (try? root.decodeIfPresent(String.self, forKey: .accent)).flatMap({ $0 }),
           let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16), value <= 0xFFFFFF {
            accent = value
        }

        if root.contains(.view) {
            let container = try root.nestedContainer(keyedBy: ViewKeys.self, forKey: .view)

            view.layout = container.lenient(ViewLayout.self, forKey: .layout) ?? view.layout
            view.iconSize = try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? view.iconSize
            view.compact = try container.decodeIfPresent(Bool.self, forKey: .compact) ?? view.compact
            view.showHidden = try container.decodeIfPresent(Bool.self, forKey: .showHidden) ?? view.showHidden
            view.showExtensions = try container.decodeIfPresent(Bool.self, forKey: .showExtensions) ?? view.showExtensions
            view.previewPane = try container.decodeIfPresent(Bool.self, forKey: .previewPane) ?? view.previewPane
            view.detailsPane = try container.decodeIfPresent(Bool.self, forKey: .detailsPane) ?? view.detailsPane
            view.checkBoxes = try container.decodeIfPresent(Bool.self, forKey: .checkBoxes) ?? view.checkBoxes
            view.sort = container.lenient(SortField.self, forKey: .sort) ?? view.sort
            view.ascending = try container.decodeIfPresent(Bool.self, forKey: .sortAscending) ?? view.ascending
            view.group = container.lenient(GroupField.self, forKey: .group) ?? view.group
        }

        shares = try root.decodeIfPresent([String].self, forKey: .shares)

        fontSize = fontSize.clamped(to: Self.fontSizes)
        backgroundBlur = backgroundBlur.clamped(to: Self.blurs)
        backgroundDim = backgroundDim.clamped(to: Self.dims)
        view.iconSize = view.iconSize.clamped(to: FolderView.iconSizes)

        if view.previewPane {
            view.detailsPane = false
        }
    }

    func encode(to encoder: Encoder) throws {
        let defaults = AppSettings()
        var root = encoder.container(keyedBy: Keys.self)

        if fontFamily != defaults.fontFamily || fontSize != defaults.fontSize {
            var font = root.nestedContainer(keyedBy: FontKeys.self, forKey: .font)

            if fontFamily != defaults.fontFamily {
                try font.encode(fontFamily, forKey: .family)
            }

            if fontSize != defaults.fontSize {
                try font.encode(fontSize, forKey: .size)
            }
        }

        if backgroundBlur != defaults.backgroundBlur || backgroundDim != defaults.backgroundDim {
            var background = root.nestedContainer(keyedBy: BackgroundKeys.self, forKey: .background)

            if backgroundBlur != defaults.backgroundBlur {
                try background.encode(backgroundBlur, forKey: .blur)
            }

            if backgroundDim != defaults.backgroundDim {
                try background.encode(backgroundDim, forKey: .dim)
            }
        }

        if accent != defaults.accent {
            try root.encode(String(format: "#%06X", accent), forKey: .accent)
        }

        if view != defaults.view {
            var container = root.nestedContainer(keyedBy: ViewKeys.self, forKey: .view)
            let base = defaults.view

            try container.encode(view.layout, unless: base.layout, forKey: .layout)
            try container.encode(view.iconSize, unless: base.iconSize, forKey: .iconSize)
            try container.encode(view.compact, unless: base.compact, forKey: .compact)
            try container.encode(view.showHidden, unless: base.showHidden, forKey: .showHidden)
            try container.encode(view.showExtensions, unless: base.showExtensions, forKey: .showExtensions)
            try container.encode(view.previewPane, unless: base.previewPane, forKey: .previewPane)
            try container.encode(view.detailsPane, unless: base.detailsPane, forKey: .detailsPane)
            try container.encode(view.checkBoxes, unless: base.checkBoxes, forKey: .checkBoxes)
            try container.encode(view.sort, unless: base.sort, forKey: .sort)
            try container.encode(view.ascending, unless: base.ascending, forKey: .sortAscending)
            try container.encode(view.group, unless: base.group, forKey: .group)
        }

        try root.encodeIfPresent(shares, forKey: .shares)
    }
}

private extension KeyedDecodingContainer {
    // an unknown raw value falls back to the default instead of failing the whole file
    func lenient<Value: RawRepresentable>(_ type: Value.Type, forKey key: Key) -> Value? where Value.RawValue == String {
        (try? decodeIfPresent(String.self, forKey: key)).flatMap { $0 }.flatMap(Value.init(rawValue:))
    }
}

private extension KeyedEncodingContainer {
    mutating func encode<Value: Encodable & Equatable>(_ value: Value, unless base: Value, forKey key: Key) throws {
        guard value != base else { return }

        try encode(value, forKey: key)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
