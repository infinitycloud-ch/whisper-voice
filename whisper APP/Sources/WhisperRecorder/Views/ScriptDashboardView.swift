import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Row View for List Layout

struct ScriptRowView: View {
    let tile: ScriptTile
    let theme: AppTheme
    let zoomLevel: Double
    let onExecute: () -> Void
    var iconOverride: String? = nil
    var colorOverride: Color? = nil
    
    private var finalColor: Color {
        if tile.isFavorite {
            return .yellow
        }
        return colorOverride ?? tile.colorValue
    }
    
    private var finalIconName: String {
        return iconOverride ?? tile.iconName
    }
    
    var body: some View {
        HStack(spacing: 12 * zoomLevel) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8 * zoomLevel)
                    .fill(finalColor.opacity(0.1))
                    .frame(width: 28 * zoomLevel, height: 28 * zoomLevel)
                
                Image(systemName: finalIconName)
                    .font(.system(size: 14 * zoomLevel))
                    .foregroundColor(finalColor)
            }
            
            // Text Content - Combined into single Text for strict single-line layout
            Group {
                if !tile.description.isEmpty {
                    (Text(tile.name)
                        .font(.system(size: 13 * zoomLevel, weight: .medium))
                        .foregroundColor(theme.textColor)
                     + Text("  ")
                     + Text(tile.description)
                        .font(.system(size: 12 * zoomLevel))
                        .foregroundColor(theme.secondaryTextColor))
                } else {
                    Text(tile.name)
                        .font(.system(size: 13 * zoomLevel, weight: .medium))
                        .foregroundColor(theme.textColor)
                }
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Execute Button / Hover Action
            Image(systemName: "play.circle")
                .font(.system(size: 14 * zoomLevel))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
        }
        .padding(.horizontal, 10 * zoomLevel)
        .padding(.vertical, 4 * zoomLevel)
        .background(theme.secondaryBackgroundColor)
        .cornerRadius(8 * zoomLevel)
        .overlay(
            RoundedRectangle(cornerRadius: 8 * zoomLevel)
                .stroke(theme.accentColor.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onExecute)
    }
}

struct RowItemView: View {
    let item: TileItem
    let theme: AppTheme
    let zoomLevel: Double
    let scriptManager: ScriptManager
    let onTerminalAction: () -> Void
    let onTerminalInDirectory: (String) -> Void
    let onEdit: (ScriptTile) -> Void
    var iconOverride: String? = nil
    var colorOverride: Color? = nil
    
    @State private var isHovering = false
    
    var body: some View {
        Group {
            switch item {
            case .tile(let tile):
                ScriptRowView(
                    tile: tile,
                    theme: theme,
                    zoomLevel: zoomLevel,
                    onExecute: {
                        executeTile(tile)
                    },
                    iconOverride: iconOverride,
                    colorOverride: colorOverride
                )
                .contextMenu {
                    Button(tile.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris") {
                        var mutableTile = tile
                        mutableTile.isFavorite.toggle()
                        scriptManager.updateScriptTile(mutableTile)
                    }
                    Divider()
                    Button("Modifier") { onEdit(tile) }
                    Button("Dupliquer") { duplicateTile(tile) }
                    Divider()
                    Button("Supprimer", role: .destructive) {
                        scriptManager.deleteScriptTile(tile)
                    }
                }
                
            case .group(let group):
                // Groups are rendered as sections in the main list, but if we encounter one here
                // (e.g. inside another group? though strictly flat mostly), we can render it.
                // However, the main view handles groups as expandable sections.
                // If a group is passed here, we fallback to a simple header.
                Text(group.name)
                    .font(.system(size: 13 * zoomLevel))
            }
        }
        .draggable(item) {
            let name: String = {
                switch item {
                case .tile(let tile): return tile.name
                case .group(let group): return group.name
                }
            }()
             Text(name)
                .padding()
                .background(theme.secondaryBackgroundColor)
        }
    }
    
    private func executeTile(_ tile: ScriptTile) {
        if tile.type == .folderBookmark {
            scriptManager.executeScript(tile)
        } else if tile.name == "Terminal" {
            onTerminalAction()
        } else if tile.name.hasPrefix("Terminal - ") {
            onTerminalInDirectory(tile.projectPath)
        } else {
            scriptManager.executeScript(tile)
        }
    }
    
