import Foundation
import AVFoundation

class ElevenLabsService {
    static let shared = ElevenLabsService()
    
    private let baseURL = "https://api.elevenlabs.io/v1"
    private let voiceId = "21m00Tcm4TlvDq8ikWAM" // Rachel voice (clear, natural)
    
    // Clé API stockée de manière sécurisée
    private var apiKey: String? {
        // D'abord vérifier UserDefaults
        if let key = UserDefaults.standard.string(forKey: "elevenlabs_api_key") {
            return key
        }
        // Sinon utiliser la clé par défaut (temporaire)
        return "sk_3675808e869f48de53785c5796bcc050a15cc9f6b7b59a37"
    }
    
    private init() {}
    
    // MARK: - Text-to-Speech
    
    func generateSpeech(text: String) async -> Data? {
        guard let apiKey = apiKey else {
            print("❌ ElevenLabs API key not configured")
            return nil
        }
        
        guard let url = URL(string: "\(baseURL)/text-to-speech/\(voiceId)") else {
            print("❌ Invalid ElevenLabs URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept") // Pour recevoir du MP3
        
        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.7,
                "style": 0.0,
                "use_speaker_boost": true
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ ElevenLabs TTS successful: \(data.count) bytes")
                    // Vérifier que nous avons bien reçu de l'audio
                    if data.count > 1000 {  // Un fichier audio devrait faire au moins 1KB
                        print("✅ Audio data seems valid")
                        return data
                    } else {
                        print("⚠️ Audio data too small: \(data.count) bytes")
                        return nil
                    }
                } else {
                    print("❌ ElevenLabs TTS error: HTTP \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("Error details: \(errorString)")
                    }
                    return nil
                }
            }
        } catch {
            print("❌ ElevenLabs TTS error: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Audio File Management
    
    func saveAudioFile(data: Data) -> String? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first!
        let audioFolder = appSupport
            .appendingPathComponent("WhisperByMrD")
            .appendingPathComponent("audio")
        
        // Créer le dossier si nécessaire
        try? FileManager.default.createDirectory(at: audioFolder,
                                                  withIntermediateDirectories: true)
        
        // Sauvegarder en .mp3 directement (ElevenLabs renvoie du MP3)
        let fileName = "\(UUID().uuidString).mp3"
        let fileURL = audioFolder.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("💾 Audio file saved: \(fileURL.path) (\(data.count) bytes)")
            return fileURL.path
        } catch {
            print("❌ Failed to save audio: \(error)")
            return nil
        }
    }
    
    // MARK: - Voice Management
    
    func listAvailableVoices() async -> [(id: String, name: String)]? {
        guard let apiKey = apiKey else { return nil }
        
        guard let url = URL(string: "\(baseURL)/voices") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let voices = json["voices"] as? [[String: Any]] {
                
                return voices.compactMap { voice in
                    guard let id = voice["voice_id"] as? String,
                          let name = voice["name"] as? String else { return nil }
                    return (id, name)
                }
            }
        } catch {
            print("❌ Failed to list voices: \(error)")
        }
        
        return nil
    }
}