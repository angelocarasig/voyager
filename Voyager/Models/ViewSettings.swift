//
//  ViewSettings.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

struct FolderView: Equatable, Codable, Sendable {
    var layout = ViewLayout.details
    var iconSize = 64.0
    var sort = SortField.name
    var ascending = true
    var group = GroupField.none

    static let iconSizes = 16.0...256.0
}

struct ViewSettings: Equatable {
    var layout = FolderView().layout
    var iconSize = FolderView().iconSize
    var compact = false
    var showHidden = false
    var showExtensions = true
    var previewPane = false
    var detailsPane = false
    var checkBoxes = false
    var sort = FolderView().sort
    var ascending = FolderView().ascending
    var group = FolderView().group

    var folder: FolderView {
        get { FolderView(layout: layout, iconSize: iconSize, sort: sort, ascending: ascending, group: group) }
        set {
            layout = newValue.layout
            iconSize = newValue.iconSize
            sort = newValue.sort
            ascending = newValue.ascending
            group = newValue.group
        }
    }
}
