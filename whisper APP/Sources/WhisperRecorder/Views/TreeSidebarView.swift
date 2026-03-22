import SwiftUI
import UniformTypeIdentifiers

// Version unifiée et stylisée de la sidebar
struct TreeSidebarView: View {
    @EnvironmentObject var manager: TranscriptionManager
    let folderManager: FolderTreeManager
    @Binding var selectedTranscription: Transcription?
    @Binding var selectedTranscriptions: Set<UUID>
    @Binding var isMultiSelecting: Bool
    let theme: AppTheme
    var compactMode: Bool = false
    @AppStorage("global_zoom_level") private var zoomLevel: Double = 1.0
    @State private var searchText = ""
    @State private var showingNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var refreshID = UUID()
    @State private var transcriptionForModal: Transcription?

    private var effectiveZoom: Double {
        compactMode ? min(zoomLevel, 0.85) : zoomLevel
    }

    init(folderManager: FolderTreeManager,
         selectedTranscription: Binding<Transcription?>,
         selectedTranscriptions: Binding<Set<UUID>>,
         isMultiSelecting: Binding<Bool>,
         theme: AppTheme,
         compactMode: Bool = false) {
        self.folderManager = folderManager
        self._selectedTranscription = selectedTranscription
        self._selectedTranscriptions = selectedTranscriptions
        self._isMultiSelecting = isMultiSelecting
        self.theme = theme
        self.compactMode = compactMode
    }
    
