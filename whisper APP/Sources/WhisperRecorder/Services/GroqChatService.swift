import Foundation
import AVFoundation

class GroqChatService: ObservableObject {
    static let shared = GroqChatService()
    
    @Published var isProcessing = false
    @Published var currentSessionId: String?
    @Published var audioPlayer: AVAudioPlayer?
    
    private let baseURL = "https://api.groq.com/openai/v1"
    private var apiKey: String? {
        UserDefaults.standard.string(forKey: "groq_api_key")
    }
    
    // Modèles Groq recommandés
    private let chatModel = "llama-3.1-8b-instant" // Ultra rapide pour latence minimale
    private let ttsModel = "playai-tts"
    private let ttsVoice = "Fritz-PlayAI" // Voix masculine claire
    
    private init() {
        // Créer une session par défaut si nécessaire
        if currentSessionId == nil {
            currentSessionId = DatabaseManager.shared.createSession(title: "Nouvelle conversation")
        }
    }
    
    // MARK: - Chat Completion
    
    func sendMessage(_ userMessage: String) async -> String? {
        let startTime = Date()
        print("⏱️ [LATENCY] Starting chat processing at \(startTime.formatted(.dateTime.hour().minute().second()))")
        
        guard let apiKey = apiKey else {
            print("❌ Groq API key not configured")
            return nil
        }
        
        guard let sessionId = currentSessionId else {
            print("❌ No active session")
            return nil
        }
        
        isProcessing = true
        defer { 
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        // Sauvegarder le message utilisateur
        _ = DatabaseManager.shared.addMessage(sessionId: sessionId, 
                                               role: "user", 
                                               content: userMessage)
        
        // Récupérer l'historique pour le contexte
        let messages = DatabaseManager.shared.getMessages(sessionId: sessionId)
        
        // Construire le contexte pour l'API
        let systemMessage = """
        Tu es un assistant vocal, concis et utile. Réponds en français.
        Tu as accès à des outils pour créer des dossiers et des notes.
        """
        
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": systemMessage]
        ]
        
        // Ajouter les 10 derniers messages pour le contexte
        for message in messages.suffix(10) {
            var msgDict: [String: Any] = ["role": message.role, "content": message.content]
            if let toolCalls = message.toolCalls {
                msgDict["tool_calls"] = toolCalls
            }
            apiMessages.append(msgDict)
        }
        
        // Appel API Chat Completion
        guard let url = URL(string: "\(baseURL)/chat/completions") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let tools = [
            [
                "type": "function",
                "function": [
                    "name": "create_folder",
                    "description": "Crée un nouveau dossier dans la bibliothèque.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Le nom du nouveau dossier."]
                        ],
                        "required": ["name"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "create_note",
                    "description": "Crée une nouvelle note textuelle (transcription).",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "content": ["type": "string", "description": "Le contenu texte de la note."],
                            "folder_name": ["type": "string", "description": "Optionnel: Le nom du dossier où ranger la note."]
                        ],
                        "required": ["content"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "list_folders",
                    "description": "Liste les noms de tous les dossiers existants.",
                    "parameters": [
                        "type": "object",
                        "properties": [:],
                        "required": []
                    ]
                ]
            ]
        ]
        
