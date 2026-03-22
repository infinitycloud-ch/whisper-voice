import Foundation

struct Folder: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var subfolders: [Folder] = []
    var transcriptions: [UUID] = [] // IDs des transcriptions dans ce dossier
    var isExpanded: Bool = true
    var parentID: UUID? = nil
    
    init(name: String, parentID: UUID? = nil) {
        self.name = name
        self.parentID = parentID
    }
}

class FolderManager: ObservableObject {
    @Published var folders: [Folder] = []
    @Published var transcriptionFolders: [UUID: UUID] = [:] // transcriptionID -> folderID
    @Published var selectedFolder: Folder?
    @Published var draggedTranscription: Transcription?
    @Published var draggedFolder: Folder?
    
    init() {
        loadFolders()
        // Pas de dossiers par défaut - l'utilisateur crée son arborescence
    }
    
    func createFolder(name: String, parentID: UUID? = nil) {
        if let parentID = parentID,
           let parentIndex = findFolderIndex(id: parentID) {
            folders[parentIndex].subfolders.append(Folder(name: name, parentID: parentID))
        } else {
            folders.append(Folder(name: name))
        }
        saveFolders()
    }
    
    func deleteFolder(_ folder: Folder) {
        if let parentID = folder.parentID,
           let parentIndex = findFolderIndex(id: parentID) {
            folders[parentIndex].subfolders.removeAll { $0.id == folder.id }
        } else {
            folders.removeAll { $0.id == folder.id }
        }
        
        // Retirer toutes les transcriptions de ce dossier
        transcriptionFolders = transcriptionFolders.filter { $0.value != folder.id }
        saveFolders()
    }
    
    func renameFolder(_ folder: Folder, newName: String) {
        if let index = findFolderIndex(id: folder.id) {
            folders[index].name = newName
            saveFolders()
        }
    }
    
    func moveTranscription(_ transcription: Transcription, toFolder folder: Folder) {
        transcriptionFolders[transcription.id] = folder.id
        saveFolders()
    }
    
    func removeTranscriptionFromFolder(_ transcription: Transcription) {
        transcriptionFolders.removeValue(forKey: transcription.id)
        saveFolders()
    }
    
    func toggleFolder(_ folder: Folder) {
        if let index = findFolderIndex(id: folder.id) {
            folders[index].isExpanded.toggle()
        }
    }
    
    func getTranscriptionsInFolder(_ folder: Folder) -> [UUID] {
        return transcriptionFolders.compactMap { (key, value) in
            value == folder.id ? key : nil
        }
    }
    
    private func findFolderIndex(id: UUID) -> Int? {
        for (index, folder) in folders.enumerated() {
            if folder.id == id {
                return index
            }
            // Recherche récursive dans les sous-dossiers
            if let _ = findFolderInSubfolders(id: id, in: folder.subfolders) {
                return index
            }
        }
        return nil
    }
    
    private func findFolderInSubfolders(id: UUID, in subfolders: [Folder]) -> Folder? {
        for folder in subfolders {
            if folder.id == id {
                return folder
            }
            if let found = findFolderInSubfolders(id: id, in: folder.subfolders) {
                return found
            }
        }
        return nil
    }
    
    private func saveFolders() {
        if let encodedFolders = try? JSONEncoder().encode(folders),
           let encodedMapping = try? JSONEncoder().encode(transcriptionFolders) {
            UserDefaults.standard.set(encodedFolders, forKey: "folders")
            UserDefaults.standard.set(encodedMapping, forKey: "transcription_folders")
        }
    }
    
    private func loadFolders() {
        if let data = UserDefaults.standard.data(forKey: "folders"),
           let decoded = try? JSONDecoder().decode([Folder].self, from: data) {
            folders = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: "transcription_folders"),
           let decoded = try? JSONDecoder().decode([UUID: UUID].self, from: data) {
            transcriptionFolders = decoded
        }
    }
}