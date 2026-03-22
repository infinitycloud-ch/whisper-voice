import SwiftUI

struct CommandLauncherView: View {
    @StateObject private var launcher = CommandLauncherService.shared
    @AppStorage("app_theme") private var currentTheme: String = AppTheme.cyberpunk.rawValue
    @AppStorage("global_zoom_level") private var zoomLevel: Double = 1.0

    var theme: AppTheme {
        AppTheme(rawValue: currentTheme) ?? .dark
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Search bar
            searchBar

            // Content
            if launcher.isScanning {
                scanningView
            } else if launcher.filteredFolders.isEmpty {
                emptyView
            } else {
                foldersList
            }
        }
        .background(theme.backgroundColor)
    }

    // MARK: - Header

    private var allExpanded: Bool {
        launcher.folders.allSatisfy { $0.isExpanded }
    }

    private var header: some View {
        HStack(spacing: 8) {
            // Chevron global pour tout plier/déplier
            Button(action: { launcher.toggleAllExpanded() }) {
                Image(systemName: allExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.secondaryTextColor)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .help(allExpanded ? "Tout replier" : "Tout déplier")

            Image(systemName: "terminal.fill")
                .font(.system(size: 14))
                .foregroundColor(theme.accentColor)

            Text("Command Launcher")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textColor)

            Spacer()

            // Stats
            Text("\(launcher.totalCommands) commands")
                .font(.system(size: 11))
                .foregroundColor(theme.secondaryTextColor)

            // Refresh button
            Button(action: { launcher.scan() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryTextColor)
            }
            .buttonStyle(.plain)
            .help("Rescanner les dossiers")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.secondaryBackgroundColor.opacity(0.5))
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryTextColor)

            TextField("Rechercher...", text: $launcher.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(theme.textColor)

            if !launcher.searchText.isEmpty {
                Button(action: { launcher.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.secondaryBackgroundColor.opacity(0.3))
        .cornerRadius(6)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Folders List

    @State private var favoriteCommandsExpanded = true

    private var foldersList: some View {
        ScrollView {
            LazyVStack(spacing: 2, pinnedViews: [.sectionHeaders]) {
                // Commandes favorites (tout en haut)
                if !launcher.filteredFavoriteCommands.isEmpty {
                    Section {
                        if favoriteCommandsExpanded {
                            ForEach(launcher.filteredFavoriteCommands) { command in
                                CommandRow(command: command, theme: theme, zoomLevel: zoomLevel, isFavorite: true) {
                                    launcher.execute(command)
                                }
                            }
                        }
                    } header: {
                        FavoriteCommandsHeader(
                            count: launcher.filteredFavoriteCommands.count,
                            isExpanded: favoriteCommandsExpanded,
                            theme: theme,
                            zoomLevel: zoomLevel
                        ) {
                            favoriteCommandsExpanded.toggle()
                        }
                    }
                }

                // Dossiers favoris (pinned)
                ForEach(launcher.filteredFavoriteFolders) { folder in
                    Section {
                        if folder.isExpanded {
                            ForEach(folder.commands) { command in
                                CommandRow(command: command, theme: theme, zoomLevel: zoomLevel, isFavorite: launcher.isFavoriteCommand(command)) {
                                    launcher.execute(command)
                                }
                            }
                        }
                    } header: {
                        FolderHeader(folder: folder, theme: theme, zoomLevel: zoomLevel, isFavorite: true) {
                            launcher.toggleExpanded(folder)
                        }
                    }
                }

                // Dossiers normaux
                ForEach(launcher.filteredNonFavoriteFolders) { folder in
                    Section {
                        if folder.isExpanded {
                            ForEach(folder.commands) { command in
                                CommandRow(command: command, theme: theme, zoomLevel: zoomLevel, isFavorite: launcher.isFavoriteCommand(command)) {
                                    launcher.execute(command)
                                }
                            }
                        }
                    } header: {
                        FolderHeader(folder: folder, theme: theme, zoomLevel: zoomLevel, isFavorite: false) {
                            launcher.toggleExpanded(folder)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty / Scanning Views

    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Scan en cours...")
                .font(.caption)
                .foregroundColor(theme.secondaryTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))

            if launcher.searchText.isEmpty {
                Text("Aucun fichier .command trouvé")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)

                Button("Rescanner") {
                    launcher.scan()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Aucun résultat pour \"\(launcher.searchText)\"")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Favorite Commands Header

struct FavoriteCommandsHeader: View {
    let count: Int
    let isExpanded: Bool
    let theme: AppTheme
    let zoomLevel: Double
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6 * zoomLevel) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10 * zoomLevel, weight: .semibold))
                    .foregroundColor(theme.secondaryTextColor)
                    .frame(width: 12 * zoomLevel)

                Image(systemName: "star.fill")
                    .font(.system(size: 12 * zoomLevel))
                    .foregroundColor(.orange)

                Text("Commandes favorites")
                    .font(.system(size: 12 * zoomLevel, weight: .semibold))
                    .foregroundColor(theme.textColor)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10 * zoomLevel, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6 * zoomLevel)
                    .padding(.vertical, 2 * zoomLevel)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4 * zoomLevel)
            }
            .padding(.horizontal, 8 * zoomLevel)
            .padding(.vertical, 6 * zoomLevel)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(6 * zoomLevel)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Folder Header

struct FolderHeader: View {
    let folder: CommandFolder
    let theme: AppTheme
    let zoomLevel: Double
    var isFavorite: Bool = false
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6 * zoomLevel) {
            Button(action: onToggle) {
                HStack(spacing: 6 * zoomLevel) {
                    Image(systemName: folder.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10 * zoomLevel, weight: .semibold))
                        .foregroundColor(theme.secondaryTextColor)
                        .frame(width: 12 * zoomLevel)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 12 * zoomLevel))
                        .foregroundColor(isFavorite ? .yellow : theme.accentColor)

                    Text(folder.name)
                        .font(.system(size: 12 * zoomLevel, weight: .medium))
                        .foregroundColor(theme.textColor)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Étoile favori (visible au hover ou si favori)
            if isHovering || isFavorite {
                Button(action: {
                    CommandLauncherService.shared.toggleFavoriteFolder(folder)
                }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 10 * zoomLevel))
                        .foregroundColor(isFavorite ? .yellow : theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
                .help(isFavorite ? "Retirer des favoris" : "Épingler en haut")
            }

            Text("\(folder.count)")
                .font(.system(size: 10 * zoomLevel, weight: .medium))
                .foregroundColor(isFavorite ? .yellow : theme.secondaryTextColor)
                .padding(.horizontal, 6 * zoomLevel)
                .padding(.vertical, 2 * zoomLevel)
                .background(isFavorite ? Color.yellow.opacity(0.2) : theme.secondaryBackgroundColor)
                .cornerRadius(4 * zoomLevel)
        }
        .padding(.horizontal, 8 * zoomLevel)
        .padding(.vertical, 6 * zoomLevel)
        .background(isFavorite ? Color.yellow.opacity(0.1) : theme.secondaryBackgroundColor.opacity(0.7))
        .cornerRadius(6 * zoomLevel)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Command Row

struct CommandRow: View {
    let command: CommandFile
    let theme: AppTheme
    let zoomLevel: Double
    var isFavorite: Bool = false
    let onExecute: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onExecute) {
            HStack(spacing: 8 * zoomLevel) {
                // Star button pour favoris (visible au hover ou si favori)
                if isHovering || isFavorite {
                    Button(action: {
                        CommandLauncherService.shared.toggleFavoriteCommand(command)
                    }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 10 * zoomLevel))
                            .foregroundColor(isFavorite ? .orange : theme.secondaryTextColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
                } else {
                    Color.clear.frame(width: 10 * zoomLevel)
                }

                Image(systemName: "terminal")
                    .font(.system(size: 11 * zoomLevel))
                    .foregroundColor(isFavorite ? .orange : theme.accentColor.opacity(0.8))

                Text(command.displayName)
                    .font(.system(size: 12 * zoomLevel))
                    .foregroundColor(theme.textColor)
                    .lineLimit(1)

                Spacer()

                if isHovering {
                    HStack(spacing: 4 * zoomLevel) {
                        Button(action: {
                            CommandLauncherService.shared.revealInFinder(command)
                        }) {
                            Image(systemName: "folder")
                                .font(.system(size: 10 * zoomLevel))
                                .foregroundColor(theme.secondaryTextColor)
                        }
                        .buttonStyle(.plain)
                        .help("Révéler dans Finder")

                        Image(systemName: "play.fill")
                            .font(.system(size: 10 * zoomLevel))
                            .foregroundColor(theme.accentColor)
                    }
                }
            }
            .padding(.horizontal, 8 * zoomLevel)
            .padding(.vertical, 5 * zoomLevel)
            .padding(.leading, 12 * zoomLevel)
            .background(isHovering ? theme.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(4 * zoomLevel)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris") {
                CommandLauncherService.shared.toggleFavoriteCommand(command)
            }
            Divider()
            Button("Exécuter") {
                onExecute()
            }
            Button("Révéler dans Finder") {
                CommandLauncherService.shared.revealInFinder(command)
            }
            Divider()
            Button("Copier le chemin") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command.path, forType: .string)
            }
        }
    }
}

#Preview {
    CommandLauncherView()
        .frame(width: 400, height: 500)
}