    var filteredTranscriptions: [Transcription] {
        if searchText.isEmpty {
            return manager.transcriptions
        } else {
            return manager.transcriptions.filter {
                // Recherche dans le texte OU dans les tags
                $0.text.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button(action: {
                    showingNewFolderAlert = true
                }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14))
                        .foregroundColor(theme.accentColor)
                }
                .buttonStyle(.borderless)
                .help("Nouveau dossier")
                
                if !selectedTranscriptions.isEmpty {
                    Text("\(selectedTranscriptions.count) sélectionnés")
                        .font(.caption)
                        .foregroundColor(theme.accentColor)
                    
                    Button(action: {
                        selectedTranscriptions.removeAll()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.secondaryBackgroundColor.opacity(0.3))
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.secondaryTextColor)
                    .font(.system(size: 11))
                TextField("Rechercher", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(5)
            .background(theme.secondaryBackgroundColor.opacity(0.2))
            .cornerRadius(5)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            
            // List
            List {
                // Bouton "Non classé"
                Button(action: {
                    manager.selectedFolderForNewRecording = nil
                    folderManager.selectedFolder = nil
                }) {
                    HStack {
                        Image(systemName: "tray")
                            .font(.system(size: 13 * zoomLevel))
                            .foregroundColor(manager.selectedFolderForNewRecording == nil ? theme.accentColor : theme.secondaryTextColor)
                        Text("Non classé")
                            .font(.system(size: 13 * zoomLevel))
                            .foregroundColor(manager.selectedFolderForNewRecording == nil ? theme.accentColor : theme.textColor)
                            .fontWeight(manager.selectedFolderForNewRecording == nil ? .semibold : .regular)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(manager.selectedFolderForNewRecording == nil ? theme.accentColor.opacity(0.2) : Color.clear)
                    )
                }
                .buttonStyle(.plain)

                // Section Favoris - DOSSIER SYSTÈME PERMANENT (non supprimable)
                DisclosureGroup {
                    if manager.favoriteTranscriptionIDs.isEmpty {
                        Text("Aucun favori")
                            .font(.system(size: 12 * zoomLevel))
                            .foregroundColor(theme.secondaryTextColor)
                            .italic()
                            .padding(.vertical, 8)
                            .padding(.leading, 10)
                    } else {
                        ForEach(filteredTranscriptions.filter { manager.isFavorite($0) }) { transcription in
                            UnifiedTranscriptionRow(
                                transcription: transcription,
                                isSelected: selectedTranscription?.id == transcription.id,
                                isMultiSelecting: isMultiSelecting,
                                selectedTranscriptions: $selectedTranscriptions,
                                theme: theme,
                                zoomLevel: zoomLevel,
                                searchText: searchText,
                                onDoubleClick: {
                                    if !isMultiSelecting {
                                        transcriptionForModal = transcription
                                    }
                                }
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13 * zoomLevel))
                            .foregroundColor(.orange)
                        Text("Favoris")
                            .font(.system(size: 13 * zoomLevel, weight: .semibold))
                            .foregroundColor(.orange)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.orange.opacity(0.1))
                    )
                }

                Divider()

                // Dossiers
                ForEach(folderManager.rootNodes) { folder in
                    FolderRowSimple(
                        folder: folder,
                        manager: manager,
                        folderManager: folderManager,
                        selectedTranscription: $selectedTranscription,
                        selectedTranscriptions: $selectedTranscriptions,
                        isMultiSelecting: $isMultiSelecting,
                        transcriptionForModal: $transcriptionForModal,
                        theme: theme,
                        zoomLevel: zoomLevel,
                        searchText: searchText
                    )
                }
                .id(refreshID)
                
                // Transcriptions non classées
                Section("Non classé") {
                    ForEach(filteredTranscriptions) { transcription in
                        if folderManager.getFolderForTranscription(id: transcription.id) == nil {
                            UnifiedTranscriptionRow(
                                transcription: transcription,
                                isSelected: selectedTranscription?.id == transcription.id,
                                isMultiSelecting: isMultiSelecting,
                                selectedTranscriptions: $selectedTranscriptions,
                                theme: theme,
                                zoomLevel: zoomLevel,
                                searchText: searchText,
                                onDoubleClick: {
                                    if !isMultiSelecting {
                                        transcriptionForModal = transcription
                                    }
                                }
                            )
                            .onDrag {
                                folderManager.draggedTranscriptionID = transcription.id
                                return NSItemProvider(object: transcription.id.uuidString as NSString)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden) // Clean background
        }
        .background(theme.backgroundColor)
        .onReceive(manager.objectWillChange) { _ in
             // Ensures list updates when new recordings are added
             // refreshID = UUID() // Too aggressive?
        }
        .alert("Nouveau dossier", isPresented: $showingNewFolderAlert) {
            TextField("Nom", text: $newFolderName)
            Button("Créer") {
                if !newFolderName.isEmpty {
                    folderManager.createFolder(name: newFolderName)
                    newFolderName = ""
                    refreshID = UUID()
                }
            }
            Button("Annuler", role: .cancel) {
                newFolderName = ""
            }
        }
        .sheet(item: $transcriptionForModal) { transcription in
            TranscriptionModal(transcription: transcription)
                .environmentObject(manager)
        }
    }
}

struct FolderRowSimple: View {
    @ObservedObject var folder: TreeNode
    @ObservedObject var manager: TranscriptionManager
    let folderManager: FolderTreeManager
    @Binding var selectedTranscription: Transcription?
    @Binding var selectedTranscriptions: Set<UUID>
    @Binding var isMultiSelecting: Bool
    @Binding var transcriptionForModal: Transcription?
    let theme: AppTheme
    let zoomLevel: Double
    let searchText: String // Ajout pour filtrer dans les dossiers
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var isTargeted = false
    @State private var updateID = UUID()

    var transcriptionsInFolder: [Transcription] {
        let inFolder = manager.transcriptions.filter { folder.contains(transcriptionID: $0.id) }
        if searchText.isEmpty {
            return inFolder
        }
        return inFolder.filter {
            $0.text.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var allTranscriptionIDsInFolder: Set<UUID> {
        Set(transcriptionsInFolder.map { $0.id })
    }
    
    var isFolderFullySelected: Bool {
        !transcriptionsInFolder.isEmpty && allTranscriptionIDsInFolder.isSubset(of: selectedTranscriptions)
    }
    
    func getFolderColor() -> Color {
        switch folder.name.lowercased() {
        case let name where name.contains("inbox"): return theme.folderInboxColor
        case let name where name.contains("travail") || name.contains("work"): return theme.folderWorkColor
        case let name where name.contains("personnel") || name.contains("personal"): return theme.folderPersonalColor
        case let name where name.contains("archive"): return theme.folderArchiveColor
        default:
            let hash = abs(folder.name.hashValue)
            let colors = [theme.folderInboxColor, theme.folderWorkColor, theme.folderPersonalColor, theme.folderArchiveColor]
            return colors[hash % colors.count]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if isMultiSelecting {
                    Image(systemName: isFolderFullySelected ? "checkmark.square.fill" : (selectedTranscriptions.intersection(allTranscriptionIDsInFolder).isEmpty ? "square" : "minus.square"))
                        .font(.system(size: 14 * zoomLevel))
                        .foregroundColor(isFolderFullySelected ? theme.accentColor : theme.secondaryTextColor)
                        .onTapGesture {
                            if isFolderFullySelected {
                                for id in allTranscriptionIDsInFolder { selectedTranscriptions.remove(id) }
                            } else {
                                for id in allTranscriptionIDsInFolder { selectedTranscriptions.insert(id) }
                            }
                        }
                }
                
                Button(action: { folder.isExpanded.toggle() }) {
                    Image(systemName: folder.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11 * zoomLevel))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
                .frame(width: 16 * zoomLevel)
                    
                Image(systemName: folder.isExpanded ? "folder.fill" : "folder")
                    .font(.system(size: 13 * zoomLevel))
                    .foregroundColor(isFolderFullySelected ? Color.orange : (isTargeted ? theme.accentColor : getFolderColor()))
                
                if isRenaming {
                    TextField("Nom", text: $newName, onCommit: {
                        if !newName.isEmpty {
                            folder.name = newName
                            folderManager.renameFolder(folder, newName: newName)
                        }
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 13 * zoomLevel))
                } else {
                    Text(folder.name)
                        .font(.system(size: 13 * zoomLevel))
                        .foregroundColor(manager.selectedFolderForNewRecording?.id == folder.id ? theme.accentColor : theme.textColor)
                        .fontWeight(manager.selectedFolderForNewRecording?.id == folder.id ? .bold : .regular)
                }
                
                Spacer()
                
                if !transcriptionsInFolder.isEmpty || folder.children?.isEmpty == false {
                    Text("\(transcriptionsInFolder.count + (folder.children?.count ?? 0))")
                        .font(.system(size: 10 * zoomLevel))
                        .foregroundColor(theme.secondaryTextColor)
                }
                
                Menu {
                    Button("Renommer") { newName = folder.name; isRenaming = true }
                    Divider()
                    Button("Supprimer", role: .destructive) { folderManager.deleteFolder(folder) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10 * zoomLevel))
                        .foregroundColor(theme.secondaryTextColor)
                        .frame(width: 16 * zoomLevel, height: 16 * zoomLevel)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4 * zoomLevel)
            .padding(.horizontal, 6 * zoomLevel)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isFolderFullySelected ? Color.orange.opacity(0.1) : (manager.selectedFolderForNewRecording?.id == folder.id ? theme.accentColor.opacity(0.1) : (isTargeted ? theme.accentColor.opacity(0.1) : Color.clear)))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.none) {
                    if manager.selectedFolderForNewRecording?.id == folder.id {
                        manager.selectedFolderForNewRecording = nil
                        folderManager.selectedFolder = nil
                    } else {
                        manager.selectedFolderForNewRecording = folder
                        folderManager.selectedFolder = folder
                    }
                    updateID = UUID()
                    manager.objectWillChange.send()
                }
            }
            
            if folder.isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    if let children = folder.children {
                        ForEach(children) { child in
                            FolderRowSimple(
                                folder: child,
                                manager: manager,
                                folderManager: folderManager,
                                selectedTranscription: $selectedTranscription,
                                selectedTranscriptions: $selectedTranscriptions,
                                isMultiSelecting: $isMultiSelecting,
                                transcriptionForModal: $transcriptionForModal,
                                theme: theme,
                                zoomLevel: zoomLevel,
                                searchText: searchText
                            )
                            .padding(.leading, 16 * zoomLevel)
                        }
                    }
                    
                    ForEach(transcriptionsInFolder) { transcription in
                        UnifiedTranscriptionRow(
                            transcription: transcription,
                            isSelected: selectedTranscription?.id == transcription.id,
                            isMultiSelecting: isMultiSelecting,
                            selectedTranscriptions: $selectedTranscriptions,
                            theme: theme,
                            zoomLevel: zoomLevel,
                            searchText: searchText,
                            onDoubleClick: {
                                if !isMultiSelecting {
                                    transcriptionForModal = transcription
                                }
                            }
                        )
                        .padding(.leading, 16 * zoomLevel)
                        .onDrag {
                            folderManager.draggedTranscriptionID = transcription.id
                            return NSItemProvider(object: transcription.id.uuidString as NSString)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    }
                }
            }
        }
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let draggedID = folderManager.draggedTranscriptionID else { return false }
            folderManager.moveTranscription(id: draggedID, to: folder)
            return true
        }
    }
}

