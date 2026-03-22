import Foundation
import SwiftUI

class FolderTreeManager: ObservableObject {
    static let shared = FolderTreeManager()
    
    @Published var rootNodes: [TreeNode] = []
    @Published var selectedNode: TreeNode?
    @Published var selectedFolder: TreeNode? // Dossier sélectionné pour les nouveaux enregistrements
    @Published var draggedNode: TreeNode?
    @Published var draggedTranscriptionID: UUID?
    
    private let storageKey = "folderTreeStructure"
    
    init() {
        loadTree()
        // Pas de dossiers par défaut - l'utilisateur crée son arborescence
    }
    
    // Supprimé - pas de dossiers par défaut
    
    // MARK: - Gestion des dossiers
    
    func createFolder(name: String, parent: TreeNode? = nil) {
        let newFolder = TreeNode(name: name)
        
        if let parent = parent {
            parent.addChild(newFolder)
        } else {
            rootNodes.append(newFolder)
        }
        
        saveTree()
        
        // Force le rafraîchissement immédiat comme pour les dossiers orange
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func deleteFolder(_ node: TreeNode) {
        // Retirer de son parent ou de la racine
        if let parent = findParent(of: node) {
            parent.removeChild(node)
        } else {
            rootNodes.removeAll { $0.id == node.id }
        }
        
        saveTree()
        
        // Force le rafraîchissement immédiat
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func renameFolder(_ node: TreeNode, newName: String) {
        node.name = newName
        saveTree()
        
        // Force le rafraîchissement immédiat
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Gestion des transcriptions
    
    func moveTranscription(id: UUID, to folder: TreeNode) {
        // Retirer de tous les dossiers existants
        removeTranscriptionFromAllFolders(id: id)
        
        // Ajouter au nouveau dossier
        folder.addTranscription(id)
        
        saveTree()
        
        // Force le rafraîchissement immédiat
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func removeTranscriptionFromAllFolders(id: UUID) {
        func removeFromNode(_ node: TreeNode) {
            node.removeTranscription(id)
            if let children = node.children {
                for child in children {
                    removeFromNode(child)
                }
            }
        }
        
        for root in rootNodes {
            removeFromNode(root)
        }
    }
    
    func getFolderForTranscription(id: UUID) -> TreeNode? {
        func searchInNode(_ node: TreeNode) -> TreeNode? {
            if node.contains(transcriptionID: id) {
                return node
            }
            
            if let children = node.children {
                for child in children {
                    if let found = searchInNode(child) {
                        return found
                    }
                }
            }
            
            return nil
        }
        
        for root in rootNodes {
            if let found = searchInNode(root) {
                return found
            }
        }
        
        return nil
    }
    
    // MARK: - Utilitaires
    
    private func findParent(of node: TreeNode) -> TreeNode? {
        func searchInNode(_ parent: TreeNode) -> TreeNode? {
            if let children = parent.children {
                if children.contains(where: { $0.id == node.id }) {
                    return parent
                }
                
                for child in children {
                    if let found = searchInNode(child) {
                        return found
                    }
                }
            }
            
            return nil
        }
        
        for root in rootNodes {
            if let found = searchInNode(root) {
                return found
            }
        }
        
        return nil
    }
    
    func toggleExpansion(_ node: TreeNode) {
        node.isExpanded.toggle()
        saveTree()
    }
    
    // MARK: - Persistence
    
    private func saveTree() {
        let folderData = rootNodes.map { $0.toFolderData() }
        if let encoded = try? JSONEncoder().encode(folderData) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadTree() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([FolderData].self, from: data) {
            rootNodes = decoded.map { TreeNode(from: $0) }
        }
    }
    
}