        let body: [String: Any] = [
            "model": chatModel,
            "messages": apiMessages,
            "temperature": 0.7,
            "max_tokens": 500,
            "tools": tools,
            "tool_choice": "auto"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            let groqResponseTime = Date()
            print("⏱️ [LATENCY] Groq response received: \(groqResponseTime.timeIntervalSince(startTime).formatted(.number.precision(.fractionLength(3))))s")
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                print("❌ Chat API error: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Error details: \(errorString)")
                }
                return nil
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let choices = json?["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any] {
                
                // Sauvegarder la réponse de l'assistant (qui peut être un appel d'outil)
                let toolCalls = message["tool_calls"] as? [[String: Any]]
                DatabaseManager.shared.addMessage(sessionId: sessionId, role: "assistant", content: message["content"] as? String ?? "", toolCalls: toolCalls)

                // Vérifier si l'IA veut utiliser un outil
                if let toolCalls = toolCalls {
                    print("🤖 IA wants to use a tool...")
                    // Gérer l'appel d'outil
                    return await handleToolCall(toolCalls, sessionId: sessionId)
                }
                
                // Si pas d'outil, c'est une réponse normale
                if let content = message["content"] as? String {
                    await triggerTTS(for: content, sessionId: sessionId)
                    return content
                }
            }
            
        } catch {
            print("❌ Chat completion error: \(error)")
        }
        
        return nil
    }

    private func handleToolCall(_ toolCalls: [[String: Any]], sessionId: String) async -> String? {
        guard let toolCall = toolCalls.first,
              let functionInfo = toolCall["function"] as? [String: Any],
              let functionName = functionInfo["name"] as? String,
              let argumentsString = functionInfo["arguments"] as? String,
              let argumentsData = argumentsString.data(using: .utf8) else {
            return "Erreur lors de la lecture de l'appel d'outil."
        }

        print("📞 Function call: \(functionName)")
        print("📋 Arguments: \(argumentsString)")

        var toolResultMessage = ""

        do {
            switch functionName {
            case "create_folder":
                let args = try JSONDecoder().decode(CreateFolderArgs.self, from: argumentsData)
                await MainActor.run {
                    FolderTreeManager.shared.createFolder(name: args.name)
                }
                toolResultMessage = "Dossier '\(args.name)' créé avec succès."

            case "create_note":
                let args = try JSONDecoder().decode(CreateNoteArgs.self, from: argumentsData)
                await MainActor.run {
                    TranscriptionManager.shared.addTranscription(text: args.content, folderName: args.folder_name)
                }
                toolResultMessage = "Note créée avec succès" + (args.folder_name != nil ? " dans le dossier '\(args.folder_name!)'." : ".")

            case "list_folders":
                let folders = FolderTreeManager.shared.rootNodes.map { $0.name }
                // Recursive listing could be better, but flat root listing is a start
                toolResultMessage = "Dossiers disponibles: " + (folders.isEmpty ? "Aucun" : folders.joined(separator: ", "))

            default:
                toolResultMessage = "Outil inconnu: \(functionName)"
            }
        } catch {
            toolResultMessage = "Erreur lors de l'exécution de l'outil \(functionName): \(error.localizedDescription)"
        }

        // Renvoyer le résultat à l'IA pour qu'elle formule la réponse finale
        return await sendToolResult(toolCall: toolCall, result: toolResultMessage, sessionId: sessionId)
    }

    private func sendToolResult(toolCall: [String: Any], result: String, sessionId: String) async -> String? {
        print("📤 Sending tool result back to AI: \(result)")
        
        // Construire l'historique + la réponse de l'outil
        let history = DatabaseManager.shared.getMessages(sessionId: sessionId)
        var apiMessages: [[String: Any]] = history.map { msg in
            var dict: [String: Any] = ["role": msg.role, "content": msg.content]
            if let tc = msg.toolCalls { dict["tool_calls"] = tc }
            return dict
        }
        
        apiMessages.append([
            "role": "tool",
            "tool_call_id": toolCall["id"] as! String,
            "name": (toolCall["function"] as! [String:Any])["name"] as! String,
            "content": result
        ])

        // Refaire un appel à /chat/completions avec ce nouvel historique
        guard let apiKey = apiKey, let url = URL(string: "\(baseURL)/chat/completions") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": chatModel,
            "messages": apiMessages,
            "temperature": 0.7,
            "max_tokens": 500
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let choices = json?["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                DatabaseManager.shared.addMessage(sessionId: sessionId, role: "assistant", content: content)
                await triggerTTS(for: content, sessionId: sessionId)
                return content
            }
        } catch {
            print("❌ Error sending tool result: \(error)")
        }
        
        return "J'ai utilisé mon outil, mais je n'ai pas pu formuler de réponse finale."
    }

    // Structs pour les arguments
    struct CreateFolderArgs: Codable {
        let name: String
    }
    
    struct CreateNoteArgs: Codable {
        let content: String
        let folder_name: String?
    }
    
    private func triggerTTS(for text: String, sessionId: String) async {
        if let audioData = await ElevenLabsService.shared.generateSpeech(text: text) {
            if let audioPath = ElevenLabsService.shared.saveAudioFile(data: audioData) {
                DatabaseManager.shared.addMessage(sessionId: sessionId, role: "assistant", content: text, audioPath: audioPath)
                playAudio(at: audioPath)
            }
        }
    }

    // MARK: - Audio Management
    
    private func playAudio(at path: String) {
        Task { @MainActor in
            do {
                let url = URL(fileURLWithPath: path)
                
                if FileManager.default.fileExists(atPath: path) {
                    print("✅ Audio file exists at: \(path)")
                } else {
                    print("❌ Audio file does not exist at: \(path)")
                    return
                }
                
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.volume = 1.0
                let success = self.audioPlayer?.play() ?? false
                print("🔊 Playing audio: \(success ? "SUCCESS" : "FAILED")")
            } catch {
                print("❌ Failed to play audio: \(error)")
            }
        }
    }
    
    // MARK: - Session Management
    
    func createNewSession() {
        currentSessionId = DatabaseManager.shared.createSession(title: "Conversation du \(Date().formatted())")
    }
    
    func loadSession(id: String) {
        currentSessionId = id
    }
    
    func exportCurrentSession() -> String? {
        guard let sessionId = currentSessionId else { return nil }
        return DatabaseManager.shared.exportSessionToMarkdown(sessionId: sessionId)
    }
}