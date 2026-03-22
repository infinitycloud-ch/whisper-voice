import SwiftUI
import AVFoundation

struct ChatView: View {
    @StateObject private var chatService = GroqChatService.shared
    @EnvironmentObject var transcriptionManager: TranscriptionManager
    @AppStorage("app_theme") private var currentTheme: String = AppTheme.dark.rawValue
    @AppStorage("auto_play_tts") private var autoPlayTTS: Bool = true
    
    @State private var messages: [(role: String, content: String, audioPath: String?)] = []
    @State private var isRecordingForChat = false
    @State private var isWaitingResponse = false
    @State private var sessionList: [(id: String, title: String, createdAt: Date)] = []
    @State private var showSessionList = false
    
    var theme: AppTheme {
        AppTheme(rawValue: currentTheme) ?? .dark
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header amélioré
            HStack {
                // Bouton sessions
                Button(action: {
                    showSessionList.toggle()
                    if showSessionList {
                        sessionList = DatabaseManager.shared.getSessions()
                    }
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14))
                        .foregroundColor(theme.accentColor.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Historique des sessions")
                
                Text("🎤 Chat Vocal Groq")
                    .font(.headline)
                    .foregroundColor(theme.accentColor)
                
                Spacer()
                
                // Toggle lecture auto
                Toggle(isOn: $autoPlayTTS) {
                    Image(systemName: autoPlayTTS ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.system(size: 12))
                        .foregroundColor(autoPlayTTS ? theme.accentColor : theme.secondaryTextColor)
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .help("Lecture automatique des réponses")
                
                // Bouton nouvelle session
                Button(action: {
                    chatService.createNewSession()
                    messages.removeAll()
                }) {
                    Image(systemName: "plus.bubble")
                        .foregroundColor(theme.accentColor)
                }
                .buttonStyle(.plain)
                .help("Nouvelle conversation")
                
                // Bouton export
                Button(action: exportChat) {
                    Image(systemName: "doc.text")
                        .foregroundColor(theme.accentColor)
                }
                .buttonStyle(.plain)
                .help("Exporter (MD)")
            }
            .padding()
            .background(theme.secondaryBackgroundColor)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            MessageBubble(
                                role: message.role,
                                content: message.content,
                                audioPath: message.audioPath,
                                theme: theme
                            )
                            .id(index)
                        }
                        
                        if isWaitingResponse {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Réflexion en cours...")
                                    .font(.caption)
                                    .foregroundColor(theme.secondaryTextColor)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(messages.count - 1, anchor: .bottom)
                    }
                }
            }
            
