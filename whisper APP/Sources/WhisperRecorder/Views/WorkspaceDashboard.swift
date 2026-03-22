import SwiftUI

struct WorkspaceSection: Identifiable {
    let id = UUID()
    var text: String = ""
    var isFavorite: Bool = false
}

struct WorkspaceDashboard: View {
    @EnvironmentObject var manager: TranscriptionManager
    @Binding var isPresented: Bool
    @AppStorage("app_theme") private var currentTheme: String = AppTheme.cyberpunk.rawValue

    @State private var sections: [WorkspaceSection] = [WorkspaceSection()]
    @State private var isRecording = false
    @State private var recordingForSection: UUID? = nil

    var theme: AppTheme {
        AppTheme(rawValue: currentTheme) ?? .dark
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentColor)

                Text("Workspace Dashboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textColor)

                Spacer()

                // Add section button
                Button(action: addSection) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Section")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(theme.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.accentColor.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Ajouter une nouvelle section")

                // Save all favorites button
                Button(action: saveAllFavorites) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                        Text("Sauver favoris")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(sections.filter { $0.isFavorite && !$0.text.isEmpty }.isEmpty)
                .help("Sauvegarder toutes les sections marquées en favoris")

                // Close button
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(theme.secondaryBackgroundColor.opacity(0.5))

            Divider()

            // Sections
            ScrollView {
                VStack(spacing: 16) {
                    ForEach($sections) { $section in
                        SectionCard(
                            section: $section,
                            isRecording: recordingForSection == section.id,
                            onRecord: { toggleRecording(for: section.id) },
                            onDelete: { deleteSection(section.id) },
                            theme: theme
                        )
                    }
                }
                .padding()
            }
        }
        .frame(width: 800, height: 600)
        .background(theme.backgroundColor)
        .cornerRadius(12)
    }

    private func addSection() {
        withAnimation {
            sections.append(WorkspaceSection())
        }
    }

    private func deleteSection(_ id: UUID) {
        withAnimation {
            sections.removeAll { $0.id == id }
            if sections.isEmpty {
                sections.append(WorkspaceSection())
            }
        }
    }

    private func toggleRecording(for sectionID: UUID) {
        if recordingForSection == sectionID {
            // Stop recording
            recordingForSection = nil
            isRecording = false
            manager.toggleRecording()

            // Wait for transcription and append to section
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let lastTranscription = manager.transcriptions.first {
                    if let index = sections.firstIndex(where: { $0.id == sectionID }) {
                        if sections[index].text.isEmpty {
                            sections[index].text = lastTranscription.text
                        } else {
                            sections[index].text += "\n\n" + lastTranscription.text
                        }
                    }
                }
            }
        } else {
            // Start recording for this section
            recordingForSection = sectionID
            isRecording = true
            manager.toggleRecording()
        }
    }

    private func saveAllFavorites() {
        for section in sections where section.isFavorite && !section.text.isEmpty {
            // Create a new transcription and mark it as favorite
            manager.addTranscription(text: section.text)

            // Mark the newly added transcription as favorite
            if let newTranscription = manager.transcriptions.first {
                manager.toggleFavorite(newTranscription)
            }
        }

        // Clear saved sections
        sections = sections.map { section in
            if section.isFavorite && !section.text.isEmpty {
                return WorkspaceSection() // Reset saved sections
            }
            return section
        }

        manager.copySuccessMessage = "Favoris sauvegardés!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            manager.copySuccessMessage = nil
        }
    }
}

struct SectionCard: View {
    @Binding var section: WorkspaceSection
    let isRecording: Bool
    let onRecord: () -> Void
    let onDelete: () -> Void
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                // Favorite toggle
                Button(action: {
                    section.isFavorite.toggle()
                }) {
                    Image(systemName: section.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundColor(section.isFavorite ? .orange : theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
                .help(section.isFavorite ? "Retirer des favoris" : "Marquer comme favori")

                Spacer()

                // Record button
                Button(action: onRecord) {
                    HStack(spacing: 4) {
                        if isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 11))
                        }
                        Text(isRecording ? "Stop" : "Enregistrer")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(isRecording ? .red : theme.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.red.opacity(0.15) : theme.accentColor.opacity(0.15))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                // Copy button
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(section.text, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
                .disabled(section.text.isEmpty)

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            // Text editor
            TextEditor(text: $section.text)
                .font(.system(size: 13))
                .foregroundColor(theme.textColor)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(8)
                .background(theme.secondaryBackgroundColor.opacity(0.3))
                .cornerRadius(8)
                .overlay(
                    Group {
                        if section.text.isEmpty {
                            Text("Tapez ou enregistrez du texte...")
                                .font(.system(size: 13))
                                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                                .padding(.leading, 12)
                                .padding(.top, 16)
                        }
                    },
                    alignment: .topLeading
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.secondaryBackgroundColor.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(section.isFavorite ? Color.orange.opacity(0.5) : theme.accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
