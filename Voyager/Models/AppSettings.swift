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

    static let fontSizes = 9.0...24.0
    static let blurs = 0.0...100.0
    static let dims = 0.0...1.0

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
        case font, background
    }

    private enum FontKeys: String, CodingKey {
        case family, size
    }

    private enum BackgroundKeys: String, CodingKey {
        case blur, dim
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

        fontSize = fontSize.clamped(to: Self.fontSizes)
        backgroundBlur = backgroundBlur.clamped(to: Self.blurs)
        backgroundDim = backgroundDim.clamped(to: Self.dims)
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
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
