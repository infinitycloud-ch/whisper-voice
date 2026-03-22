import Foundation

// Structure pour le résultat de l'organisation
struct OrganizationResult {
    struct FolderSuggestion {
        let name: String
        let transcriptions: [TranscriptionClassification]
        let description: String
    }
    
    struct TranscriptionClassification {
        let transcription: Transcription
        let folderName: String
        let confidence: Double
        let reason: String
    }
    
    let folders: [FolderSuggestion]
    let unclassified: [Transcription]
    let summary: String
}

class AIOrganizer {
    private let groqService = GroqChatService.shared
    private let confidenceThreshold = 0.7 // 70% de confiance minimum
    
    func organizeTranscriptions(_ transcriptions: [Transcription]) async throws -> OrganizationResult {
        print("🔍 AIOrganizer: Début de l'organisation de \(transcriptions.count) transcriptions")
        
        guard !transcriptions.isEmpty else {
            print("❌ AIOrganizer: Aucune transcription")
            throw OrganizerError.noTranscriptions
        }
        
        // Préparer le prompt pour l'IA
        print("📝 AIOrganizer: Création du prompt...")
        let prompt = createOrganizationPrompt(transcriptions)
        print("📝 AIOrganizer: Prompt créé (\(prompt.count) caractères)")
        
        // Envoyer à OpenAI pour analyse
        print("🚀 AIOrganizer: Envoi à OpenAI API...")
        let response = try await analyzeWithAI(prompt)
        print("📥 AIOrganizer: Réponse reçue de OpenAI")
        
        // Parser la réponse JSON
        print("🔧 AIOrganizer: Parsing de la réponse...")
        let classifications = try parseAIResponse(response, transcriptions: transcriptions)
        print("✅ AIOrganizer: \(classifications.count) classifications trouvées")
        
        // Grouper par dossiers
        print("📁 AIOrganizer: Construction du résultat...")
        let result = buildOrganizationResult(classifications, transcriptions: transcriptions)
        print("✅ AIOrganizer: Organisation terminée - \(result.folders.count) dossiers créés")
        
        return result
    }
    
    private func createOrganizationPrompt(_ transcriptions: [Transcription]) -> String {
        var prompt = """
        Analyse ces transcriptions et organise-les en dossiers thématiques.
        
        IMPORTANT: Réponds UNIQUEMENT avec du JSON valide, sans aucun texte avant ou après.
        
        Format JSON obligatoire:
        {
            "folders": [
                {"name": "Nom du dossier", "description": "Description"}
            ],
            "classifications": [
                {"index": 0, "folder": "Nom du dossier", "confidence": 0.95, "reason": "Raison"}
            ]
        }
        
        Règles:
        - Crée des dossiers pertinents (ex: Projets, Idées, Réunions, Notes)
        - Si incertain, mets folder: "Non classé" 
        - Maximum 10 dossiers
        - Noms courts et clairs en français
        
        Transcriptions à analyser:
        
        """
        
        // Ajouter les transcriptions avec index
        for (index, transcription) in transcriptions.enumerated() {
            let preview = String(transcription.text.prefix(200))
            prompt += """
            
            [Transcription \(index)]
            Date: \(transcription.formattedDate)
            Texte: \(preview)\(transcription.text.count > 200 ? "..." : "")
            
            """
        }
        
        return prompt
    }
    
    private func analyzeWithAI(_ prompt: String) async throws -> String {
        print("🔑 AIOrganizer: Vérification de la clé API OpenAI...")
        guard let apiKey = UserDefaults.standard.string(forKey: "openai_api_key"), !apiKey.isEmpty else {
            print("❌ AIOrganizer: Clé API OpenAI manquante")
            throw OrganizerError.missingAPIKey
        }
        print("✅ AIOrganizer: Clé API OpenAI trouvée")
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini", // Modèle OpenAI mini avec beaucoup de tokens
            "messages": [
                ["role": "system", "content": "Tu es un assistant expert en organisation et classification de documents. Tu réponds UNIQUEMENT en JSON valide."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3, // Plus déterministe pour la classification
            "max_tokens": 2000,
            "response_format": ["type": "json_object"] // OpenAI supporte ce format
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("📤 AIOrganizer: Envoi de la requête à OpenAI...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ AIOrganizer: Pas de réponse HTTP")
            throw OrganizerError.apiError
        }
        
        print("📥 AIOrganizer: Code de réponse HTTP: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ AIOrganizer: Erreur API OpenAI: \(errorString)")
            }
            throw OrganizerError.apiError
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OrganizerError.invalidResponse
        }
        
