import Foundation
import SwiftUI
import AppKit
import HotKey

class TranscriptionManager: ObservableObject {
    static let shared = TranscriptionManager()
    
    @Published var transcriptions: [Transcription] = []
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var recordingTime: TimeInterval = 0
    @Published var liveTranscription: String = ""
    @Published var isEditingTranscription = false
    @Published var editedTranscription: String = ""
    @Published var shouldAppendNextRecording = false
    @Published var copySuccessMessage: String?
    @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 20)
    @Published var currentInputDevice: String = "Microphone par défaut"

    @Published var autoPasteCountdown: Int = 0
    @Published var selectedFolderForNewRecording: TreeNode? // Dossier pour les nouveaux enregistrements
    @Published var selectedTranscription: Transcription? // Transcription sélectionnée
    @AppStorage("auto_paste_enabled") var autoPasteEnabled: Bool = true
    @AppStorage("auto_paste_delay") var autoPasteDelay: Double = 0.2  // Délai en secondes
    @AppStorage("minimize_after_recording") var minimizeAfterRecording: Bool = false
    @AppStorage("stay_on_top") var stayOnTop: Bool = false
    @AppStorage("selected_api") var selectedAPI: String = "groq"

    // Favoris
    @Published var favoriteTranscriptionIDs: Set<UUID> = []
    @AppStorage("favorite_transcription_ids") private var favoriteIDsData: Data = Data()

    // AI Optimization
    @Published var isOptimizing = false
    @Published var originalTextBeforeOptimization: String?

    // Live Transcription (incremental)
    @Published var livePreviewText: String = ""
    @Published var isLiveTranscribing = false
    @AppStorage("live_transcription_enabled") var liveTranscriptionEnabled: Bool = true
    private var liveTranscriptionTimer: Timer?
    private let liveTranscriptionInterval: TimeInterval = 5.0 // 5 seconds

    private let audioRecorder = AudioRecorderManager()
    private let groqService = GroqAPIService.shared
    private let openaiService = OpenAIService.shared
    private var hotKey: HotKey?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadTranscriptions()
        loadFavorites()
        setupBindings()
    }
    
    private func setupBindings() {
        audioRecorder.$isRecording
            .assign(to: &$isRecording)
        
        audioRecorder.$recordingTime
            .assign(to: &$recordingTime)
        
        audioRecorder.$audioLevels
            .assign(to: &$audioLevels)
        
        audioRecorder.$currentInputDevice
            .assign(to: &$currentInputDevice)
    }
    
    // MARK: - Hotkey Configuration

    static let defaultHotkeyKeyCode: UInt32 = 7  // X key
    static let defaultHotkeyModifiers: UInt32 = 2048  // Option key
    private let hotkeyKeyCodeKey = "hotkey_keycode"
    private let hotkeyModifiersKey = "hotkey_modifiers"

    @Published var currentHotkeyDescription: String = "⌥X"

    func setupHotkey() {
        let keyCombo = loadHotkeyConfig()
        hotKey = HotKey(keyCombo: keyCombo, keyDownHandler: { [weak self] in
            self?.toggleRecording()
        })
        updateHotkeyDescription(keyCombo)
    }

    private func loadHotkeyConfig() -> KeyCombo {
        let keyCode = UInt32(UserDefaults.standard.integer(forKey: hotkeyKeyCodeKey))
        let modifiers = UInt32(UserDefaults.standard.integer(forKey: hotkeyModifiersKey))

        // Si pas de config sauvegardée, utiliser le défaut
        if keyCode == 0 && modifiers == 0 {
            return KeyCombo(key: .x, modifiers: [.option])
        }

        return KeyCombo(carbonKeyCode: keyCode, carbonModifiers: modifiers)
    }

    func updateHotkey(keyCombo: KeyCombo) {
        // Sauvegarder la config
        UserDefaults.standard.set(Int(keyCombo.carbonKeyCode), forKey: hotkeyKeyCodeKey)
        UserDefaults.standard.set(Int(keyCombo.carbonModifiers), forKey: hotkeyModifiersKey)

        // Recréer le hotkey
        hotKey = nil
        hotKey = HotKey(keyCombo: keyCombo, keyDownHandler: { [weak self] in
            self?.toggleRecording()
        })

        updateHotkeyDescription(keyCombo)
    }

    func resetHotkeyToDefault() {
        UserDefaults.standard.removeObject(forKey: hotkeyKeyCodeKey)
        UserDefaults.standard.removeObject(forKey: hotkeyModifiersKey)
        setupHotkey()
    }

    private func updateHotkeyDescription(_ keyCombo: KeyCombo) {
        currentHotkeyDescription = keyCombo.description
    }

    func getCurrentKeyCombo() -> KeyCombo {
        return loadHotkeyConfig()
    }
    
    func toggleRecording() {
        if isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        // Clear previous transcription when starting new recording
        liveTranscription = ""
        livePreviewText = ""
        _ = audioRecorder.startRecording()

        // Start live transcription timer if enabled
        if liveTranscriptionEnabled {
            startLiveTranscriptionTimer()
        }

        // Bring window to front and keep it on top during recording
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)

            // Forcer l'app à venir au premier plan
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

            if let window = NSApp.windows.first {
                // Ne mettre en floating que si l'option est activée
                if self.stayOnTop {
                    window.level = .floating
                }
                window.makeKeyAndOrderFront(nil)
                // Supprimé window.center() pour préserver la position

                // S'assurer que la fenêtre est visible
                if !window.isVisible {
                    window.orderFront(nil)
                }
            }
        }

        NSSound.beep()
    }

    // MARK: - Live Transcription

    private func startLiveTranscriptionTimer() {
        liveTranscriptionTimer?.invalidate()
        liveTranscriptionTimer = Timer.scheduledTimer(withTimeInterval: liveTranscriptionInterval, repeats: true) { [weak self] _ in
            self?.performLiveTranscription()
        }
    }

    private func stopLiveTranscriptionTimer() {
        liveTranscriptionTimer?.invalidate()
        liveTranscriptionTimer = nil
        isLiveTranscribing = false
    }

    private func performLiveTranscription() {
        guard isRecording, !isLiveTranscribing else { return }

        // Copy the current recording to a temp file
        guard let tempURL = audioRecorder.copyCurrentRecordingForPreview() else {
            print("⚠️ Could not copy recording for live preview")
            return
        }

        isLiveTranscribing = true

        Task {
            do {
                let text: String
                if selectedAPI == "openai" {
                    text = try await openaiService.transcribeAudio(fileURL: tempURL)
                } else {
                    text = try await groqService.transcribeAudio(fileURL: tempURL)
                }

                await MainActor.run {
                    // Update live preview with the full transcription so far
                    self.livePreviewText = text
                    self.liveTranscription = "📝 " + text
                    self.isLiveTranscribing = false
                }
            } catch {
                await MainActor.run {
                    self.isLiveTranscribing = false
                    print("⚠️ Live transcription error: \(error.localizedDescription)")
                }
                // Clean up temp file on error
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }
    
    func stopAndTranscribe() {
        print("🔴 stopAndTranscribe called")

        // Stop live transcription timer
        stopLiveTranscriptionTimer()

        guard let result = audioRecorder.stopRecording(),
              let audioURL = result.0 else {
            print("❌ Failed to stop recording or get audio URL")
            // Si l'arrêt échoue, on reset quand même les flags
            isRecording = false
            recordingTime = 0
            return
        }
        
        print("✅ Recording stopped, audio URL: \(audioURL)")
        // Reset isRecording flag après l'arrêt réussi
        isRecording = false
        recordingTime = 0
        
        let duration = result.1
        isProcessing = true
        liveTranscription = "Transcription en cours..."
        print("📤 Starting transcription task...")
        
        Task {
            do {
                print("🎯 Calling transcription API: \(selectedAPI)")
                let text: String
                if selectedAPI == "openai" {
                    text = try await openaiService.transcribeAudio(fileURL: audioURL)
                } else {
                    text = try await groqService.transcribeAudio(fileURL: audioURL)
                }
                
                print("📝 Transcription received: \(text)")
                
                await MainActor.run {
                    // Si on doit ajouter au texte précédent
                    let finalText: String
                    if self.shouldAppendNextRecording && !self.liveTranscription.isEmpty {
                        finalText = self.liveTranscription + " " + text
                    } else {
                        finalText = text
                    }
                    
                    self.liveTranscription = finalText
                    self.editedTranscription = finalText
                    self.isEditingTranscription = false
                    
                    // Toujours créer une nouvelle transcription sauf si on ajoute explicitement
                    if self.shouldAppendNextRecording && !self.transcriptions.isEmpty {
                        // Mettre à jour la dernière transcription
                        self.updateLastTranscription(finalText)
                        self.shouldAppendNextRecording = false // Reset après utilisation
                    } else {
                        // Créer une nouvelle transcription
                        let transcription = Transcription(
                            text: finalText,
                            timestamp: Date(),
                            duration: duration
                        )
                        
                        self.transcriptions.insert(transcription, at: 0)
                        self.saveTranscriptions()
                        
                        // Si un dossier est sélectionné, y ajouter la transcription
                        if let folder = self.selectedFolderForNewRecording {
                            folder.addTranscription(transcription.id)
                            // Sauvegarder via le FolderTreeManager (sera fait dans TreeSidebarView)
                        }
                    }
                    
                    self.copyToClipboard(finalText)
                    
                    // Auto-paste functionality
                    if self.autoPasteEnabled {
                        self.autoPasteCountdown = 0 // Pas de compte à rebours visuel

                        // Délai configurable pour permettre le changement de focus
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.autoPasteDelay) {
                            
                            // Méthode améliorée pour simuler Cmd+V
                            let source = CGEventSource(stateID: .combinedSessionState)
                            
                            // Créer les événements avec les bons keycodes
                            // V = 9 (kVK_ANSI_V)
                            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
                            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
                            
                            // Ajouter le flag Command
                            vDown?.flags = .maskCommand
                            vUp?.flags = .maskCommand
                            
                            // Obtenir la position actuelle de la souris pour poster l'événement au bon endroit
                            let mouseLocation = NSEvent.mouseLocation
                            let screenHeight = NSScreen.main?.frame.height ?? 0
                            let cgLocation = CGPoint(x: mouseLocation.x, y: screenHeight - mouseLocation.y)
                            
                            // Poster les événements à la position de la souris
                            vDown?.location = cgLocation
                            vUp?.location = cgLocation
                            
                            vDown?.post(tap: .cghidEventTap)
                            Thread.sleep(forTimeInterval: 0.01)
                            vUp?.post(tap: .cghidEventTap)
                            
                            print("🚀 Auto-paste rapide envoyé")
                        }
                    }
                    
                    self.isProcessing = false
                    NSSound.beep()
                    
                    // Remove floating window level after recording
                    DispatchQueue.main.async {
                        if let window = NSApp.keyWindow {
                            window.level = .normal
                            
                            // Minimiser si l'option est activée
                            if self.minimizeAfterRecording {
                                NSApp.hide(nil)
                            }
                        }
                    }
                    
                    // Ne PAS effacer le texte - il reste visible jusqu'au prochain enregistrement
                }
            } catch {
                print("❌ Transcription error: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                    self.liveTranscription = ""
                }
            }
        }
    }
    
    func copyToClipboard(_ text: String, showSuccess: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        if showSuccess {
            copySuccessMessage = "✓ Copié dans le presse-papier"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.copySuccessMessage = nil
            }
        }
    }
    
    
    
    func addTranscription(text: String, folderName: String? = nil) {
        let transcription = Transcription(text: text, duration: 0)
        transcriptions.insert(transcription, at: 0)
        saveTranscriptions()
        
        // Handle folder assignment
        if let folderName = folderName {
            // Find folder by name
            func findFolder(in nodes: [TreeNode]) -> TreeNode? {
                for node in nodes {
                    if node.name.lowercased() == folderName.lowercased() {
                        return node
                    }
                    if let children = node.children, let found = findFolder(in: children) {
                        return found
                    }
                }
                return nil
            }
            
            if let folder = findFolder(in: FolderTreeManager.shared.rootNodes) {
                FolderTreeManager.shared.moveTranscription(id: transcription.id, to: folder)
            } else {
                // Option: Create folder if it doesn't exist? For now, just ignore or log.
                print("Folder '\(folderName)' not found.")
            }
        }
    }

    func deleteTranscription(_ transcription: Transcription) {
        transcriptions.removeAll { $0.id == transcription.id }
        saveTranscriptions()
    }
    
    func clearHistory() {
        transcriptions.removeAll()
        saveTranscriptions()
    }
    
    func saveTranscriptions() {
        if let encoded = try? JSONEncoder().encode(transcriptions) {
            UserDefaults.standard.set(encoded, forKey: "transcriptions_history")
        }
    }
    
    private func loadTranscriptions() {
        if let data = UserDefaults.standard.data(forKey: "transcriptions_history"),
           let decoded = try? JSONDecoder().decode([Transcription].self, from: data) {
            // Ne charger que les 30 dernières transcriptions pour améliorer les performances
            transcriptions = Array(decoded.prefix(30))
        }
    }
    
    func appendToLastTranscription(_ additionalText: String) {
        guard !transcriptions.isEmpty else { return }
        
        // Fusionner avec la dernière transcription
        var lastTranscription = transcriptions[0]
        let newText = lastTranscription.text + " " + additionalText
        
        // Créer une nouvelle transcription avec le texte fusionné
        let mergedTranscription = Transcription(
            text: newText,
            timestamp: lastTranscription.timestamp,
            duration: lastTranscription.duration
        )
        
        transcriptions[0] = mergedTranscription
        saveTranscriptions()
        
        // Mettre à jour l'affichage
        liveTranscription = newText
        editedTranscription = newText
    }
    
    func updateLastTranscription(_ newText: String) {
        guard !transcriptions.isEmpty else { return }
        
        var lastTranscription = transcriptions[0]
        let updatedTranscription = Transcription(
            text: newText,
            timestamp: lastTranscription.timestamp,
            duration: lastTranscription.duration
        )
        
        transcriptions[0] = updatedTranscription
        saveTranscriptions()
        liveTranscription = newText
    }
    
    func exportTranscriptionsToFile() -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let fileName = "whisper_export_\(dateFormatter.string(from: Date())).json"
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        if let encoded = try? JSONEncoder().encode(transcriptions) {
            try? encoded.write(to: fileURL)
            return fileURL
        }
        return nil
    }
    
    func exportTranscriptionsAsText() -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        var text = "Whisper Voice Notes Export\n"
        text += "Exported: \(dateFormatter.string(from: Date()))\n"
        text += "Total: \(transcriptions.count) transcriptions\n\n"
        text += String(repeating: "=", count: 50) + "\n\n"
        
        for transcription in transcriptions {
            text += "📅 \(dateFormatter.string(from: transcription.timestamp))\n"
            text += "⏱️ Duration: \(String(format: "%.1f", transcription.duration)) seconds\n\n"
            text += transcription.text + "\n\n"
            text += String(repeating: "-", count: 50) + "\n\n"
        }
        
        let fileName = "whisper_export_\(dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")).txt"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        if let data = text.data(using: .utf8) {
            try? data.write(to: fileURL)
            return fileURL
        }
        return nil
    }
    
    func purgeOldTranscriptions(keepLast count: Int = 30) {
        if transcriptions.count > count {
            transcriptions = Array(transcriptions.prefix(count))
            saveTranscriptions()
        }
    }
    
    func purgeAllTranscriptions() {
        transcriptions.removeAll()
        saveTranscriptions()
    }
    
    func cleanup() {
        hotKey = nil
        stopLiveTranscriptionTimer()
        if isRecording {
            _ = audioRecorder.stopRecording()
        }
    }

    // MARK: - Favoris

    func loadFavorites() {
        if let ids = try? JSONDecoder().decode(Set<UUID>.self, from: favoriteIDsData) {
            favoriteTranscriptionIDs = ids
        }
    }

    func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteTranscriptionIDs) {
            favoriteIDsData = data
        }
    }

    func isFavorite(_ transcription: Transcription) -> Bool {
        favoriteTranscriptionIDs.contains(transcription.id)
    }

    func toggleFavorite(_ transcription: Transcription) {
        if favoriteTranscriptionIDs.contains(transcription.id) {
            favoriteTranscriptionIDs.remove(transcription.id)
        } else {
            favoriteTranscriptionIDs.insert(transcription.id)
        }
        saveFavorites()
    }

    var favoriteTranscriptions: [Transcription] {
        transcriptions.filter { favoriteTranscriptionIDs.contains($0.id) }
    }

    // MARK: - AI Optimization

    func optimizeText(_ text: String) async throws -> String {
        let apiKey = UserDefaults.standard.string(forKey: "groq_api_key") ?? ""
        return try await TextOptimizationService.shared.optimizeText(text, apiKey: apiKey)
    }

    func optimizeLiveTranscription() {
        guard !liveTranscription.isEmpty else { return }

        // Sauvegarder l'original pour pouvoir annuler
        originalTextBeforeOptimization = liveTranscription
        isOptimizing = true

        Task {
            do {
                let optimized = try await optimizeText(liveTranscription)
                await MainActor.run {
                    self.liveTranscription = optimized
                    self.isOptimizing = false
                }
            } catch {
                await MainActor.run {
                    self.isOptimizing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func undoOptimization() {
        if let original = originalTextBeforeOptimization {
            liveTranscription = original
            originalTextBeforeOptimization = nil
        }
    }

    // MARK: - AI Summary

    @Published var isSummarizing = false

    /// Seuil de caractères pour suggérer un résumé automatique
    static let summarySuggestThreshold = 200

    /// Génère un résumé pour une transcription
    func summarizeTranscription(_ transcription: Transcription) async throws -> String {
        let apiKey = UserDefaults.standard.string(forKey: "groq_api_key") ?? ""
        return try await TextOptimizationService.shared.summarizeText(transcription.text, apiKey: apiKey)
    }

    /// Met à jour une transcription avec son résumé
    func updateTranscriptionSummary(_ transcription: Transcription, summary: String) {
        if let index = transcriptions.firstIndex(where: { $0.id == transcription.id }) {
            var updated = transcriptions[index]
            updated.summary = summary
            transcriptions[index] = updated
            saveTranscriptions()
        }
    }

    /// Met à jour une transcription avec sa traduction
    func updateTranscriptionTranslation(_ transcription: Transcription, translation: String) {
        if let index = transcriptions.firstIndex(where: { $0.id == transcription.id }) {
            var updated = transcriptions[index]
            updated.translation = translation
            transcriptions[index] = updated
            saveTranscriptions()
        }
    }

    // MARK: - Tags Management

    /// Ajoute un tag à une transcription
    func addTag(_ tag: String, to transcription: Transcription) {
        if let index = transcriptions.firstIndex(where: { $0.id == transcription.id }) {
            var updated = transcriptions[index]
            let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanTag.isEmpty && !updated.tags.contains(cleanTag) {
                updated.tags.append(cleanTag)
                transcriptions[index] = updated
                saveTranscriptions()
            }
        }
    }

    /// Supprime un tag d'une transcription
    func removeTag(_ tag: String, from transcription: Transcription) {
        if let index = transcriptions.firstIndex(where: { $0.id == transcription.id }) {
            var updated = transcriptions[index]
            updated.tags.removeAll { $0 == tag }
            transcriptions[index] = updated
            saveTranscriptions()
        }
    }

    /// Met à jour les tags d'une transcription
    func updateTags(_ transcription: Transcription, tags: [String]) {
        if let index = transcriptions.firstIndex(where: { $0.id == transcription.id }) {
            var updated = transcriptions[index]
            updated.tags = tags
            transcriptions[index] = updated
            saveTranscriptions()
        }
    }

    /// Retourne tous les tags utilisés dans l'historique
    var allUsedTags: [String] {
        var tagsSet = Set<String>()
        for transcription in transcriptions {
            tagsSet.formUnion(transcription.tags)
        }
        return Array(tagsSet).sorted()
    }

    /// Génère et sauvegarde le résumé d'une transcription
    func generateAndSaveSummary(for transcription: Transcription) {
        isSummarizing = true

        Task {
            do {
                let summary = try await summarizeTranscription(transcription)
                await MainActor.run {
                    self.updateTranscriptionSummary(transcription, summary: summary)
                    self.isSummarizing = false
                }
            } catch {
                await MainActor.run {
                    self.isSummarizing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Vérifie si une transcription devrait suggérer un résumé
    func shouldSuggestSummary(_ transcription: Transcription) -> Bool {
        transcription.summary == nil && transcription.text.count >= Self.summarySuggestThreshold
    }
}


import Combine