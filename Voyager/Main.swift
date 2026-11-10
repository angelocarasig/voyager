//
//  Main.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

@main
struct VoyagerApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            BrowserScreen()
        }
        .commands {
            SidebarCommands()
            BrowserCommands()
        }

        Settings {
            SettingsScreen()
        }
    }
}
