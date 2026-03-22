import Foundation
import SwiftUI

struct Transcription: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let timestamp: Date
    let duration: TimeInterval
    let audioURL: URL?
    let language: String
    let isPRD: Bool
    let prdTitle: String?
    var summary: String? // Résumé IA automatique
    var tags: [String] // Tags/étiquettes
    var translation: String? // Traduction FR↔EN
    var isAIModified: Bool // Texte modifié par l'IA (optimisé)

    init(text: String, audioURL: URL? = nil, timestamp: Date = Date(), duration: TimeInterval, language: String = "fr", isPRD: Bool = false, prdTitle: String? = nil, summary: String? = nil, tags: [String] = [], translation: String? = nil, isAIModified: Bool = false, id: UUID = UUID()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.audioURL = audioURL
        self.language = language
        self.isPRD = isPRD
        self.prdTitle = prdTitle
        self.summary = summary
        self.tags = tags
        self.translation = translation
        self.isAIModified = isAIModified
    }

    // Pour compatibilité
    init(text: String, timestamp: Date, duration: TimeInterval) {
        self.init(text: text, audioURL: nil, timestamp: timestamp, duration: duration, language: "fr", isPRD: false, prdTitle: nil, summary: nil, tags: [])
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Génère une couleur déterministe basée sur le nom du tag
    static func colorForTag(_ tag: String) -> Color {
        let colors: [Color] = [
            .blue, .purple, .pink, .red, .orange,
            .yellow, .green, .mint, .teal, .cyan, .indigo
        ]
        let hash = abs(tag.lowercased().hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Tag Suggestions

extension Transcription {
    static let suggestedTags = [
        "Perso", "Travail", "Important", "Idée",
        "À faire", "Rappel", "Note", "Réunion"
    ]
}