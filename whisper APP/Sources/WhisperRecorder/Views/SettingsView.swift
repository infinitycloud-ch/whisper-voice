import SwiftUI
import HotKey
import Carbon

struct SettingsView: View {
    @AppStorage("groq_api_key") private var groqApiKey = ""
    @AppStorage("openai_api_key") private var openaiApiKey = ""
    @AppStorage("selected_api") private var selectedAPI = "groq"
    @AppStorage("auto_paste_enabled") private var autoPasteEnabled = true
    @AppStorage("live_transcription_enabled") private var liveTranscriptionEnabled = true
    @State private var tempGroqKey = ""
    @State private var tempOpenAIKey = ""
    @State private var isValidatingKey = false
    @State private var keyValidationResult: Bool?
    @State private var isRecordingHotkey = false
    @State private var hotkeyMonitor: Any?
    @EnvironmentObject var manager: TranscriptionManager
    
    var body: some View {
        Form {
            Section("Configuration API") {
                Picker("API Sélectionnée", selection: $selectedAPI) {
                    Text("Groq (Rapide)").tag("groq")
                    Text("OpenAI").tag("openai")
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)
                
                if selectedAPI == "groq" {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Clé API Groq")
                            .font(.headline)
                        
                        HStack {
                            SecureField("gsk_...", text: $tempGroqKey)
                                .textFieldStyle(.roundedBorder)
                                .onAppear {
                                    tempGroqKey = groqApiKey
                                }
                            
                            Button("Sauvegarder") {
                                groqApiKey = tempGroqKey
                            }
                            .disabled(tempGroqKey.isEmpty)
                        }
                        
                        Link("Obtenir une clé API Groq", 
                             destination: URL(string: "https://console.groq.com/keys")!)
                            .font(.caption)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Clé API OpenAI")
                            .font(.headline)
                        
                        HStack {
                            SecureField("sk-...", text: $tempOpenAIKey)
                                .textFieldStyle(.roundedBorder)
                                .onAppear {
                                    tempOpenAIKey = openaiApiKey
                                }
                            
                            Button("Sauvegarder") {
                                openaiApiKey = tempOpenAIKey
                            }
                            .disabled(tempOpenAIKey.isEmpty)
                        }
                        
                        Link("Obtenir une clé API OpenAI", 
                             destination: URL(string: "https://platform.openai.com/api-keys")!)
                            .font(.caption)
                    }
                }
            }
            
            Section("Raccourci clavier") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Raccourci global")
                        .font(.headline)

                    HStack(spacing: 12) {
                        // Affichage du raccourci actuel
                        Text(manager.currentHotkeyDescription)
                            .font(.system(.title2, design: .monospaced))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isRecordingHotkey ? Color.red.opacity(0.3) : Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isRecordingHotkey ? Color.red : Color.clear, lineWidth: 2)
                            )

                        if isRecordingHotkey {
                            Text("Appuyez sur le nouveau raccourci...")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("Démarrer/Arrêter l'enregistrement")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        // Bouton Modifier
                        Button(action: {
                            if isRecordingHotkey {
                                stopRecordingHotkey()
                            } else {
                                startRecordingHotkey()
                            }
                        }) {
                            HStack {
                                Image(systemName: isRecordingHotkey ? "stop.fill" : "record.circle")
                                Text(isRecordingHotkey ? "Annuler" : "Modifier")
                            }
                        }
                        .buttonStyle(.bordered)

                        // Bouton Reset
                        Button(action: {
                            manager.resetHotkeyToDefault()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Défaut (⌥X)")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRecordingHotkey)
                    }

                    Text("Utilisez une combinaison avec ⌥ Option, ⌃ Control, ⇧ Shift ou ⌘ Command")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Options") {
                Toggle("Collage automatique après transcription", isOn: $autoPasteEnabled)

                if autoPasteEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Permissions requises", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Text("L'auto-paste nécessite les permissions d'Accessibilité.")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("Si ça ne fonctionne pas: Préférences Système > Sécurité > Accessibilité")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }

                Divider()

                Toggle("Transcription en temps réel", isOn: $liveTranscriptionEnabled)

                if liveTranscriptionEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Aperçu progressif toutes les 5s", systemImage: "waveform.badge.mic")
                            .font(.caption)
                            .foregroundColor(.blue)

                        Text("Affiche le texte pendant l'enregistrement. Consomme plus d'appels API.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            
            Section("Statistiques") {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    // Total transcriptions
                    StatCard(
                        icon: "waveform",
                        value: "\(manager.transcriptions.count)",
                        label: "Transcriptions",
                        color: .blue
                    )

                    // Favoris
                    StatCard(
                        icon: "star.fill",
                        value: "\(manager.favoriteTranscriptionIDs.count)",
                        label: "Favoris",
                        color: .orange
                    )

                    // Temps total
                    StatCard(
                        icon: "clock.fill",
                        value: formatTotalDuration(),
                        label: "Temps total",
                        color: .green
                    )

                    // Avec résumé
                    StatCard(
                        icon: "text.quote",
                        value: "\(manager.transcriptions.filter { $0.summary != nil }.count)",
                        label: "Avec résumé",
                        color: .purple
                    )
                }

                // Dates première/dernière
                if let firstDate = manager.transcriptions.last?.timestamp,
                   let lastDate = manager.transcriptions.first?.timestamp {
                    Divider()
                        .padding(.vertical, 4)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Première")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatDate(firstDate))
                                .font(.caption)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Dernière")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatDate(lastDate))
                                .font(.caption)
                        }
                    }
                }
            }

