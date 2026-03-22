import SwiftUI

struct MicrophoneMinimalView: View {
    @EnvironmentObject var manager: TranscriptionManager
    @EnvironmentObject var uiState: UIStateModel
    @AppStorage("app_theme") private var currentTheme: String = AppTheme.dark.rawValue
    
    var theme: AppTheme {
        AppTheme(rawValue: currentTheme) ?? .dark
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Bouton principal
            Button(action: {
                manager.toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(manager.isRecording ? theme.recordColor : theme.accentColor)
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: manager.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            
            // Indicateur de temps ou texte transcrit
            if manager.isRecording {
                Text(formatTime(manager.recordingTime))
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textColor)
                    .monospacedDigit()
            } else if manager.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Transcription...")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryTextColor)
                }
            } else if !manager.liveTranscription.isEmpty && manager.liveTranscription != "Transcription en cours..." {
                // Afficher le texte transcrit avec bouton copier
                VStack(spacing: 4) {
                    ScrollView {
                        Text(manager.liveTranscription)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 60)

                    Button(action: {
                        manager.copyToClipboard(manager.liveTranscription, showSuccess: true)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("Copier")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(theme.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.accentColor.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Prêt")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(theme.secondaryTextColor)
            }
            
            // Boutons pour changer de mode
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation {
                        uiState.windowMode = .medium
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
                .help("Mode liste")

                Button(action: {
                    withAnimation {
                        uiState.windowMode = .full
                    }
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
                .help("Mode complet")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundColor)
        .onAppear {
            // Mode compact: toujours au premier plan
            if let window = NSApp.windows.first {
                window.level = .floating
            }
        }
        .onDisappear {
            // Quand on quitte le mode compact, restaurer le niveau normal (sauf si stayOnTop est activé)
            if let window = NSApp.windows.first {
                window.level = manager.stayOnTop ? .floating : .normal
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}