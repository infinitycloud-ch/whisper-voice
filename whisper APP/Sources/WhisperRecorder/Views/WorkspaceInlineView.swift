import SwiftUI

/// Vue Workspace intégrée dans le panneau droit (pas en modal)
struct WorkspaceInlineView: View {
    @EnvironmentObject var manager: TranscriptionManager
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
                Text("Workspace")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textColor)

                Text("\(sections.count) section\(sections.count > 1 ? "s" : "")")
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(theme.secondaryBackgroundColor)
                    .cornerRadius(10)

                Spacer()

                // Add section button
                Button(action: addSection) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("Section")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(theme.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.accentColor.opacity(0.15))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                // Save all favorites
                if sections.contains(where: { $0.isFavorite && !$0.text.isEmpty }) {
                    Button(action: saveAllFavorites) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                            Text("Sauver")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Sections list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach($sections) { $section in
                        InlineSectionCard(
                            section: $section,
                            isRecording: recordingForSection == section.id,
                            onRecord: { toggleRecording(for: section.id) },
                            onDelete: { deleteSection(section.id) },
                            theme: theme
                        )
                    }
                }
                .padding(12)
            }
        }
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
            recordingForSection = nil
            isRecording = false
            manager.toggleRecording()

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
            recordingForSection = sectionID
            isRecording = true
            manager.toggleRecording()
        }
    }

    private func saveAllFavorites() {
        for section in sections where section.isFavorite && !section.text.isEmpty {
            manager.addTranscription(text: section.text)
            if let newTranscription = manager.transcriptions.first {
                manager.toggleFavorite(newTranscription)
            }
        }

        sections = sections.map { section in
            if section.isFavorite && !section.text.isEmpty {
                return WorkspaceSection()
            }
            return section
        }

        manager.copySuccessMessage = "Favoris sauvegardés!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            manager.copySuccessMessage = nil
        }
    }
}

struct InlineSectionCard: View {
    @Binding var section: WorkspaceSection
    let isRecording: Bool
    let onRecord: () -> Void
    let onDelete: () -> Void
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 8) {
                // Favorite
                Button(action: { section.isFavorite.toggle() }) {
                    Image(systemName: section.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundColor(section.isFavorite ? .orange : theme.secondaryTextColor)
                }
                .buttonStyle(.plain)

                Spacer()

                // Record
                Button(action: onRecord) {
                    HStack(spacing: 3) {
                        if isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 10))
                        }
                        Text(isRecording ? "Stop" : "Rec")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(isRecording ? .red : theme.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isRecording ? Color.red.opacity(0.15) : theme.accentColor.opacity(0.15))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                // Copy
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(section.text, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
                .disabled(section.text.isEmpty)

                // Delete
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            // Text
            TextEditor(text: $section.text)
                .font(.system(size: 12))
                .foregroundColor(theme.textColor)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60, maxHeight: 150)
                .padding(6)
                .background(theme.secondaryBackgroundColor.opacity(0.2))
                .cornerRadius(6)
                .overlay(
                    Group {
                        if section.text.isEmpty {
                            Text("Tapez ou enregistrez...")
                                .font(.system(size: 11))
                                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                                .padding(.leading, 10)
                                .padding(.top, 14)
                        }
                    },
                    alignment: .topLeading
                )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.secondaryBackgroundColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(section.isFavorite ? Color.orange.opacity(0.4) : theme.accentColor.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
