import Foundation
import SwiftUI

enum WindowMode: String {
    case full
    case medium
    case compact
}

@MainActor
class UIStateModel: ObservableObject {
    @Published var windowMode: WindowMode = .full

    // Compatibilité
    var isCompact: Bool {
        get { windowMode == .compact }
        set { windowMode = newValue ? .compact : .full }
    }

    var isMedium: Bool {
        get { windowMode == .medium }
        set { windowMode = newValue ? .medium : .full }
    }
}
