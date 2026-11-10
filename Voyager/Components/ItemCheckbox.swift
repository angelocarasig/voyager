//
//  ItemCheckbox.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

struct ItemCheckbox: View {
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            RoundedRectangle(cornerRadius: 3)
                .fill(isOn ? Color.userAccent : Color.clear)
                .strokeBorder(isOn ? Color.userAccent : Color.white.opacity(0.5), lineWidth: 1)
                .frame(width: 16, height: 16)
                .overlay {
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.Mocha.base)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select item")
        .accessibilityValue(isOn ? "Selected" : "Not selected")
    }
}