            Section("À propos") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Whisper by Mr D", systemImage: "mic.fill")
                        .font(.headline)

                    Text(selectedAPI == "groq" ? "Utilise Groq Whisper Large v3 Turbo" : "Utilise OpenAI Whisper")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Transcription rapide avec copie automatique")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Données") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(manager.transcriptions.count) transcription(s) sauvegardée(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Exporter (.txt)") {
                            if let fileURL = manager.exportTranscriptionsAsText() {
                                NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: "")
                            }
                        }
                        
                        Button("Exporter (.json)") {
                            if let fileURL = manager.exportTranscriptionsToFile() {
                                NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: "")
                            }
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Button("Garder les 30 dernières") {
                            manager.purgeOldTranscriptions()
                        }
                        .foregroundColor(.orange)
                        
                        Button("Effacer tout l'historique") {
                            manager.purgeAllTranscriptions()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 620)
    }
    
    private func validateAndSaveKey() {
        isValidatingKey = true
        keyValidationResult = nil

        Task {
            let isValid = await GroqAPIService.shared.validateAPIKey(tempGroqKey)

            await MainActor.run {
                keyValidationResult = isValid
                if isValid {
                    groqApiKey = tempGroqKey
                }
                isValidatingKey = false
            }
        }
    }

    // MARK: - Statistics Helpers

    private func formatTotalDuration() -> String {
        let totalSeconds = manager.transcriptions.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(Int(totalSeconds))s"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Hotkey Recording

    private func startRecordingHotkey() {
        isRecordingHotkey = true

        // Écouter les événements clavier globaux
        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleKeyEvent(event)
            return nil // Consommer l'événement
        }
    }

    private func stopRecordingHotkey() {
        isRecordingHotkey = false
        if let monitor = hotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Ignorer si pas en mode enregistrement
        guard isRecordingHotkey else { return }

        // Ignorer les touches modificatrices seules
        let modifierOnlyKeys: [UInt16] = [55, 54, 59, 62, 58, 61, 56, 60, 63] // Command, Shift, Control, Option, Fn
        if modifierOnlyKeys.contains(event.keyCode) {
            return
        }

        // Ignorer Escape (annuler)
        if event.keyCode == 53 {
            stopRecordingHotkey()
            return
        }

        // Vérifier qu'au moins un modificateur est utilisé
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else {
            return // Ignorer les touches sans modificateur
        }

        // Créer le KeyCombo
        let keyCombo = KeyCombo(
            carbonKeyCode: UInt32(event.keyCode),
            carbonModifiers: modifiers.carbonFlags
        )

        // Appliquer le nouveau raccourci
        manager.updateHotkey(keyCombo: keyCombo)
        stopRecordingHotkey()
    }
}

// Extension pour obtenir carbonFlags depuis NSEvent.ModifierFlags
extension NSEvent.ModifierFlags {
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)

                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}