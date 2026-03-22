import Foundation
import SwiftUI

class ScriptManager: ObservableObject {
    static let shared = ScriptManager()

    @Published var scriptTiles: [ScriptTile] = []
    @Published var tileItems: [TileItem] = []
    @Published var isExecuting: Bool = false
    @Published var executionOutput: String = ""
    @Published var lastExecutedScript: ScriptTile?

    private let userDefaults = UserDefaults.standard
    private let scriptTilesKey = "script_tiles"
    // private let tileItemsKey = "tile_items" // No longer persisting tileItems directly

    private init() {
        loadScriptTiles()
        migrateExistingTiles() // One-time migration for better naming
        // Rebuild tileItems from the source of truth
        if tileItems.isEmpty { // Only if it's truly empty
            tileItems = scriptTiles.map { .tile($0) }
        }
        createDefaultTiles()
    }

    private func migrateExistingTiles() {
        // Check if migration already ran (using a flag in UserDefaults)
        let migrationKey = "migration_v1_renaming_done"
        guard !userDefaults.bool(forKey: migrationKey) else { return }
        
        print("🔄 Migrating existing tiles to new naming convention...")
        
        for index in 0..<scriptTiles.count {
            var tile = scriptTiles[index]
            // Only migrate file-based scripts that look like they haven't been customized manually
            // (This is a best-guess heuristic: if name has an extension, it's likely the original filename)
            if (tile.type == .shellScript || tile.type == .pythonScript) && tile.name.contains(".") {
                let url = URL(fileURLWithPath: tile.projectPath.isEmpty ? tile.commandToRun : tile.projectPath)
                // If it's a file path (not a command string)
                if url.path.hasPrefix("/") {
                     let parentDirName = url.deletingLastPathComponent().lastPathComponent
                     let filename = url.lastPathComponent
                     
                     // Update
                     tile.name = parentDirName
                     tile.description = filename
                     scriptTiles[index] = tile
                     print("✅ Migrated: \(filename) -> \(parentDirName)")
                }
            }
        }
        
        saveScriptTiles()
        userDefaults.set(true, forKey: migrationKey)
    }

    func loadScriptTiles() {
        if let data = userDefaults.data(forKey: scriptTilesKey),
           let decoded = try? JSONDecoder().decode([ScriptTile].self, from: data) {
            scriptTiles = decoded
        }
    }

    func saveScriptTiles() {
        if let encoded = try? JSONEncoder().encode(scriptTiles) {
            userDefaults.set(encoded, forKey: scriptTilesKey)
        }
    }
    
    func setFavoriteStatus(for id: UUID, isFavorite: Bool) {
        if let index = scriptTiles.firstIndex(where: { $0.id == id }) {
            scriptTiles[index].isFavorite = isFavorite
            saveScriptTiles()
            
            // Also update in tileItems for immediate UI refresh
            if let tileIndex = tileItems.firstIndex(where: { $0.id == id }) {
                if case .tile(var tile) = tileItems[tileIndex] {
                    tile.isFavorite = isFavorite
                    tileItems[tileIndex] = .tile(tile)
                }
            }
            objectWillChange.send()
        }
    }
        
