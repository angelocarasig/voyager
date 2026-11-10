//
//  SettingKey.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

enum SettingSection: String, CaseIterable, Identifiable {
    case appearance
    case window
    case system

    var id: Self { self }

    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .window: "Window"
        case .system: "System"
        }
    }

    var symbol: String {
        switch self {
        case .appearance: "textformat"
        case .window: "macwindow"
        case .system: "gearshape"
        }
    }

    var keys: [SettingKey] {
        SettingKey.allCases.filter { $0.section == self }
    }
}

// raw values are the paths written in settings.json; system rows show macOS state and are never written
enum SettingKey: String, CaseIterable, Identifiable {
    case fontFamily = "font.family"
    case fontSize = "font.size"
    case backgroundBlur = "background.blur"
    case backgroundDim = "background.dim"
    case fullDiskAccess = "system.fullDiskAccess"
    case defaultFileManager = "system.defaultFileManager"

    var id: Self { self }

    var section: SettingSection {
        switch self {
        case .fontFamily, .fontSize: .appearance
        case .backgroundBlur, .backgroundDim: .window
        case .fullDiskAccess, .defaultFileManager: .system
        }
    }

    var title: String {
        switch self {
        case .fontFamily: "Font Family"
        case .fontSize: "Font Size"
        case .backgroundBlur: "Background Blur"
        case .backgroundDim: "Background Dim"
        case .fullDiskAccess: "Full Disk Access"
        case .defaultFileManager: "Default File Manager"
        }
    }

    var detail: String {
        switch self {
        case .fontFamily: "The font used for file names, the sidebar and the path bar. Menus keep the system font."
        case .fontSize: "The base text size in points. Smaller labels scale with it."
        case .backgroundBlur: "How strongly the desktop behind the window is blurred, from 0 to 100."
        case .backgroundDim: "How much of the base colour covers the blur. 100% hides the desktop entirely."
        case .fullDiskAccess: "Lets Voyager open Desktop, Documents, Downloads, iCloud Drive and external drives without asking for each one. Granted in System Settings."
        case .defaultFileManager: "Shows files in Voyager when an app asks to reveal them, as with Show in Finder. Apps pick this up when they next launch. macOS keeps opening folders themselves in Finder."
        }
    }

    func matches(_ query: String) -> Bool {
        query.isEmpty || [title, detail, rawValue].contains { $0.localizedStandardContains(query) }
    }
}
