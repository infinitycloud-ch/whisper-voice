import Foundation

/// Service for optimizing text using Groq API (fast LLM)
class TextOptimizationService {
    static let shared = TextOptimizationService()

    private let groqEndpoint = "https://api.groq.com/openai/v1/chat/completions"
    private let model = "llama-3.3-70b-versatile"

    private init() {}

    /// Optimize text to be more concise and effective
    func optimizeText(_ text: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OptimizationError.noAPIKey
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OptimizationError.emptyText
        }

        guard let url = URL(string: groqEndpoint) else {
            throw OptimizationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let systemPrompt = """
        Tu es un assistant qui optimise les messages. Ton rôle:
        - Rendre le texte plus concis et efficace
        - Garder un langage naturel et direct
        - Aller droit au but
        - Raccourcir si possible sans perdre le sens
        - Garder le même ton (formel/informel)
        - Corriger les fautes d'orthographe et de grammaire
        - Répondre UNIQUEMENT avec le texte optimisé, sans explication
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "max_tokens": 1024,
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OptimizationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OptimizationError.apiError(message)
            }
            throw OptimizationError.apiError("Status code: \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OptimizationError.parseError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generate a concise summary of a long text
    func summarizeText(_ text: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OptimizationError.noAPIKey
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OptimizationError.emptyText
        }

        guard let url = URL(string: groqEndpoint) else {
            throw OptimizationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let systemPrompt = """
        Tu es un assistant qui crée des résumés concis. Ton rôle:
        - Extraire les points clés du texte
        - Créer un résumé en 2-3 phrases maximum
        - Garder les informations essentielles (noms, dates, actions)
        - Utiliser un style direct et informatif
        - Répondre UNIQUEMENT avec le résumé, sans introduction ni explication
        - Si le texte est très court (< 50 mots), reformuler simplement en une phrase
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Résume ce texte:\n\n\(text)"]
            ],
            "max_tokens": 256,
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OptimizationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OptimizationError.apiError(message)
            }
            throw OptimizationError.apiError("Status code: \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OptimizationError.parseError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Translate text between French and English (auto-detect source)
    func translateText(_ text: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OptimizationError.noAPIKey
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OptimizationError.emptyText
        }

        guard let url = URL(string: groqEndpoint) else {
            throw OptimizationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let systemPrompt = """
        Tu es un traducteur expert FR↔EN. Ton rôle:
        - Détecter automatiquement la langue source (français ou anglais)
        - Si le texte est en français → traduire en anglais
        - Si le texte est en anglais → traduire en français
        - Garder le même ton et style
        - Traduire fidèlement sans ajouter ni retirer d'information
        - Répondre UNIQUEMENT avec la traduction, sans explication
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Traduis ce texte:\n\n\(text)"]
            ],
            "max_tokens": 2048,
            "temperature": 0.2
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OptimizationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OptimizationError.apiError(message)
            }
            throw OptimizationError.apiError("Status code: \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OptimizationError.parseError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum OptimizationError: LocalizedError {
    case noAPIKey
    case emptyText
    case invalidURL
    case invalidResponse
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Clé Groq API manquante"
        case .emptyText:
            return "Texte vide"
        case .invalidURL:
            return "URL invalide"
        case .invalidResponse:
            return "Réponse invalide"
        case .apiError(let message):
            return "Erreur API: \(message)"
        case .parseError:
            return "Erreur de parsing"
        }
    }
}
