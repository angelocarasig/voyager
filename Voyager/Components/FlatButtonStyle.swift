//
//  FlatButtonStyle.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

struct FlatButtonStyle: ButtonStyle {
    var isOn = false

    func makeBody(configuration: Configuration) -> some View {
        FlatButton(configuration: configuration, isOn: isOn)
    }
}

extension ButtonStyle where Self == FlatButtonStyle {
    static var flat: FlatButtonStyle { FlatButtonStyle() }

    static func flat(isOn: Bool) -> FlatButtonStyle {
        FlatButtonStyle(isOn: isOn)
    }
}

private struct FlatButton: View {
    let configuration: ButtonStyleConfiguration
    let isOn: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.35)
            .padding(7)
            .frame(minWidth: 30, minHeight: 30)
            .background(Color.white.opacity(fillOpacity), in: .rect(cornerRadius: 8))
            .contentShape(.rect)
            .onHover { isHovered = $0 }
    }

    private var fillOpacity: Double {
        guard isEnabled else { return 0 }

        if configuration.isPressed {
            return 0.16
        }

        if isOn {
            return 0.12
        }

        return isHovered ? 0.08 : 0
    }
}
