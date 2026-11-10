//
//  Preferences.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

enum Preferences {
    enum Key {
        // one app-wide value - folders deliberately do not remember their own view
        static let viewMode = "browser.viewMode"
        static let pins = "sidebar.pins"
        static let askedForFullDiskAccess = "system.askedForFullDiskAccess"
    }
}
