//
//  DesignerPalette.swift
//  RoomScanTest
//
//  Compatibility aliases - canonical tokens live in AppTheme.
//

import SwiftUI

enum DesignerPalette {
    static let primaryDark   = AppTheme.primaryDark
    static let secondaryTint = AppTheme.secondaryTint
    static let warmAccent    = AppTheme.warmAccent
    static let lightNeutral  = AppTheme.lightNeutral
    static let primaryText   = AppTheme.primaryText
    static let secondaryText = AppTheme.secondaryText
    static let tertiaryText  = AppTheme.tertiaryText
    static let accentGradient = AppTheme.accentGradient
    static let cornerRadius = AppTheme.cornerRadius
    static let buttonCornerRadius = AppTheme.buttonCornerRadius
}

typealias DesignerTopBarBackground = AppTopBarBackground
typealias DesignerPanelCard = AppPanelCard
typealias DesignerIconButton = AppIconButton
typealias DesignerPrimaryButtonStyle = GradientButtonStyle
typealias DesignerSecondaryChipButton = SecondaryChipButtonStyle

extension View {
    func designerPanel(cornerRadius: CGFloat = AppTheme.cornerRadius) -> some View {
        appPanel(cornerRadius: cornerRadius)
    }

    func designerIconButton(prominent: Bool = false) -> some View {
        appIconButton(prominent: prominent)
    }
}
