//
//  Notification+Extensions.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 04.03.2026.
//

import Foundation

extension Notification.Name {
    /// Posted when the user toggles between orbit and first-person camera modes.
    /// `userInfo["firstPerson"]` is a `Bool`.
    static let switchCameraMode = Notification.Name("switchCameraMode")
}