struct UnifiedTranscriptionRow: View {
    let transcription: Transcription
    let isSelected: Bool
    let isMultiSelecting: Bool
    @Binding var selectedTranscriptions: Set<UUID>
    let theme: AppTheme
    let zoomLevel: Double
    var searchText: String = "" // Pour le highlight
    var onDoubleClick: (() -> Void)? = nil // Callback pour ouvrir la modale
    @EnvironmentObject var manager: TranscriptionManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isExpanded = false // Accordéon
    @State private var isCopied = false // Feedback copie

    // Couleur de highlight adaptée au thème
    private var highlightColor: Color {
        colorScheme == .dark ? .orange : .yellow
    }

    // Fonction pour créer le texte avec highlight (couleur adaptée au thème)
    private func highlightedText(_ text: String, highlight: String) -> Text {
        guard !highlight.isEmpty else {
            return Text(text)
        }

        let lowercaseText = text.lowercased()
        let lowercaseHighlight = highlight.lowercased()

        var result = Text("")
        var currentIndex = text.startIndex

        while let range = lowercaseText[currentIndex...].range(of: lowercaseHighlight) {
            // Texte avant le match
            let beforeRange = currentIndex..<range.lowerBound
            if !beforeRange.isEmpty {
                result = result + Text(text[beforeRange])
            }

            // Match avec highlight (jaune bold)
            let matchRange = Range(uncheckedBounds: (
                lower: text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound)),
                upper: text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound))
            ))
            result = result + Text(text[matchRange])
                .foregroundColor(highlightColor)
                .bold()

            currentIndex = range.upperBound
        }

        // Texte restant après le dernier match
        if currentIndex < text.endIndex {
            result = result + Text(text[currentIndex...])
        }

        return result
    }

    var body: some View {
        HStack(spacing: 8 * zoomLevel) {
            if isMultiSelecting {
                Image(systemName: selectedTranscriptions.contains(transcription.id) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14 * zoomLevel))
                    .foregroundColor(selectedTranscriptions.contains(transcription.id) ? theme.accentColor : theme.secondaryTextColor)
                    .onTapGesture {
                        if selectedTranscriptions.contains(transcription.id) {
                            selectedTranscriptions.remove(transcription.id)
                        } else {
                            selectedTranscriptions.insert(transcription.id)
                        }
                    }
            }

            // Icon avec indicateur AI modifié (jaune fluo)
            ZStack {
                RoundedRectangle(cornerRadius: 6 * zoomLevel)
                    .fill(transcription.isAIModified ? Color.yellow.opacity(0.3) : theme.accentColor.opacity(0.1))
                    .frame(width: 28 * zoomLevel, height: 28 * zoomLevel)

                Image(systemName: transcription.isAIModified ? "wand.and.stars" : "waveform")
                    .font(.system(size: 14 * zoomLevel))
                    .foregroundColor(transcription.isAIModified ? .orange : theme.accentColor)
            }
            .overlay(
                // Badge jaune fluo si modifié par IA
                transcription.isAIModified ?
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8 * zoomLevel, height: 8 * zoomLevel)
                        .offset(x: 10 * zoomLevel, y: -10 * zoomLevel)
                : nil
            )

            // Text Content
            VStack(alignment: .leading, spacing: 2 * zoomLevel) {
                highlightedText(transcription.text, highlight: searchText)
                    .font(.system(size: 13 * zoomLevel, weight: .medium))
                    .foregroundColor(isSelected ? .white : theme.textColor)
                    .lineLimit(isExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 6 * zoomLevel) {
                    Text(transcription.formattedDate)
                    Spacer()
                    Text(transcription.formattedDuration)
                }
                .font(.system(size: 11 * zoomLevel))
                .foregroundColor(isSelected ? .white.opacity(0.8) : theme.secondaryTextColor)
            }
            
            // Favori toggle (always visible if favorite, or on hover)
            if isHovered || isSelected || manager.isFavorite(transcription) {
                Button(action: {
                    manager.toggleFavorite(transcription)
                }) {
                    Image(systemName: manager.isFavorite(transcription) ? "star.fill" : "star")
                        .font(.system(size: 12 * zoomLevel))
                        .foregroundColor(manager.isFavorite(transcription) ? .orange : (isSelected ? .white.opacity(0.6) : theme.secondaryTextColor.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .help(manager.isFavorite(transcription) ? "Retirer des favoris" : "Ajouter aux favoris")
            }

            // Delete button - TOUJOURS visible
            Button(action: {
                manager.deleteTranscription(transcription)
            }) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 11 * zoomLevel))
                    .foregroundColor(.red.opacity(0.6))
                    .padding(4)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Supprimer")

            if isHovered || isSelected {
                Button(action: {
                    manager.copyToClipboard(transcription.text, showSuccess: true)
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
                        .font(.system(size: 12 * zoomLevel))
                        .foregroundColor(isCopied ? .green : (isSelected ? .white : theme.secondaryTextColor))
                }
                .buttonStyle(.plain)
                .help("Copier")
            }
        }
        .padding(.horizontal, 10 * zoomLevel)
        .padding(.vertical, 6 * zoomLevel)
        .background(isSelected ? theme.accentColor : (transcription.isAIModified ? Color.yellow.opacity(0.08) : theme.secondaryBackgroundColor))
        .cornerRadius(8 * zoomLevel)
        .overlay(
            RoundedRectangle(cornerRadius: 8 * zoomLevel)
                .stroke(theme.accentColor.opacity(isSelected ? 0.0 : 0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            // Double-clic = ouvrir la modale (sauf en mode multi-sélection)
            if !isMultiSelecting {
                onDoubleClick?()
            }
        }
        .onTapGesture(count: 1) {
            if isMultiSelecting {
                // Mode multi-sélection : toggle la sélection
                if selectedTranscriptions.contains(transcription.id) {
                    selectedTranscriptions.remove(transcription.id)
                } else {
                    selectedTranscriptions.insert(transcription.id)
                }
            } else {
                // Simple clic = copier le texte
                manager.copyToClipboard(transcription.text, showSuccess: true)
                withAnimation {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isCopied = false
                    }
                }
            }
        }
    }
}