    private func duplicateTile(_ tile: ScriptTile) {
        let newTile = ScriptTile(
            name: "\(tile.name) Copie",
            description: tile.description,
            type: tile.type,
            iconName: tile.iconName,
            color: tile.colorValue,
            projectPath: tile.projectPath,
            commandToRun: tile.commandToRun,
            workingDirectory: tile.workingDirectory,
            environment: tile.environment,
            isEnabled: tile.isEnabled,
            isFavorite: false
        )
        scriptManager.addScriptTile(newTile)
    }
}

// MARK: - Main View

struct ScriptDashboardView: View {
    @ObservedObject private var scriptManager = ScriptManager.shared
    @AppStorage("app_theme") private var currentTheme: String = AppTheme.cyberpunk.rawValue
    @AppStorage("dashboard_zoom_level") private var zoomLevel: Double = 1.0
    @State private var showSettingsMenu = false
    @State private var scriptToEdit: ScriptTile? = nil
    @State private var isOutputPanelVisible = false
    @EnvironmentObject var manager: TranscriptionManager
    
    // Expandable states
    @State private var isBookmarksExpanded = true
    @State private var isAppsExpanded = true
    @State private var isFoldersExpanded = true
    @State private var isTerminalExpanded = true

    var theme: AppTheme {
        AppTheme(rawValue: currentTheme) ?? .dark
    }

    // MARK: - Categorized Items

    private var favoriteItems: [ScriptTile] {
        scriptManager.tileItems.compactMap { item -> ScriptTile? in
            guard case .tile(let tile) = item, tile.isFavorite else { return nil }
            return tile
        }
    }

    private var bookmarkItems: [TileItem] {
        scriptManager.tileItems.filter { item in
            guard case .tile(let tile) = item else { return false }
            return tile.type == .webUrl
        }
    }

    private var applicationItems: [TileItem] {
        scriptManager.tileItems.filter { item in
            switch item {
            case .tile(let tile):
                let isBookmark = tile.type == .webUrl
                let isTerminalFolder = tile.type == .shellScript && tile.name.hasPrefix("Terminal")
                let isFolderBookmark = tile.type == .folderBookmark
                return !isBookmark && !isTerminalFolder && !isFolderBookmark
            case .group:
                return true
            }
        }
    }

    private var terminalFolderItems: [TileItem] {
        scriptManager.tileItems.filter { item in
            guard case .tile(let tile) = item else { return false }
            return tile.type == .shellScript && tile.name.hasPrefix("Terminal")
        }
    }

