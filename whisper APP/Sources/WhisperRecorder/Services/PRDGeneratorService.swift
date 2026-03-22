import Foundation
import SwiftUI

class PRDGeneratorService {
    static let shared = PRDGeneratorService()
    
    private init() {}
    
    struct GeneratedPRD: Identifiable {
        let id = UUID()
        let title: String
        let content: String
        let sourceTranscriptions: [Transcription]
        let createdAt: Date
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: createdAt)
        }
    }
    
    @MainActor
    func generatePRD(from transcriptions: [Transcription], manager: TranscriptionManager) async {
        guard !transcriptions.isEmpty else { return }
        
        // Combine all transcription texts
        let combinedText = transcriptions.map { $0.text }.joined(separator: "\n\n---\n\n")
        
        // Generate PRD using AI with the specific prompt
        let prompt = """
        Analyse ces transcriptions et génère un PRD (Product Requirements Document).
        Courts et concis, droit au but.
        
        Format attendu:
        # Titre du Projet
        
        ## Objectif
        [Description concise de l'objectif principal]
        
        ## Fonctionnalités Clés
        - [Fonctionnalité 1]
        - [Fonctionnalité 2]
        - ...
        
        ## Exigences Techniques
        - [Exigence 1]
        - [Exigence 2]
        - ...
        
        ## Critères de Succès
        - [Critère 1]
        - [Critère 2]
        - ...
        
        Transcriptions à analyser:
        \(combinedText)
        """
        
        // Check if API key is configured
        let apiKey = UserDefaults.standard.string(forKey: "groq_api_key") ?? ""
        
        if apiKey.isEmpty {
            // Generate a sample PRD if no API key
            let samplePRD = generateSamplePRD(from: transcriptions)
            savePRD(samplePRD, manager: manager)
            return
        }
        
        // Call Groq API
        do {
            let prdContent = try await callGroqAPI(prompt: prompt, apiKey: apiKey)
            let prd = GeneratedPRD(
                title: extractTitle(from: prdContent) ?? "PRD - \(Date().formatted())",
                content: prdContent,
                sourceTranscriptions: transcriptions,
                createdAt: Date()
            )
            savePRD(prd, manager: manager)
        } catch {
            print("Error generating PRD: \(error)")
            // Fallback to sample PRD
            let samplePRD = generateSamplePRD(from: transcriptions)
            savePRD(samplePRD, manager: manager)
        }
    }
    
    private func callGroqAPI(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "mixtral-8x7b-32768",
            "messages": [
                ["role": "system", "content": "Tu es un expert en création de PRD. Sois court, concis et droit au but."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 2000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GroqResponse.self, from: data)
        
        return response.choices.first?.message.content ?? ""
    }
    
    private func generateSamplePRD(from transcriptions: [Transcription]) -> GeneratedPRD {
        let content = """
        # PRD - Projet basé sur \(transcriptions.count) transcription(s)
        
        ## Objectif
        Développer une solution basée sur les idées capturées dans les transcriptions vocales.
        
        ## Fonctionnalités Clés
        - Fonctionnalité principale identifiée dans les transcriptions
        - Support multi-plateforme (iOS, macOS)
        - Interface utilisateur intuitive
        - Synchronisation des données
        
        ## Exigences Techniques
        - SwiftUI pour l'interface
        - Core Data pour la persistance
        - CloudKit pour la synchronisation
        - Support iOS 16+ et macOS 13+
        
        ## Critères de Succès
        - Application fonctionnelle sur toutes les plateformes
        - Performance optimale
        - Expérience utilisateur fluide
        - Conformité App Store
        
        ## Notes
        Ce PRD a été généré automatiquement. Pour une analyse complète avec IA, configurez votre clé API Groq dans les paramètres.
        
        ## Transcriptions sources
        \(transcriptions.map { "- \($0.text.prefix(100))..." }.joined(separator: "\n"))
        """
        
        return GeneratedPRD(
            title: "PRD - \(Date().formatted())",
            content: content,
            sourceTranscriptions: transcriptions,
            createdAt: Date()
        )
    }
    
    private func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("# ") {
                return String(line.dropFirst(2))
            }
        }
        return nil
    }
    
    @MainActor
    private func savePRD(_ prd: GeneratedPRD, manager: TranscriptionManager) {
        // Create a new transcription with the PRD content
        let prdTranscription = Transcription(
            text: prd.content,
            audioURL: nil,
            duration: 0,
            language: "fr",
            isPRD: true,
            prdTitle: prd.title
        )
        
        // Add to manager
        manager.transcriptions.insert(prdTranscription, at: 0)
        manager.saveTranscriptions()
        
        // Show success notification
        #if os(macOS)
        NSSound.beep()
        #endif
        
        // Navigate to the new PRD
        manager.selectedTranscription = prdTranscription
    }
}

// MARK: - Groq Response Models
private struct GroqResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}