import Foundation

// Structure simplifiée pour la persistence
struct FolderData: Codable {
    let id: UUID
    let name: String
    let children: [FolderData]?
    let isExpanded: Bool
    let transcriptionIDs: [UUID]
}

// Modèle de données pour l'arborescence
class TreeNode: Identifiable, ObservableObject, Hashable {
    let id: UUID
    @Published var name: String
    @Published var children: [TreeNode]?
    @Published var isExpanded: Bool = true
    @Published var transcriptionIDs: [UUID] = []
    
    init(name: String, children: [TreeNode]? = nil) {
        self.id = UUID()
        self.name = name
        self.children = children
    }
    
    // Initialisation depuis les données persistées
    init(from data: FolderData) {
        self.id = data.id
        self.name = data.name
        self.isExpanded = data.isExpanded
        self.transcriptionIDs = data.transcriptionIDs
        
        if let childrenData = data.children {
            self.children = childrenData.map { TreeNode(from: $0) }
        }
    }
    
    // Conversion en données persistables
    func toFolderData() -> FolderData {
        FolderData(
            id: id,
            name: name,
            children: children?.map { $0.toFolderData() },
            isExpanded: isExpanded,
            transcriptionIDs: transcriptionIDs
        )
    }
    
    // Pour Hashable
    static func == (lhs: TreeNode, rhs: TreeNode) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Méthodes utilitaires
    func addChild(_ child: TreeNode) {
        if children == nil {
            children = []
        }
        children?.append(child)
    }
    
    func removeChild(_ child: TreeNode) {
        children?.removeAll { $0.id == child.id }
    }
    
    func addTranscription(_ id: UUID) {
        if !transcriptionIDs.contains(id) {
            transcriptionIDs.append(id)
        }
    }
    
    func removeTranscription(_ id: UUID) {
        transcriptionIDs.removeAll { $0 == id }
    }
    
    func contains(transcriptionID: UUID) -> Bool {
        return transcriptionIDs.contains(transcriptionID)
    }
    
    // Recherche récursive d'un nœud
    func findNode(withID id: UUID) -> TreeNode? {
        if self.id == id {
            return self
        }
        
        if let children = children {
            for child in children {
                if let found = child.findNode(withID: id) {
                    return found
                }
            }
        }
        
        return nil
    }
}

