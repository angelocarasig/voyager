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
    case view
    case system

    var id: Self { self }

    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .window: "Window"
        case .view: "View"
        case .system: "System"
        }
    }

    var symbol: String {
        switch self {
        case .appearance: "textformat"
        case .window: "macwindow"
        case .view: "square.grid.2x2"
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
    case accent
    case backgroundBlur = "background.blur"
    case backgroundDim = "background.dim"
    case viewLayout = "view.layout"
    case viewIconSize = "view.iconSize"
    case viewCompact = "view.compact"
    case viewShowHidden = "view.showHidden"
    case viewShowExtensions = "view.showExtensions"
    case viewPreviewPane = "view.previewPane"
    case viewDetailsPane = "view.detailsPane"
    case viewCheckBoxes = "view.checkBoxes"
    case viewSort = "view.sort"
    case viewSortAscending = "view.sortAscending"
    case viewGroup = "view.group"
    case fullDiskAccess = "system.fullDiskAccess"
    case defaultFileManager = "system.defaultFileManager"

    var id: Self { self }

    var section: SettingSection {
        switch self {
        case .fontFamily, .fontSize, .accent: .appearance
        case .backgroundBlur, .backgroundDim: .window
        case .viewLayout, .viewIconSize, .viewCompact, .viewShowHidden, .viewShowExtensions, .viewPreviewPane,
             .viewDetailsPane, .viewCheckBoxes, .viewSort, .viewSortAscending, .viewGroup: .view
        case .fullDiskAccess, .defaultFileManager: .system
        }
    }

    var title: String {
        switch self {
        case .fontFamily: "Font Family"
        case .fontSize: "Font Size"
        case .accent: "Accent Colour"
        case .backgroundBlur: "Background Blur"
        case .backgroundDim: "Background Dim"
        case .viewLayout: "Layout"
        case .viewIconSize: "Icon Size"
        case .viewCompact: "Compact View"
        case .viewShowHidden: "Hidden Items"
        case .viewShowExtensions: "File Name Extensions"
        case .viewPreviewPane: "Preview Pane"
        case .viewDetailsPane: "Details Pane"
        case .viewCheckBoxes: "Item Check Boxes"
        case .viewSort: "Sort By"
        case .viewSortAscending: "Sort Order"
        case .viewGroup: "Group By"
        case .fullDiskAccess: "Full Disk Access"
        case .defaultFileManager: "Default File Manager"
        }
    }

    var detail: String {
        switch self {
        case .fontFamily: "The font used for file names, the sidebar and the path bar. Menus keep the system font."
        case .fontSize: "The base text size in points. Smaller labels scale with it."
        case .accent: "The colour of selections, check boxes, controls and folder icons."
        case .backgroundBlur: "How strongly the desktop behind the window is blurred, from 0 to 100."
        case .backgroundDim: "How much of the base colour covers the blur. 100% hides the desktop entirely."
        case .viewLayout: "How folders without their own view show their files."
        case .viewIconSize: "The icon size in points for the icon layouts, from 16 to 256."
        case .viewCompact: "Tightens the spacing between rows and items."
        case .viewShowHidden: "Lists files and folders whose names start with a dot or that macOS marks as hidden."
        case .viewShowExtensions: "Shows the extension at the end of file names. Folders always show their full name."
        case .viewPreviewPane: "Shows a preview of the selected item beside the list. Turns the details pane off."
        case .viewDetailsPane: "Shows the properties of the selected item beside the list. Turns the preview pane off."
        case .viewCheckBoxes: "Shows a check box on each item for selecting several without a modifier key."
        case .viewSort: "The property folders without their own view sort by."
        case .viewSortAscending: "Whether the sort runs from first to last or last to first."
        case .viewGroup: "The property folders without their own view group their items by."
        case .fullDiskAccess: "Lets Voyager open Desktop, Documents, Downloads, iCloud Drive and external drives without asking for each one. Granted in System Settings."
        case .defaultFileManager: "Shows files in Voyager when an app asks to reveal them, as with Show in Finder. Apps pick this up when they next launch. macOS keeps opening folders themselves in Finder."
        }
    }

    func matches(_ query: String) -> Bool {
        query.isEmpty || [title, detail, rawValue].contains { $0.localizedStandardContains(query) }
    }
}