    func addScriptTile(_ tile: ScriptTile) {
        print("📥 ScriptManager.addScriptTile called with: \(tile.name)")
        print("📋 Current scriptTiles count: \(scriptTiles.count)")
        print("🎯 Current tileItems count: \(tileItems.count)")

        scriptTiles.append(tile)
        print("✅ Added to scriptTiles, new count: \(scriptTiles.count)")

        saveScriptTiles()
        print("💾 saveScriptTiles() called")

        // Also add to tileItems for UI display
        tileItems.append(.tile(tile))
        print("🎨 Added to tileItems, new count: \(tileItems.count)")

        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
            print("🔄 objectWillChange.send() called")
        }
    }

    func updateScriptTile(_ tile: ScriptTile) {
        // Mettre à jour dans la liste principale
        if let index = scriptTiles.firstIndex(where: { $0.id == tile.id }) {
            scriptTiles[index] = tile
            saveScriptTiles()
        }

        // Mettre à jour dans la liste affichée (tileItems) pour rafraîchir l'UI
        if let index = tileItems.firstIndex(where: { $0.id == tile.id }) {
            if case .tile = tileItems[index] {
                tileItems[index] = .tile(tile)
                // saveTileItems()
            }
        }
    }

    func deleteScriptTile(_ tile: ScriptTile) {
        scriptTiles.removeAll { $0.id == tile.id }
        saveScriptTiles()

        // Also remove from tileItems
        tileItems.removeAll { item in
            switch item {
            case .tile(let itemTile):
                return itemTile.id == tile.id
            case .group(var group):
                // Remove from group if it's inside one
                let originalCount = group.tiles.count
                group.tiles.removeAll { $0.id == tile.id }

                if group.tiles.count != originalCount {
                    // Update the group or remove it if empty
                    if group.tiles.isEmpty {
                        return true // Remove empty group
                    } else if group.tiles.count == 1 {
                        // Replace group with single tile
                        if let index = tileItems.firstIndex(where: {
                            if case .group(let g) = $0 { return g.id == group.id }
                            return false
                        }) {
                            tileItems[index] = .tile(group.tiles[0])
                        }
                    } else {
                        // Update group with remaining tiles
                        if let index = tileItems.firstIndex(where: {
                            if case .group(let g) = $0 { return g.id == group.id }
                            return false
                        }) {
                            tileItems[index] = .group(group)
                        }
                    }
                }
                return false
            }
        }
        // saveTileItems()
    }

    func importCommandFile(url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        let path = url.path
        
        let tile = ScriptTile(
            name: name,
            description: "Fichier .command importé",
            type: .shellScript,
            projectPath: path, // Le chemin du fichier
            commandToRun: "execute_shell_script_in_terminal", // Commande spéciale gérée par executeShellScript
            workingDirectory: url.deletingLastPathComponent().path
        )
        
        addScriptTile(tile)
    }

    func executeScript(_ tile: ScriptTile) {
        print("🚀 executeScript appelé pour: \(tile.name) - commande: \(tile.commandToRun)")
        guard !isExecuting else {
            print("❌ Script déjà en cours d'exécution")
            return
        }

        isExecuting = true
        executionOutput = ""
        lastExecutedScript = tile

        // Mettre à jour la date de dernière exécution
        var updatedTile = tile
        updatedTile.lastRun = Date()
        updateScriptTile(updatedTile)

        Task {
            await runScript(tile)
        }
    }

    @MainActor
    private func runScript(_ tile: ScriptTile) async {
        let process = Process()
        let pipe = Pipe()
        
        // Détermine si l'action lance une application externe sans sortie à capturer
        let isGuiLaunch = tile.type == .xcodeProject || tile.type == .webUrl || tile.type == .folderBookmark ||
                          (tile.type == .shellScript && (tile.commandToRun.hasSuffix(".sh") || tile.commandToRun == "open Terminal in folder"))

        do {
            if !isGuiLaunch {
                process.standardOutput = pipe
                process.standardError = pipe
            }

            // Définir le répertoire de travail
            if let workingDir = tile.workingDirectory, !workingDir.isEmpty {
                process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
            } else if !tile.projectPath.isEmpty {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: tile.projectPath, isDirectory: &isDirectory), !isDirectory.boolValue {
                    process.currentDirectoryURL = URL(fileURLWithPath: (tile.projectPath as NSString).deletingLastPathComponent)
                } else {
                    process.currentDirectoryURL = URL(fileURLWithPath: tile.projectPath)
                }
            }

            // Variables d'environnement
            var environment = ProcessInfo.processInfo.environment
            for (key, value) in tile.environment {
                environment[key] = value
            }
            process.environment = environment

            // Configuration de la commande (sans l'exécuter)
            switch tile.type {
            case .xcodeProject:
                try await executeXcodeProject(tile, process: process)
            case .swiftPackage:
                try await executeSwiftPackage(tile, process: process)
            case .shellScript:
                try await executeShellScript(tile, process: process)
            case .pythonScript:
                try await executePythonScript(tile, process: process)
            case .streamlitApp:
                try await executeStreamlitApp(tile, process: process)
            case .nodeProject:
                try await executeNodeProject(tile, process: process)
            case .dockerCompose:
                try await executeDockerCompose(tile, process: process)
            case .webUrl:
                try await executeWebUrl(tile, process: process)
            case .folderBookmark:
                try await executeFolderBookmark(tile, process: process)
            case .custom:
                try await executeCustomScript(tile, process: process)
            }

            // Lancement centralisé
            try process.run()

            // Gestion de la sortie
            if !isGuiLaunch {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Aucune sortie" 
                
                await MainActor.run {
                    self.executionOutput = output
                }
            }
        } catch {
            print("❌ Erreur d'exécution: \(error)")
            await MainActor.run {
                self.executionOutput = "❌ Erreur: \(error.localizedDescription)\n\nVérifiez:\n- Les permissions du script\n- Le chemin du fichier\n- La commande utilisée"
            }
        }

        await MainActor.run {
            self.isExecuting = false
        }
    }

    private func executeXcodeProject(_ tile: ScriptTile, process: Process) async throws {
        let projectPath = tile.projectPath
        print("🚀 Configuring to open Xcode project with 'open': \(projectPath)")
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [projectPath]
    }

    private func executeSwiftPackage(_ tile: ScriptTile, process: Process) async throws {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        let args = tile.commandToRun.components(separatedBy: " ").filter { !$0.isEmpty }
        process.arguments = args.isEmpty ? ["run"] : args
    }

    private func executeShellScript(_ tile: ScriptTile, process: Process) async throws {
        print("🔧 Configuring executeShellScript for interactive terminal - command: \(tile.commandToRun)")
        let command = tile.commandToRun
        
        // Cas spécial pour simplement ouvrir un dossier dans le Terminal
        if command == "open Terminal in folder" {
            let workingDir = tile.projectPath.isEmpty ? "~" : tile.projectPath
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", workingDir]
            print("📂 Configured to open Terminal in: \(workingDir)")
            return
        }

        // Cas spécial pour exécuter un script shell dans Terminal
        if command == "execute_shell_script_in_terminal" {
            // Le script à exécuter est dans projectPath
            let scriptPath = tile.projectPath
            let workingDir = (scriptPath as NSString).deletingLastPathComponent

            print("🐚 Will execute shell script: \(scriptPath)")
            print("📂 In directory: \(workingDir)")

            // Créer un script temporaire qui va dans le bon répertoire et exécute le script
            var scriptContent = "#!/bin/bash\n"
            scriptContent += "cd \"\(workingDir)\"\n"
            scriptContent += "echo \"Executing script: \((scriptPath as NSString).lastPathComponent)\"\n"
            scriptContent += "echo \"In directory: \(workingDir)\"\n"
            scriptContent += "echo \"---\"\n"
            scriptContent += "chmod +x \"\(scriptPath)\"\n"
            scriptContent += "\"\(scriptPath)\"\n"
            scriptContent += "echo \"\n--- Script finished. Terminal is now yours. ---\"\n"
            scriptContent += "exec zsh\n" // Laisse le terminal ouvert

            let tempDir = FileManager.default.temporaryDirectory
            let tempScriptURL = tempDir.appendingPathComponent("whisper_exec_\(UUID().uuidString).sh")

            try scriptContent.write(to: tempScriptURL, atomically: true, encoding: .utf8)

            // Rendre le script temporaire exécutable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptURL.path)

            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", tempScriptURL.path]
            print("🚀 Configured to open Terminal and execute script")
            return
        }

        // Pour toutes les autres commandes, créer un script temporaire et l'ouvrir dans une nouvelle fenêtre de Terminal
        let workingDir = tile.workingDirectory ?? tile.projectPath
        
        var scriptContent = "#!/bin/bash\n"
        scriptContent += "cd \"\(workingDir)\"\n"
        scriptContent += "echo \"Executing: \(command) in \(workingDir)\"\n"
        scriptContent += "clear\n"
        scriptContent += "\(command)\n"
        scriptContent += "echo \"\nScript finished. The terminal is now yours.\"\n"
        scriptContent += "exec zsh\n" // Laisse le terminal ouvert et interactif

        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("whisper_exec_\(UUID().uuidString).sh")

        try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
        
        // Rendre le script exécutable
        let chmodProcess = Process()
        chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProcess.arguments = ["+x", scriptURL.path]
        try chmodProcess.run()
        chmodProcess.waitUntilExit()

        // Configurer le processus principal pour ouvrir ce script dans le Terminal
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", scriptURL.path]
        print("🚀 Configured to open script \(scriptURL.path) in a new Terminal window.")
    }

    private func executePythonScript(_ tile: ScriptTile, process: Process) async throws {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        let args = tile.commandToRun.components(separatedBy: " ").filter { !$0.isEmpty }
        process.arguments = args
    }

    private func executeStreamlitApp(_ tile: ScriptTile, process: Process) async throws {
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/streamlit")
        process.arguments = ["run"] + tile.commandToRun.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    private func executeNodeProject(_ tile: ScriptTile, process: Process) async throws {
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/npm")
        let args = tile.commandToRun.components(separatedBy: " ").filter { !$0.isEmpty }
        process.arguments = args.isEmpty ? ["start"] : args
    }

    private func executeDockerCompose(_ tile: ScriptTile, process: Process) async throws {
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker-compose")
        let args = tile.commandToRun.components(separatedBy: " ").filter { !$0.isEmpty }
        process.arguments = args.isEmpty ? ["up"] : args
    }

    private func executeWebUrl(_ tile: ScriptTile, process: Process) async throws {
        print("🌐 Configuring executeWebUrl - URL: \(tile.commandToRun)")
        guard let url = URL(string: tile.commandToRun), url.scheme != nil else {
            throw NSError(domain: "URLError", code: 1, userInfo: [NSLocalizedDescriptionKey: "URL invalide: \(tile.commandToRun)"])
        }
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
    }

    private func executeFolderBookmark(_ tile: ScriptTile, process: Process) async throws {
        print("📂 Configuring executeFolderBookmark - Path: \(tile.projectPath)")
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [tile.projectPath]
    }

    private func executeCustomScript(_ tile: ScriptTile, process: Process) async throws {
        let parts = tile.commandToRun.components(separatedBy: " ").filter { !$0.isEmpty }
        guard let command = parts.first else { return }

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = Array(parts.dropFirst())
    }

    private func createDefaultTiles() {
        guard scriptTiles.isEmpty else { return }

        // Créer quelques tuiles d'exemple
        let defaultTiles = [
            ScriptTile(
                name: "AI Presentation",
                description: "Lance le script de présentation IA",
                type: .shellScript,
                projectPath: "~/ai-presentation-architect",
                commandToRun: "~/ai-presentation-architect/sos_ai_presentation.sh presentation"
            ),
            ScriptTile(
                name: "Whisper Project",
                description: "Ouvrir le projet Whisper dans Xcode",
                type: .xcodeProject,
                projectPath: "~/whisper",
                commandToRun: "open"
            ),
            ScriptTile(
                name: "Test Whisper",
                description: "Lancer les tests du projet Whisper",
                type: .xcodeProject,
                projectPath: "~/whisper",
                commandToRun: "test"
            ),
            ScriptTile(
                name: "Terminal",
                description: "Ouvrir un terminal",
                type: .shellScript,
                projectPath: "",
                commandToRun: "open -a Terminal"
            ),
            ScriptTile(
                name: "Terminal Whisper",
                description: "Terminal dans le dossier Whisper",
                type: .shellScript,
                projectPath: "~/whisper",
                commandToRun: "open Terminal in folder"
            ),
            ScriptTile(
                name: "Terminal Desktop",
                description: "Terminal sur le Desktop",
                type: .shellScript,
                projectPath: "~/Desktop",
                commandToRun: "open Terminal in folder"
            )
        ]

        scriptTiles = defaultTiles
        saveScriptTiles()

        // Initialiser tileItems si vide
        if tileItems.isEmpty {
            tileItems = scriptTiles.map { .tile($0) }
            // saveTileItems()
        }
    }

    // MARK: - Group Management

    func createGroup(from tiles: [ScriptTile], name: String) {
        let group = TileGroup(name: name, tiles: tiles)

        // Supprimer les tuiles individuelles de tileItems
        tileItems = tileItems.filter { item in
            switch item {
            case .tile(let tile):
                return !tiles.contains(tile)
            case .group:
                return true
            }
        }

        // Ajouter le nouveau groupe
        tileItems.append(.group(group))
        // saveTileItems()
    }

    func addTileToGroup(_ tile: ScriptTile, groupId: UUID) {
        for (index, item) in tileItems.enumerated() {
            if case .group(var group) = item, group.id == groupId {
                group.tiles.append(tile)
                tileItems[index] = .group(group)

                // Supprimer la tuile individuelle
                tileItems = tileItems.filter { otherItem in
                    switch otherItem {
                    case .tile(let otherTile):
                        return otherTile.id != tile.id
                    case .group:
                        return true
                    }
                }

                // saveTileItems()
                break
            }
        }
    }

    func removeFromGroup(_ tile: ScriptTile, groupId: UUID) {
        for (index, item) in tileItems.enumerated() {
            if case .group(var group) = item, group.id == groupId {
                group.tiles.removeAll { $0.id == tile.id }

                if group.tiles.isEmpty {
                    // Supprimer le groupe vide
                    tileItems.remove(at: index)
                } else if group.tiles.count == 1 {
                    // Si il ne reste qu'une tuile, dissoudre le groupe
                    let remainingTile = group.tiles[0]
                    tileItems[index] = .tile(remainingTile)
                } else {
                    tileItems[index] = .group(group)
                }

                // Ajouter la tuile comme élément individuel
                tileItems.append(.tile(tile))

                // saveTileItems()
                break
            }
        }
    }

    func expandGroup(_ groupId: UUID) {
        for (index, item) in tileItems.enumerated() {
            if case .group(var group) = item, group.id == groupId {
                group.isExpanded.toggle()
                tileItems[index] = .group(group)
                // saveTileItems()
                break
            }
        }
    }

    func dissolveGroup(_ groupId: UUID) {
        print("💥 dissolveGroup appelé pour groupe: \(groupId)")
        for (index, item) in tileItems.enumerated() {
            if case .group(let group) = item, group.id == groupId {
                print("🔍 Groupe trouvé avec \(group.tiles.count) tiles à l'index \(index)")

                // Supprimer le groupe
                tileItems.remove(at: index)

                // Insérer toutes les tiles à la même position (en ordre inverse pour maintenir l'ordre)
                for (tileIndex, tile) in group.tiles.enumerated() {
                    tileItems.insert(.tile(tile), at: index + tileIndex)
                    print("➕ Tile \(tile.name) insérée à l'index \(index + tileIndex)")
                }

                // saveTileItems()
                print("✅ Groupe dissous, \(group.tiles.count) tiles libérées à la bonne position")
                break
            }
        }
    }

    func canDropOn(_ target: TileItem, dragging: TileItem) -> Bool {
        print("🎯 canDropOn - target: \(target.id), dragging: \(dragging.id)")
        switch (target, dragging) {
        case (.tile, .tile):
            print("✅ Peut créer un groupe (tile sur tile)")
            return true // Peut créer un groupe
        case (.group, .tile):
            print("✅ Peut ajouter à un groupe (tile sur groupe)")
            return true // Peut ajouter à un groupe
        default:
            print("❌ Drop non autorisé")
            return false
        }
    }

    func handleDrop(target: TileItem, dragging: TileItem) {
        print("🚀 handleDrop appelé - target: \(target.id), dragging: \(dragging.id)")

        // Si c'est le même élément, c'est juste un réarrangement
        if target.id == dragging.id {
            print("🔄 Même élément - pas d'action")
            return
        }

        switch (target, dragging) {
        case (.tile(let targetTile), .tile(let draggingTile)):
            // Créer un nouveau groupe
            print("📦 Création d'un groupe avec \(targetTile.name) et \(draggingTile.name)")
            let groupName = "Groupe"
            createGroup(from: [targetTile, draggingTile], name: groupName)

        case (.group(let group), .tile(let draggingTile)):
            // Ajouter à un groupe existant
            print("➕ Ajout de \(draggingTile.name) au groupe \(group.name)")
            addTileToGroup(draggingTile, groupId: group.id)

        default:
            print("❌ handleDrop - cas non géré")
            break
        }
    }

    func moveAfter(dragged: TileItem, target: TileItem) {
        print("🔄 MOVE AFTER: \(dragged.id) après \(target.id)")

        // Supprimer l'élément traîné
        tileItems.removeAll { $0.id == dragged.id }

        // Trouver la position du target
        if let targetIndex = tileItems.firstIndex(where: { $0.id == target.id }) {
            // Insérer après le target
            let insertIndex = targetIndex + 1
            tileItems.insert(dragged, at: min(insertIndex, tileItems.count))
            print("✅ Inséré à l'index \(insertIndex)")
        } else {
            // Si target pas trouvé, ajouter à la fin
            tileItems.append(dragged)
            print("✅ Ajouté à la fin")
        }

        // saveTileItems()
        print("📋 Total items: \(tileItems.count)")
    }

    func moveToEnd(_ item: TileItem) {
        print("🔚 MOVE TO END: \(item.id)")

        // Supprimer de la position actuelle
        tileItems.removeAll { $0.id == item.id }

        // Ajouter à la fin
        tileItems.append(item)

        // saveTileItems()
        print("✅ Déplacé à la fin, total: \(tileItems.count)")
    }
}