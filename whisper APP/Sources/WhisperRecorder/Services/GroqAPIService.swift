import Foundation

class GroqAPIService {
    static let shared = GroqAPIService()
    
    private let apiEndpoint = "https://api.groq.com/openai/v1/audio/transcriptions"
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "groq_api_key") ?? ""
    }
    
    private init() {}
    
    func transcribeAudio(fileURL: URL) async throws -> String {
        guard !apiKey.isEmpty else {
            throw TranscriptionError.missingAPIKey
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw TranscriptionError.fileNotFound
        }
        
        var request = URLRequest(url: URL(string: apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-large-v3-turbo\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("fr\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        request.timeoutInterval = 60 // 60 secondes de timeout

        // Capturer les erreurs réseau détaillées
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            print("❌ URLError: \(error.localizedDescription)")
            print("   Code: \(error.code.rawValue)")

            switch error.code {
            case .notConnectedToInternet:
                throw TranscriptionError.apiError("Pas de connexion Internet")
            case .timedOut:
                throw TranscriptionError.apiError("Timeout - Groq ne répond pas")
            case .cannotFindHost, .cannotConnectToHost:
                throw TranscriptionError.apiError("Impossible de joindre l'API Groq")
            default:
                throw TranscriptionError.networkError
            }
        } catch {
            print("❌ Erreur inattendue: \(error)")
            throw TranscriptionError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Pas de réponse HTTP valide")
            throw TranscriptionError.networkError
        }

        print("📡 Groq API Status Code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            // Essayer d'extraire le message d'erreur détaillé
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("❌ Groq API Error Response: \(errorData)")

                if let errorMessage = errorData["error"] as? [String: Any],
                   let message = errorMessage["message"] as? String {
                    throw TranscriptionError.apiError(message)
                }
            }

            // Message d'erreur basé sur le code HTTP
            let errorMessage: String
            switch httpResponse.statusCode {
            case 401:
                errorMessage = "Clé API invalide ou expirée"
            case 429:
                errorMessage = "Limite de requêtes atteinte"
            case 500...599:
                errorMessage = "Erreur serveur Groq (code \(httpResponse.statusCode))"
            default:
                errorMessage = "Erreur HTTP \(httpResponse.statusCode)"
            }

            throw TranscriptionError.apiError(errorMessage)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw TranscriptionError.invalidResponse
        }
        
        try? FileManager.default.removeItem(at: fileURL)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func validateAPIKey(_ key: String) async -> Bool {
        guard !key.isEmpty else { return false }
        
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("API key validation error: \(error)")
        }
        
        return false
    }
}

enum TranscriptionError: LocalizedError {
    case missingAPIKey
    case fileNotFound
    case networkError
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Clé API Groq manquante. Configurez-la dans les préférences."
        case .fileNotFound:
            return "Fichier audio introuvable."
        case .networkError:
            return "Erreur de connexion réseau."
        case .invalidResponse:
            return "Réponse invalide du serveur."
        case .apiError(let message):
            return "Erreur API: \(message)"
        }
    }
}