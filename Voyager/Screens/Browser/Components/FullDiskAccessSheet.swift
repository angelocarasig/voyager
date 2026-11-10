//
//  FullDiskAccessSheet.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

// asked once at launch; the same switch stays in settings under system
struct FullDiskAccessSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.open.display")
                .font(.system(size: 40))
                .foregroundStyle(Color.Mocha.blue)

            Text("Allow Full Disk Access")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Without it, macOS asks before Voyager opens Desktop, Documents, Downloads, iCloud Drive or an external drive. Drag Voyager from the Finder window that opens into the Full Disk Access list, turn it on, then reopen Voyager.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Not Now") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Open Privacy Settings") {
                    SystemAccess.shared.openPrivacySettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 420)
    }
}