        return content
    }
    
    private func parseAIResponse(_ response: String, transcriptions: [Transcription]) throws -> [OrganizationResult.TranscriptionClassification] {
        guard let data = response.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let classifications = json["classifications"] as? [[String: Any]] else {
            throw OrganizerError.invalidResponse
        }
        
        var results: [OrganizationResult.TranscriptionClassification] = []
        
        for classification in classifications {
            guard let index = classification["index"] as? Int,
                  index < transcriptions.count,
                  let folderName = classification["folder"] as? String,
                  let confidence = classification["confidence"] as? Double,
                  let reason = classification["reason"] as? String else {
                continue
            }
            
            results.append(OrganizationResult.TranscriptionClassification(
                transcription: transcriptions[index],
                folderName: folderName,
                confidence: confidence,
                reason: reason
            ))
        }
        
        return results
    }
    
    private func buildOrganizationResult(_ classifications: [OrganizationResult.TranscriptionClassification], transcriptions: [Transcription]) -> OrganizationResult {
        var folderMap: [String: [OrganizationResult.TranscriptionClassification]] = [:]
        var unclassified: [Transcription] = []
        
        // Grouper les classifications par dossier
        for classification in classifications {
            if classification.confidence >= confidenceThreshold && classification.folderName != "Non classé" {
                if folderMap[classification.folderName] == nil {
                    folderMap[classification.folderName] = []
                }
                folderMap[classification.folderName]?.append(classification)
            } else {
                unclassified.append(classification.transcription)
            }
        }
        
        // Créer les suggestions de dossiers
        let folders = folderMap.map { (name, items) in
            OrganizationResult.FolderSuggestion(
                name: name,
                transcriptions: items,
                description: "Contient \(items.count) transcription(s)"
            )
        }.sorted { $0.transcriptions.count > $1.transcriptions.count }
        
        // Ajouter les transcriptions non analysées
        let analyzedIds = Set(classifications.map { $0.transcription.id })
        for transcription in transcriptions where !analyzedIds.contains(transcription.id) {
            unclassified.append(transcription)
        }
        
        let summary = """
        Organisation terminée:
        • \(folders.count) dossier(s) créé(s)
        • \(classifications.count - unclassified.count) transcription(s) classée(s)
        • \(unclassified.count) transcription(s) non classée(s)
        """
        
        return OrganizationResult(
            folders: folders,
            unclassified: unclassified,
            summary: summary
        )
    }
    
    func applyOrganization(_ result: OrganizationResult, folderManager: FolderTreeManager) {
        print("🚀 AIOrganizer: Début de l'application de l'organisation")
        print("📁 Nombre de dossiers à traiter: \(result.folders.count)")
        
        // Créer les dossiers et déplacer les transcriptions
        for folder in result.folders {
            print("📁 Traitement du dossier: \(folder.name)")
            
            // Créer le dossier s'il n'existe pas
            if !folderManager.rootNodes.contains(where: { $0.name == folder.name }) {
                print("➕ Création du dossier: \(folder.name)")
                folderManager.createFolder(name: folder.name)
            } else {
                print("✓ Dossier existant: \(folder.name)")
            }
            
            // Trouver le dossier créé
            if let targetFolder = folderManager.rootNodes.first(where: { $0.name == folder.name }) {
                print("📦 Déplacement de \(folder.transcriptions.count) transcriptions vers \(folder.name)")
                
                // Déplacer chaque transcription
                for classification in folder.transcriptions {
                    print("  → Déplacement: \(String(classification.transcription.text.prefix(30)))...")
                    folderManager.moveTranscription(id: classification.transcription.id, to: targetFolder)
                }
            } else {
                print("❌ Impossible de trouver le dossier: \(folder.name)")
            }
        }
        
        print("✅ AIOrganizer: Organisation appliquée avec succès")
    }
}

enum OrganizerError: LocalizedError {
    case noTranscriptions
    case missingAPIKey
    case apiError
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .noTranscriptions:
            return "Aucune transcription à organiser"
        case .missingAPIKey:
            return "Clé API OpenAI manquante. Configurez-la dans les paramètres."
        case .apiError:
            return "Erreur de l'API OpenAI. Vérifiez votre connexion."
        case .invalidResponse:
            return "Réponse invalide de l'IA"
        }
    }
}