            // Bottom bar améliorée
            VStack(spacing: 8) {
                // Indicateurs de statut
                HStack {
                    if chatService.audioPlayer?.isPlaying == true {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(theme.accentColor.opacity(0.8))
                            Text("Lecture audio...")
                                .font(.caption)
                                .foregroundColor(theme.secondaryTextColor.opacity(0.8))
                            
                            // Bouton stop audio
                            Button(action: {
                                chatService.audioPlayer?.stop()
                                chatService.objectWillChange.send()
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(theme.recordColor.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Arrêter la lecture")
                        }
                    } else if isWaitingResponse {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Groq réfléchit...")
                                .font(.caption)
                                .foregroundColor(theme.secondaryTextColor)
                        }
                    } else if isRecordingForChat {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                                        .scaleEffect(1.5)
                                        .opacity(0.5)
                                        .animation(.easeInOut(duration: 1).repeatForever(), value: isRecordingForChat)
                                )
                            Text("🎙️ Parlez maintenant...")
                                .font(.caption)
                                .foregroundColor(theme.recordColor)
                        }
                    } else {
                        Text("Appuyez sur le micro pour parler")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Bouton microphone centré
                HStack {
                    Spacer()
                    
                    Button(action: toggleRecording) {
                        ZStack {
                            // Cercle de fond
                            Circle()
                                .fill(isRecordingForChat ? theme.recordColor.opacity(0.2) : theme.accentColor.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            // Animation pulse si en enregistrement
                            if isRecordingForChat {
                                Circle()
                                    .stroke(theme.recordColor, lineWidth: 3)
                                    .frame(width: 80, height: 80)
                                    .scaleEffect(1.2)
                                    .opacity(0.3)
                                    .animation(.easeInOut(duration: 1).repeatForever(), value: isRecordingForChat)
                            }
                            
                            // Icône
                            Image(systemName: isRecordingForChat ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30))
                                .foregroundColor(isRecordingForChat ? theme.recordColor : theme.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isWaitingResponse)
                    .keyboardShortcut("r", modifiers: [.command])
                    .help("Parler (⌘R)")
                    
                    Spacer()
                }
            }
            .padding()
            .background(theme.secondaryBackgroundColor)
        }
        .background(theme.backgroundColor)
        .onAppear {
            loadCurrentSession()
        }
        .overlay(alignment: .leading) {
            if showSessionList {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Sessions")
                            .font(.headline)
                            .foregroundColor(theme.textColor)
                        
                        Spacer()
                        
                        Button(action: { showSessionList = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.secondaryTextColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(theme.secondaryBackgroundColor)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(sessionList, id: \.id) { session in
                                Button(action: {
                                    chatService.loadSession(id: session.id)
                                    loadCurrentSession()
                                    showSessionList = false
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(session.title)
                                            .font(.body)
                                            .foregroundColor(theme.textColor)
                                        Text(session.createdAt.formatted())
                                            .font(.caption)
                                            .foregroundColor(theme.secondaryTextColor)
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(theme.backgroundColor.opacity(0.5))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
                .frame(width: 250)
                .background(theme.backgroundColor)
                .cornerRadius(10)
                .shadow(radius: 10)
                .padding()
            }
        }
    }
    
    private func toggleRecording() {
        print("🎤 Toggle recording: isRecording=\(isRecordingForChat)")
        
        if isRecordingForChat {
            // Arrêter l'enregistrement
            print("🛑 Stopping recording...")
            isRecordingForChat = false
            transcriptionManager.stopAndTranscribe()
            
            // Observer la transcription immédiatement
            Task {
                var attempts = 0
                while attempts < 30 { // Max 3 secondes (30 x 100ms)
                    if !transcriptionManager.liveTranscription.isEmpty && 
                       transcriptionManager.liveTranscription != "Transcription en cours..." {
                        
                        await MainActor.run {
                            print("📝 Transcription result: \(transcriptionManager.liveTranscription)")
                            let userText = transcriptionManager.liveTranscription
                            messages.append((role: "user", content: userText, audioPath: nil))
                            
                            // Effacer pour le prochain enregistrement
                            transcriptionManager.liveTranscription = ""
                            
                            // Envoyer au chat immédiatement
                            print("💬 Sending to chat: \(userText)")
                            sendToChat(userText)
                        }
                        break
                    }
                    
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    attempts += 1
                }
                
                if attempts >= 30 {
                    print("⚠️ Transcription timeout")
                }
            }
        } else {
            // Commencer l'enregistrement
            print("🎙️ Starting recording...")
            isRecordingForChat = true
            transcriptionManager.liveTranscription = ""
            transcriptionManager.startRecording()
            NSSound.beep()
        }
    }
    
    private func sendToChat(_ text: String) {
        isWaitingResponse = true
        print("📝 [LATENCY] Sending to chat: \"\(text)\"")
        
        Task {
            if let response = await chatService.sendMessage(text) {
                await MainActor.run {
                    // Récupérer le dernier message avec son audioPath depuis la DB
                    if let sessionId = chatService.currentSessionId {
                        let dbMessages = DatabaseManager.shared.getMessages(sessionId: sessionId)
                        if let lastMessage = dbMessages.last {
                            messages.append((role: "assistant", content: response, audioPath: lastMessage.audioPath))
                        } else {
                            messages.append((role: "assistant", content: response, audioPath: nil))
                        }
                    }
                    isWaitingResponse = false
                }
            } else {
                await MainActor.run {
                    isWaitingResponse = false
                    // Afficher une erreur
                    messages.append((role: "assistant", 
                                     content: "❌ Erreur de connexion. Vérifiez votre clé API Groq.",
                                     audioPath: nil))
                }
            }
        }
    }
    
    private func loadCurrentSession() {
        guard let sessionId = chatService.currentSessionId else { return }
        
        let dbMessages = DatabaseManager.shared.getMessages(sessionId: sessionId)
        messages = dbMessages.map { (role: $0.role, content: $0.content, audioPath: $0.audioPath) }
    }
    
    private func exportChat() {
        guard let markdown = chatService.exportCurrentSession() else { return }
        
        // Sauvegarder dans un fichier
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "chat_export.md"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct MessageBubble: View {
    let role: String
    let content: String
    let audioPath: String?
    let theme: AppTheme
    @State private var isPlayingAudio = false
    
    var body: some View {
        HStack {
            if role == "assistant" {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: role == "user" ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(role == "user" ? "Vous" : "Assistant")
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                    
                    // Bouton réécoute pour les messages assistant avec audio
                    if role == "assistant", let audioPath = audioPath {
                        Button(action: {
                            playAudio(at: audioPath)
                        }) {
                            Image(systemName: isPlayingAudio ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .font(.system(size: 12))
                                .foregroundColor(theme.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Réécouter")
                    }
                }
                
                Text(content)
                    .padding(10)
                    .background(
                        role == "user" 
                            ? theme.accentColor.opacity(0.2)
                            : theme.secondaryBackgroundColor.opacity(0.5)
                    )
                    .cornerRadius(12)
                    .foregroundColor(theme.textColor)
            }
            
            if role == "user" {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func playAudio(at path: String) {
        do {
            let url = URL(fileURLWithPath: path)
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            
            isPlayingAudio = true
            DispatchQueue.main.asyncAfter(deadline: .now() + audioPlayer.duration) {
                isPlayingAudio = false
            }
        } catch {
            print("❌ Failed to play audio: \(error)")
        }
    }
}