import SwiftUI

enum AppTheme: String, CaseIterable {
    case cyberpunk = "Cyberpunk"
    case dark = "Sombre"
    case light = "Clair"
    case slate = "Ardoise"
    
    var backgroundColor: Color {
        switch self {
        case .cyberpunk: return Color(red: 0.05, green: 0.05, blue: 0.08)
        case .dark: return Color(red: 0.1, green: 0.1, blue: 0.12)
        case .light: return Color(red: 0.93, green: 0.92, blue: 0.90)
        case .slate: return Color(red: 0.15, green: 0.18, blue: 0.22)
        }
    }
    
    var secondaryBackgroundColor: Color {
        switch self {
        case .cyberpunk: return Color(red: 0.08, green: 0.08, blue: 0.12)
        case .dark: return Color(red: 0.15, green: 0.15, blue: 0.17)
        case .light: return Color(red: 0.88, green: 0.87, blue: 0.85)
        case .slate: return Color(red: 0.2, green: 0.23, blue: 0.27)
        }
    }
    
    var accentColor: Color {
        switch self {
        case .cyberpunk: return Color(red: 0.0, green: 0.8, blue: 0.9)
        case .dark: return Color(red: 0.3, green: 0.7, blue: 1.0)
        case .light: return Color(red: 0.0, green: 0.5, blue: 1.0)
        case .slate: return Color(red: 0.4, green: 0.6, blue: 0.8)
        }
    }
    
    var recordColor: Color {
        return .red
    }
    
    var textColor: Color {
        switch self {
        case .light: return Color.black
        default: return Color(red: 0.95, green: 0.95, blue: 0.95)
        }
    }
    
    var secondaryTextColor: Color {
        return .gray
    }
    
    // Couleurs spéciales pour les dossiers
    var folderInboxColor: Color { .blue }
    var folderWorkColor: Color { .orange }
    var folderPersonalColor: Color { .green }
    var folderArchiveColor: Color { .purple }
}
