import Foundation
import SwiftUI

// MARK: - Models

struct CommandFolder: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    var commands: [CommandFile]
    var isExpanded: Bool = true

    var count: Int { commands.count }
}

struct CommandFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let folderName: String

    var displayName: String {
        name.replacingOccurrences(of: ".command", with: "")
    }
}

// MARK: - Service

class CommandLauncherService: ObservableObject {
    static let shared = CommandLauncherService()

    @Published var folders: [CommandFolder] = []
    @Published var isScanning = false
    @Published var lastScanDate: Date?
    @Published var searchText: String = ""
    @Published var favoriteFolderPaths: Set<String> = []
    @Published var favoriteCommandPaths: Set<String> = []

    // Dossiers à scanner (configurable)
    @AppStorage("command_scan_paths") private var scanPathsData: Data = Data()
    @AppStorage("command_folder_favorites") private var folderFavoritesData: Data = Data()
    @AppStorage("command_favorites") private var commandFavoritesData: Data = Data()

    var scanPaths: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: scanPathsData)) ?? defaultScanPaths
        }
        set {
            scanPathsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    private let defaultScanPaths: [String] = [
        NSHomeDirectory(),
        "~/whisper",
        "~/nestor",
        "~/panda",
        "~/Documents",
        "~/Developer"
    ]

    var favoriteFolders: [CommandFolder] {
        folders.filter { favoriteFolderPaths.contains($0.path) }
    }

    var nonFavoriteFolders: [CommandFolder] {
        folders.filter { !favoriteFolderPaths.contains($0.path) }
    }

    var favoriteCommands: [CommandFile] {
        folders.flatMap { $0.commands }.filter { favoriteCommandPaths.contains($0.path) }
    }

    var filteredFavoriteCommands: [CommandFile] {
        if searchText.isEmpty {
            return favoriteCommands
        }
        return favoriteCommands.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredFavoriteFolders: [CommandFolder] {
        filterFolders(favoriteFolders)
    }

    var filteredNonFavoriteFolders: [CommandFolder] {
        filterFolders(nonFavoriteFolders)
    }

    private func filterFolders(_ folders: [CommandFolder]) -> [CommandFolder] {
        if searchText.isEmpty {
            return folders
        }

        return folders.compactMap { folder in
            let filteredCommands = folder.commands.filter { command in
                command.displayName.localizedCaseInsensitiveContains(searchText) ||
                command.folderName.localizedCaseInsensitiveContains(searchText)
            }

            if filteredCommands.isEmpty {
                return nil
            }

            var filteredFolder = folder
            filteredFolder.commands = filteredCommands
            return filteredFolder
        }
    }

    var filteredFolders: [CommandFolder] {
        filterFolders(folders)
    }

    var totalCommands: Int {
        folders.reduce(0) { $0 + $1.count }
    }

    private init() {
        loadFavorites()
        scan()
    }

    // MARK: - Favorites (Folders)

    func isFavoriteFolder(_ folder: CommandFolder) -> Bool {
        favoriteFolderPaths.contains(folder.path)
    }

    func toggleFavoriteFolder(_ folder: CommandFolder) {
        if favoriteFolderPaths.contains(folder.path) {
            favoriteFolderPaths.remove(folder.path)
        } else {
            favoriteFolderPaths.insert(folder.path)
        }
        saveFavorites()
    }

    // MARK: - Favorites (Commands)

    func isFavoriteCommand(_ command: CommandFile) -> Bool {
        favoriteCommandPaths.contains(command.path)
    }

    func toggleFavoriteCommand(_ command: CommandFile) {
        if favoriteCommandPaths.contains(command.path) {
            favoriteCommandPaths.remove(command.path)
        } else {
            favoriteCommandPaths.insert(command.path)
        }
        saveFavorites()
    }

    // MARK: - Persistence

    private func loadFavorites() {
        if let paths = try? JSONDecoder().decode(Set<String>.self, from: folderFavoritesData) {
            favoriteFolderPaths = paths
        }
        if let paths = try? JSONDecoder().decode(Set<String>.self, from: commandFavoritesData) {
            favoriteCommandPaths = paths
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteFolderPaths) {
            folderFavoritesData = data
        }
        if let data = try? JSONEncoder().encode(favoriteCommandPaths) {
            commandFavoritesData = data
        }
    }

    // MARK: - Scanning

    func scan() {
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var foundFolders: [String: [CommandFile]] = [:]
            let fileManager = FileManager.default

            for basePath in self.scanPaths {
                self.scanDirectory(basePath, fileManager: fileManager, foundFolders: &foundFolders, maxDepth: 4)
            }

            // Convertir en CommandFolder et trier
            let sortedFolders = foundFolders
                .filter { !$0.value.isEmpty }
                .map { (path, commands) -> CommandFolder in
                    let folderName = (path as NSString).lastPathComponent
                    return CommandFolder(
                        name: folderName,
                        path: path,
                        commands: commands.sorted { $0.displayName < $1.displayName }
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async {
                self.folders = sortedFolders
                self.isScanning = false
                self.lastScanDate = Date()
                print("CommandLauncher: Found \(self.totalCommands) .command files in \(sortedFolders.count) folders")
            }
        }
    }

    private func scanDirectory(_ path: String, fileManager: FileManager, foundFolders: inout [String: [CommandFile]], maxDepth: Int, currentDepth: Int = 0) {
        guard currentDepth < maxDepth else { return }
        guard fileManager.fileExists(atPath: path) else { return }

        // Ignorer certains dossiers
        let ignoredNames = [".git", ".build", "node_modules", ".Trash", "Library", "Applications", ".cache"]
        let folderName = (path as NSString).lastPathComponent
        if ignoredNames.contains(folderName) || folderName.hasPrefix(".") {
            return
        }

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)

            for item in contents {
                let itemPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false

                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        // Récursion dans sous-dossiers
                        scanDirectory(itemPath, fileManager: fileManager, foundFolders: &foundFolders, maxDepth: maxDepth, currentDepth: currentDepth + 1)
                    } else if item.hasSuffix(".command") {
                        // Trouvé un .command
                        let command = CommandFile(
                            name: item,
                            path: itemPath,
                            folderName: folderName
                        )

                        if foundFolders[path] == nil {
                            foundFolders[path] = []
                        }
                        foundFolders[path]?.append(command)
                    }
                }
            }
        } catch {
            // Ignore les erreurs de permission
        }
    }

    // MARK: - Execution

    func execute(_ command: CommandFile) {
        let url = URL(fileURLWithPath: command.path)
        NSWorkspace.shared.open(url)
        print("CommandLauncher: Executing \(command.name)")
    }

    func revealInFinder(_ command: CommandFile) {
        let url = URL(fileURLWithPath: command.path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Folder Management

    func toggleExpanded(_ folder: CommandFolder) {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index].isExpanded.toggle()
        }
    }

    func toggleAllExpanded() {
        let allExpanded = folders.allSatisfy { $0.isExpanded }
        for index in folders.indices {
            folders[index].isExpanded = !allExpanded
        }
    }

    func expandAll() {
        for index in folders.indices {
            folders[index].isExpanded = true
        }
    }

    func collapseAll() {
        for index in folders.indices {
            folders[index].isExpanded = false
        }
    }

    func addScanPath(_ path: String) {
        var paths = scanPaths
        if !paths.contains(path) {
            paths.append(path)
            scanPaths = paths
            scan()
        }
    }

    func removeScanPath(_ path: String) {
        var paths = scanPaths
        paths.removeAll { $0 == path }
        scanPaths = paths
        scan()
    }
}
