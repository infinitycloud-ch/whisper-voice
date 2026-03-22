import SwiftUI

struct TranscriptionModal: View {
    let transcription: Transcription
    @EnvironmentObject var manager: TranscriptionManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_theme") private var currentTheme: String = AppTheme.cyberpunk.rawValue

    @State private var editedText: String = ""
    @State private var originalText: String = ""
    @State private var isOptimizing = false
    @State private var hasBeenOptimized = false
    @State private var isSummarizing = false
    @State private var currentSummary: String? = nil
    @State private var isTranslating = false
    @State private var currentTranslation: String? = nil
    @State private var currentTags: [String] = []
    @State private var newTagInput: String = ""
    @State private var showTagSuggestions = false
    @State private var isRecordingAppend = false
    @State private var isAIModified = false
    @State private var showOptimizationSplit = false
    @State private var optimizedText: String = ""

    var theme: AppTheme {
        AppTheme(rawValue: currentTheme) ?? .dark
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentColor)

                Text("Transcription")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textColor)

                Spacer()

                // Date & Duration
                Text(transcription.formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryTextColor)

                Text("•")
                    .foregroundColor(theme.secondaryTextColor)

                Text(transcription.formattedDuration)
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryTextColor)

                // Favorite toggle
                Button(action: {
                    manager.toggleFavorite(transcription)
                }) {
                    Image(systemName: manager.isFavorite(transcription) ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundColor(manager.isFavorite(transcription) ? .orange : theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
                .help(manager.isFavorite(transcription) ? "Retirer des favoris" : "Ajouter aux favoris")

                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(theme.secondaryBackgroundColor.opacity(0.5))

            Divider()

            // Text content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Résumé IA (si disponible)
                    if let summary = currentSummary {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "text.quote")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.accentColor)
                                Text("Résumé IA")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(theme.accentColor)
                                Spacer()
                            }

                            Text(summary)
                                .font(.system(size: 13))
                                .foregroundColor(theme.textColor)
                                .padding(10)
                                .background(theme.accentColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }

                    // Traduction (si disponible)
                    if let translation = currentTranslation {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                Text("Traduction FR↔EN")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.orange)
                                Spacer()

                                // Copy translation button
                                Button(action: {
                                    manager.copyToClipboard(translation, showSuccess: true)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.secondaryTextColor)
                                }
                                .buttonStyle(.plain)
                                .help("Copier la traduction")
                            }

                            Text(translation)
                                .font(.system(size: 13))
                                .foregroundColor(theme.textColor)
                                .padding(10)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // Tags section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 12))
                                .foregroundColor(theme.secondaryTextColor)
                            Text("Tags")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.secondaryTextColor)
                            Spacer()
                        }

                        // Tags chips
                        FlowLayout(spacing: 6) {
                            ForEach(currentTags, id: \.self) { tag in
                                TagChip(tag: tag, onRemove: {
                                    removeTag(tag)
                                })
                            }

                            // Bouton ajouter tag
                            if showTagSuggestions {
                                // Input field
                                HStack(spacing: 4) {
                                    TextField("Tag...", text: $newTagInput)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12))
                                        .frame(width: 60)
                                        .onSubmit {
                                            addNewTag()
                                        }

                                    Button(action: addNewTag) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(newTagInput.isEmpty)

                                    Button(action: { showTagSuggestions = false; newTagInput = "" }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.secondaryBackgroundColor)
                                .cornerRadius(12)
                            } else {
                                Button(action: { showTagSuggestions = true }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.secondaryTextColor)
                                        .padding(6)
                                        .background(theme.secondaryBackgroundColor.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Suggestions
                        if showTagSuggestions {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(availableSuggestions, id: \.self) { suggestion in
                                        Button(action: { addTag(suggestion) }) {
                                            Text(suggestion)
                                                .font(.system(size: 11))
                                                .foregroundColor(Transcription.colorForTag(suggestion))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Transcription.colorForTag(suggestion).opacity(0.15))
                                                .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Texte - vue normale ou vue divisée pour optimisation
                    if showOptimizationSplit {
                        // Vue divisée : Original | Optimisé
                        HStack(spacing: 12) {
                            // Original (gauche)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Original")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(theme.secondaryTextColor)

                                TextEditor(text: $editedText)
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.textColor)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 180)
                                    .padding(8)
                                    .background(theme.secondaryBackgroundColor.opacity(0.3))
                                    .cornerRadius(8)
                            }

                            // Optimisé (droite)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Optimisé")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.green)

                                    Spacer()

                                    // Accept button
                                    Button(action: acceptOptimization) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10))
                                            Text("Accepter")
                                                .font(.system(size: 11))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green)
                                        .cornerRadius(5)
                                    }
                                    .buttonStyle(.plain)

                                    // Reject button
                                    Button(action: rejectOptimization) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10))
                                            Text("Refuser")
                                                .font(.system(size: 11))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.8))
                                        .cornerRadius(5)
                                    }
                                    .buttonStyle(.plain)
                                }

                                TextEditor(text: $optimizedText)
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.textColor)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 180)
                                    .padding(8)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Vue normale
                        TextEditor(text: $editedText)
                            .font(.system(size: 15))
                            .foregroundColor(theme.textColor)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 200)
                            .padding(.horizontal)
                    }
                }
            }
            .background(theme.backgroundColor)

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                // Record/Append button
                Button(action: toggleAppendRecording) {
                    HStack(spacing: 6) {
                        if isRecordingAppend {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 12))
                        }
                        Text(isRecordingAppend ? "Stop" : "Ajouter")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isRecordingAppend ? Color.red : Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Enregistrer et ajouter du contenu")

                Divider()
                    .frame(height: 20)

                // AI Summarize
                Button(action: summarizeText) {
                    HStack(spacing: 6) {
                        if isSummarizing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "text.quote")
                                .font(.system(size: 12))
                        }
                        Text("Résumer")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(currentSummary != nil ? Color.green : theme.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isSummarizing)
                .help(currentSummary != nil ? "Régénérer le résumé" : "Générer un résumé IA")

                // AI Translate
                Button(action: translateText) {
                    HStack(spacing: 6) {
                        if isTranslating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "globe")
                                .font(.system(size: 12))
                        }
                        Text("Traduire")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(currentTranslation != nil ? Color.green : theme.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isTranslating)
                .help(currentTranslation != nil ? "Retraduire (FR↔EN)" : "Traduire FR↔EN")

                // AI Optimize
                Button(action: optimizeText) {
                    HStack(spacing: 6) {
                        if isOptimizing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 12))
                        }
                        Text("Optimiser")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isOptimizing)
                .help("Optimiser le texte avec l'IA")

                // Undo (only if optimized)
                if hasBeenOptimized {
                    Button(action: undoOptimization) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 12))
                            Text("Annuler")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(theme.textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.secondaryBackgroundColor)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Revenir au texte original")
                }

                Spacer()

                // Copy
                Button(action: {
                    manager.copyToClipboard(editedText, showSuccess: true)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                        Text("Copier")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(theme.textColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.secondaryBackgroundColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Copier dans le presse-papiers")

                // Save changes
                if editedText != transcription.text {
                    Button(action: saveChanges) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 12))
                            Text("Sauvegarder")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Sauvegarder les modifications")
                }
            }
            .padding()
            .background(theme.secondaryBackgroundColor.opacity(0.5))
        }
        .frame(width: showOptimizationSplit ? 900 : 700, height: showOptimizationSplit ? 580 : 520)
        .animation(.easeInOut(duration: 0.2), value: showOptimizationSplit)
        .background(theme.backgroundColor)
        .cornerRadius(12)
        .onAppear {
            editedText = transcription.text
            originalText = transcription.text
            currentSummary = transcription.summary
            currentTranslation = transcription.translation
            currentTags = transcription.tags
            isAIModified = transcription.isAIModified
        }
    }

    // MARK: - Tags Management

    private var availableSuggestions: [String] {
        Transcription.suggestedTags.filter { !currentTags.contains($0) }
    }

    private func addTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTag.isEmpty && !currentTags.contains(cleanTag) {
            currentTags.append(cleanTag)
            manager.updateTags(transcription, tags: currentTags)
        }
        newTagInput = ""
    }

    private func addNewTag() {
        addTag(newTagInput)
        showTagSuggestions = false
    }

    private func removeTag(_ tag: String) {
        currentTags.removeAll { $0 == tag }
        manager.updateTags(transcription, tags: currentTags)
    }

    // MARK: - Append Recording

    private func toggleAppendRecording() {
        if isRecordingAppend {
            stopAppendRecording()
        } else {
            startAppendRecording()
        }
    }

    private func startAppendRecording() {
        isRecordingAppend = true
        manager.startRecording()
    }

    private func stopAppendRecording() {
        isRecordingAppend = false

        // Stop recording and get transcription
        Task {
            // Wait a bit for the recording to finalize
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

            await MainActor.run {
                // The manager will process the transcription
                manager.shouldAppendNextRecording = false // Don't add to list
                manager.stopAndTranscribe()
            }

            // Wait for transcription to complete
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s

            await MainActor.run {
                // Append the new transcription to our text
                if !manager.liveTranscription.isEmpty &&
                   manager.liveTranscription != "Transcription en cours..." {
                    let newContent = manager.liveTranscription
                        .replacingOccurrences(of: "📝 ", with: "")
                    editedText = editedText + "\n\n" + newContent
                    manager.liveTranscription = ""
                }
            }
        }
    }

    private func summarizeText() {
        isSummarizing = true

        Task {
            do {
                let apiKey = UserDefaults.standard.string(forKey: "groq_api_key") ?? ""
                let summary = try await TextOptimizationService.shared.summarizeText(editedText, apiKey: apiKey)

                await MainActor.run {
                    currentSummary = summary
                    // Sauvegarder le résumé avec la transcription
                    manager.updateTranscriptionSummary(transcription, summary: summary)
                    isSummarizing = false
                }
            } catch {
                await MainActor.run {
                    isSummarizing = false
                    manager.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func translateText() {
        isTranslating = true

        Task {
            do {
                let apiKey = UserDefaults.standard.string(forKey: "groq_api_key") ?? ""
                let translation = try await TextOptimizationService.shared.translateText(editedText, apiKey: apiKey)

                await MainActor.run {
                    currentTranslation = translation
                    // Sauvegarder la traduction avec la transcription
                    manager.updateTranscriptionTranslation(transcription, translation: translation)
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    isTranslating = false
                    manager.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func optimizeText() {
        isOptimizing = true

        Task {
            do {
                let apiKey = UserDefaults.standard.string(forKey: "groq_api_key") ?? ""
                let optimized = try await TextOptimizationService.shared.optimizeText(editedText, apiKey: apiKey)

                await MainActor.run {
                    if !hasBeenOptimized {
                        originalText = editedText
                    }
                    optimizedText = optimized
                    showOptimizationSplit = true
                    isOptimizing = false
                }
            } catch {
                await MainActor.run {
                    isOptimizing = false
                    manager.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func acceptOptimization() {
        editedText = optimizedText
        hasBeenOptimized = true
        isAIModified = true
        showOptimizationSplit = false
        optimizedText = ""
    }

    private func rejectOptimization() {
        showOptimizationSplit = false
        optimizedText = ""
    }

    private func undoOptimization() {
        editedText = originalText
        hasBeenOptimized = false
    }

    private func saveChanges() {
        // Update the transcription in the manager
        if let index = manager.transcriptions.firstIndex(where: { $0.id == transcription.id }) {
            let updated = Transcription(
                text: editedText,
                audioURL: transcription.audioURL,
                timestamp: transcription.timestamp,
                duration: transcription.duration,
                language: transcription.language,
                isPRD: transcription.isPRD,
                prdTitle: transcription.prdTitle,
                summary: currentSummary,
                tags: currentTags,
                translation: currentTranslation,
                isAIModified: isAIModified || transcription.isAIModified,
                id: transcription.id
            )
            manager.transcriptions[index] = updated
            manager.saveTranscriptions()
        }
        dismiss()
    }
}

// MARK: - Tag Chip Component

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 12))
                .foregroundColor(Transcription.colorForTag(tag))

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Transcription.colorForTag(tag).opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Transcription.colorForTag(tag).opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Flow Layout (wrapping chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)

        for (index, placement) in result.placements.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y),
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, placements: [(x: CGFloat, y: CGFloat, size: CGSize)]) {
        let maxWidth = proposal.width ?? .infinity
        var placements: [(x: CGFloat, y: CGFloat, size: CGSize)] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            placements.append((x: currentX, y: currentY, size: size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalHeight = max(totalHeight, currentY + size.height)
        }

        return (CGSize(width: maxWidth, height: totalHeight), placements)
    }
}