    private var folderBookmarkItems: [TileItem] {
        scriptManager.tileItems.filter { item in
            guard case .tile(let tile) = item else { return false }
            return tile.type == .folderBookmark
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header Compact
            headerView
            
            // Favorites Bar (Horizontal Scroll)
            if !favoriteItems.isEmpty {
                favoritesBar
                    .padding(.bottom, 8)
            }

            // Main Content - List
            ScrollView {
                VStack(spacing: 16) {
                    // Signets
                    if !bookmarkItems.isEmpty {
                        expandableSection(
                            title: "Signets Web",
                            icon: "globe",
                            isExpanded: $isBookmarksExpanded,
                            items: bookmarkItems
                        )
                    }
                    
                    // Applications & Scripts
                    if !applicationItems.isEmpty {
                        expandableSection(
                            title: "Applications & Scripts",
                            icon: "hammer.fill",
                            isExpanded: $isAppsExpanded,
                            items: applicationItems
                        )
                    }
                    
                    // Dossiers
                    if !folderBookmarkItems.isEmpty {
                        expandableSection(
                            title: "Dossiers",
                            icon: "folder.fill",
                            isExpanded: $isFoldersExpanded,
                            items: folderBookmarkItems
                        )
                    }
                    
                    // Terminaux
                    if !terminalFolderItems.isEmpty {
                        expandableSection(
                            title: "Terminaux",
                            icon: "terminal.fill",
                            isExpanded: $isTerminalExpanded,
                            items: terminalFolderItems,
                            colorOverride: .orange
                        )
                    }
                    
                    // Add Button at bottom if empty
                    if scriptManager.tileItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 40))
                                .foregroundColor(theme.secondaryTextColor.opacity(0.3))
                            Text("Ajoutez votre premier script ou dossier")
                                .font(.caption)
                                .foregroundColor(theme.secondaryTextColor)
                            Button("Ajouter un fichier...") {
                                selectProjectFile()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 40)
                    }
                }
                .padding(12)
            }

            if isOutputPanelVisible {
                outputPanelView()
                    .transition(.move(edge: .bottom))
            }
        }
        .background(theme.backgroundColor)
        .sheet(item: $scriptToEdit) { script in
            AddEditScriptView(scriptManager: scriptManager, theme: theme, editingScript: script)
        }
        .onChange(of: scriptManager.isExecuting) { isExecuting in
            if !isExecuting && !scriptManager.executionOutput.isEmpty {
                withAnimation {
                    isOutputPanelVisible = true
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("Bibliothèque")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textColor)
            
            Spacer()
            
            // Slider de Zoom
            HStack(spacing: 4) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(theme.secondaryTextColor)
                
                Slider(value: $zoomLevel, in: 0.8...2.0)
                    .frame(width: 80)
                    .controlSize(.mini)
                
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(theme.secondaryTextColor)
            }
            .padding(.trailing, 8)
            
            Menu {
                Button(action: selectProjectFile) {
                    Label("Ajouter Fichier/Projet...", systemImage: "doc.badge.plus")
                }
                Button(action: createTerminalTileWithFolderSelector) {
                    Label("Raccourci Terminal...", systemImage: "terminal")
                }
                Button(action: createFolderBookmarkTile) {
                    Label("Raccourci Dossier...", systemImage: "folder.badge.plus")
                }
                Button(action: createUrlTile) {
                    Label("Signet Web...", systemImage: "globe")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(theme.accentColor)
            }
            .menuStyle(.borderlessButton)
            .help("Ajouter un élément")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(theme.secondaryBackgroundColor.opacity(0.5))
    }
    
    private var favoritesBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Favoris")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(theme.secondaryTextColor)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(favoriteItems) { tile in
                        VStack {
                            Image(systemName: tile.iconName)
                                .font(.system(size: 16))
                                .foregroundColor(tile.colorValue)
                                .frame(width: 32, height: 32)
                                .background(tile.colorValue.opacity(0.1))
                                .cornerRadius(8)
                            
                            Text(tile.name)
                                .font(.system(size: 9))
                                .foregroundColor(theme.textColor)
                                .lineLimit(1)
                                .frame(width: 50)
                        }
                        .padding(6)
                        .background(theme.secondaryBackgroundColor)
                        .cornerRadius(8)
                        .onTapGesture {
                            executeTile(tile)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func expandableSection(title: String, icon: String, isExpanded: Binding<Bool>, items: [TileItem], colorOverride: Color? = nil) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(spacing: 6) {
                ForEach(items) { item in
                    RowItemView(
                        item: item,
                        theme: theme,
                        zoomLevel: zoomLevel,
                        scriptManager: scriptManager,
                        onTerminalAction: openTerminalWithFolderSelector,
                        onTerminalInDirectory: openTerminalInDirectory,
                        onEdit: { tile in scriptToEdit = tile },
                        colorOverride: colorOverride
                    )
                }
            }
            .padding(.top, 4)
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(theme.accentColor)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textColor)
                Spacer()
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.secondaryBackgroundColor)
                    .cornerRadius(4)
            }
        }
        .accentColor(theme.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func outputPanelView() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sortie")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(theme.secondaryTextColor)
                Spacer()
                Button(action: { withAnimation { isOutputPanelVisible = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondaryTextColor)
                }.buttonStyle(.plain)
            }
            .padding(8)
            .background(theme.secondaryBackgroundColor)
            
            ScrollView {
                Text(scriptManager.executionOutput)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(theme.textColor)
                    .padding(8)
            }
            .frame(height: 150)
        }
        .background(theme.backgroundColor)
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding()
    }
    
    // MARK: - Actions (Duplicated from previous implementation for standalone compatibility) 
    
    private func executeTile(_ tile: ScriptTile) {
        if tile.type == .folderBookmark {
            scriptManager.executeScript(tile)
        } else if tile.name == "Terminal" {
            openTerminalWithFolderSelector()
        } else if tile.name.hasPrefix("Terminal - ") {
            openTerminalInDirectory(tile.projectPath)
        } else {
            scriptManager.executeScript(tile)
        }
    }

    private func selectProjectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Sélectionnez un projet ou un script"

        if panel.runModal() == .OK, let url = panel.url {
            createTileFromPath(url.path)
        }
    }

    private func openTerminalWithFolderSelector() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Sélectionnez un dossier pour ouvrir le Terminal"

        if panel.runModal() == .OK, let url = panel.url {
            openTerminalInDirectory(url.path)
        }
    }

    private func openTerminalInDirectory(_ path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", path]
        try? process.run()
    }

    private func createTileFromPath(_ path: String) {
        let url = URL(fileURLWithPath: path)
        var name: String
        var description: String = "Créé automatiquement"
        let scriptType: ScriptType
        let command: String
        let projectPath: String
        var workingDir: String?

        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            name = URL(string: path)?.host ?? "URL"
            scriptType = .webUrl
            command = path
            projectPath = ""
            description = "URL: \(path)"
        } else {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                name = url.lastPathComponent
                projectPath = path
                workingDir = path
                if FileManager.default.fileExists(atPath: "\(path)/Package.swift") {
                    scriptType = .swiftPackage
                    command = "run"
                } else if name.hasSuffix(".xcodeproj") || name.hasSuffix(".xcworkspace") {
                    scriptType = .xcodeProject
                    command = "open \"\(path)\""
                } else {
                    scriptType = .folderBookmark
                    command = "open \"\(path)\""
                }
            } else {
                let filename = url.lastPathComponent
                workingDir = url.deletingLastPathComponent().path
                let parentDirName = url.deletingLastPathComponent().lastPathComponent
                
                if filename.hasSuffix(".sh") || filename.hasSuffix(".zsh") || filename.hasSuffix(".bash") || filename.hasSuffix(".command") {
                    scriptType = .shellScript
                    projectPath = path
                    command = "execute_shell_script_in_terminal"
                    // Nom du dossier parent au lieu du nom du fichier pour plus de contexte
                    name = parentDirName
                    description = filename
                } else if filename.hasSuffix(".py") {
                    projectPath = url.deletingLastPathComponent().path
                    scriptType = .pythonScript
                    command = "python3 \"\(path)\""
                    // Nom du dossier parent au lieu du nom du fichier
                    name = parentDirName
                    description = filename
                } else {
                    projectPath = url.deletingLastPathComponent().path
                    scriptType = .custom
                    command = "open \"\(path)\""
                    name = filename
                }
            }
        }

        let newTile = ScriptTile(name: name, description: description, type: scriptType, projectPath: projectPath, commandToRun: command, workingDirectory: workingDir)
        scriptManager.addScriptTile(newTile)
    }

    private func createFolderBookmarkTile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            let newTile = ScriptTile(
                name: url.lastPathComponent,
                description: "Raccourci vers \(url.path)",
                type: .folderBookmark,
                projectPath: url.path,
                commandToRun: "open folder"
            )
            scriptManager.addScriptTile(newTile)
        }
    }

    private func createTerminalTileWithFolderSelector() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            let newTile = ScriptTile(
                name: "Terminal - \(url.lastPathComponent)",
                description: "Terminal dans \(url.path)",
                type: .shellScript,
                projectPath: url.path,
                commandToRun: "open Terminal in folder"
            )
            scriptManager.addScriptTile(newTile)
        }
    }

    private func createUrlTile() {
        let alert = NSAlert()
        alert.messageText = "Nouveau Signet"
        alert.informativeText = "Entrez l'URL à sauvegarder:"
        alert.addButton(withTitle: "Créer")
        alert.addButton(withTitle: "Annuler")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.placeholderString = "https://example.com"
        alert.accessoryView = inputField

        if alert.runModal() == .alertFirstButtonReturn {
            let urlString = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !urlString.isEmpty {
                let finalUrl = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"
                let newTile = ScriptTile(name: URL(string: finalUrl)?.host ?? "URL", description: "URL: \(finalUrl)", type: .webUrl, projectPath: "", commandToRun: finalUrl)
                scriptManager.addScriptTile(newTile)
            }
        }
    }
}
