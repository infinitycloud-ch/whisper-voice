import SwiftUI

struct TranscriptionDetailView: View {
    let transcription: Transcription
    @EnvironmentObject var manager: TranscriptionManager
    @AppStorage("app_theme") private var currentTheme: String = AppTheme.dark.rawValue
    @AppStorage("content_zoom_level") private var zoomLevel: Double = 1.0
    @State private var isEditing = false
    @State private var editedText = ""
    @State private var isCopied = false
    
    var theme: AppTheme {
        AppTheme(rawValue: currentTheme) ?? .dark
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header avec boutons d'action
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transcription.formattedDate)
                        .font(.headline)
                        .foregroundColor(theme.textColor)
                    
                    HStack {
                        Text("Durée: \(transcription.formattedDuration)")
                        Text("•")
                        Text("\(transcription.text.count) caractères")
                    }
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
                }
                
                // Zoom control
                Menu {
                    Text("Taille: \(Int(zoomLevel * 100))%")
                    Slider(value: $zoomLevel, in: 0.5...2.0, step: 0.1)
                        .frame(width: 120)
                    Divider()
                    Button("Réinitialiser") {
                        zoomLevel = 1.0
                    }
                } label: {
                    Image(systemName: "textformat.size")
                        .foregroundColor(theme.secondaryTextColor)
                        .padding(4)
                        .background(theme.secondaryBackgroundColor.opacity(0.5))
                        .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .padding(.leading, 8)

                Spacer()
                
                // Boutons d'action
                HStack(spacing: 12) {
                    // Bouton Copier
                    Button(action: {
                        let textToCopy = isEditing ? editedText : transcription.text
                        manager.copyToClipboard(textToCopy, showSuccess: true)
                        withAnimation {
                            isCopied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isCopied = false
                            }
                        }
                    }) {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 16))
                            .foregroundColor(isCopied ? .green : theme.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .help("Copier")
                    
                    // Bouton Modifier/Sauvegarder
                    Button(action: {
                        if isEditing {
                            // Sauvegarder les modifications
                            if let index = manager.transcriptions.firstIndex(where: { $0.id == transcription.id }) {
                                let updatedTranscription = Transcription(
                                    text: editedText,
                                    timestamp: transcription.timestamp,
                                    duration: transcription.duration
                                )
                                manager.transcriptions[index] = updatedTranscription
                                manager.saveTranscriptions()
                                manager.liveTranscription = editedText
                            }
                            isEditing = false
                        } else {
                            // Commencer à éditer
                            editedText = transcription.text
                            isEditing = true
                        }
                    }) {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                            .font(.system(size: 16))
                            .foregroundColor(isEditing ? .green : theme.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .help(isEditing ? "Sauvegarder" : "Modifier")
                    
                    // Bouton Annuler (si en édition)
                    if isEditing {
                        Button(action: {
                            isEditing = false
                            editedText = transcription.text
                        }) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.borderless)
                        .help("Annuler")
                    }
                    
                    // Bouton Supprimer
                    Button(action: {
                        manager.deleteTranscription(transcription)
                    }) {
                        Image(systemName: "trash.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Supprimer")
                }
            }
            .padding()
            .background(theme.secondaryBackgroundColor.opacity(0.3))
            .cornerRadius(8)
            
            // Content
            ScrollView {
                if isEditing {
                    ZStack {
                        theme.secondaryBackgroundColor.opacity(0.2)
                        TextEditor(text: $editedText)
                            .font(.system(size: 16 * zoomLevel))
                            .foregroundColor(theme.textColor)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                    }
                    .cornerRadius(8)
                    .frame(minHeight: 200)
                } else {
                    Text(transcription.text)
                        .font(.system(size: 16 * zoomLevel))
                        .foregroundColor(theme.textColor)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(theme.secondaryBackgroundColor.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundColor)
        .onAppear {
            editedText = transcription.text
        }
    }
}