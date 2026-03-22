import SwiftUI

struct RecorderHeaderView: View {
    @EnvironmentObject var manager: TranscriptionManager
    var theme: AppTheme
    @AppStorage("global_zoom_level") private var zoomLevel: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Recording Status / Timer
                if manager.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(theme.recordColor)
                            .frame(width: 8, height: 8)
                            .opacity(manager.recordingTime.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.3)
                        
                        Text(formatTime(manager.recordingTime))
                            .font(.system(size: 14, weight: .medium).monospacedDigit())
                            .foregroundColor(theme.recordColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.recordColor.opacity(0.1))
                    .cornerRadius(4)
                } else if manager.isProcessing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                        Text("Transcription...")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                } else {
                    Text("Prêt")
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }
                
                Spacer()
                
                // Record Button
                Button(action: {
                    manager.toggleRecording()
                }) {
                    ZStack {
                        if manager.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.recordColor)
                                .frame(width: 12, height: 12)
                        } else {
                            Circle()
                                .fill(theme.recordColor)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .background(manager.isRecording ? theme.recordColor.opacity(0.2) : theme.accentColor.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(manager.isRecording ? theme.recordColor : theme.accentColor, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut("x", modifiers: [.option])
                .help("Enregistrer (⌥X)")
                .disabled(manager.isProcessing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // Live Waveform (only when recording)
            if manager.isRecording {
                RealTimeWaveform(audioLevels: manager.audioLevels, theme: theme)
                    .frame(height: 30)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Zoom + Paste Delay Sliders
            HStack(spacing: 12) {
                // Zoom
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 9))
                        .foregroundColor(theme.secondaryTextColor)

                    Slider(value: $zoomLevel, in: 0.8...1.5, step: 0.05)
                        .frame(width: 60)
                        .controlSize(.mini)

                    Text("\(Int(zoomLevel * 100))%")
                        .font(.system(size: 9))
                        .foregroundColor(theme.secondaryTextColor)
                        .frame(width: 28)
                }

                Divider()
                    .frame(height: 12)

                // Paste Delay
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 9))
                        .foregroundColor(theme.secondaryTextColor)

                    Slider(value: $manager.autoPasteDelay, in: 0.1...2.0, step: 0.1)
                        .frame(width: 60)
                        .controlSize(.mini)

                    Text("\(String(format: "%.1f", manager.autoPasteDelay))s")
                        .font(.system(size: 9))
                        .foregroundColor(theme.secondaryTextColor)
                        .frame(width: 24)
                }

                // Toggle auto-paste
                Toggle("", isOn: $manager.autoPasteEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help(manager.autoPasteEnabled ? "Auto-coller activé" : "Auto-coller désactivé")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .background(theme.secondaryBackgroundColor.opacity(0.3))
        .overlay(Rectangle().frame(height: 1).foregroundColor(theme.secondaryBackgroundColor), alignment: .bottom)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
