import Foundation
import SwiftUI

enum ScriptType: String, CaseIterable, Codable {
    case xcodeProject = "xcode"
    case swiftPackage = "swift_package"
    case shellScript = "shell"
    case pythonScript = "python"
    case streamlitApp = "streamlit"
    case nodeProject = "node"
    case dockerCompose = "docker"
    case webUrl = "web_url"
    case folderBookmark = "folder_bookmark"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .xcodeProject: return "Xcode Project"
        case .swiftPackage: return "Swift Package"
        case .shellScript: return "Shell Script"
        case .pythonScript: return "Python Script"
        case .streamlitApp: return "Streamlit App"
        case .nodeProject: return "Node.js Project"
        case .dockerCompose: return "Docker Compose"
        case .webUrl: return "Web URL"
        case .folderBookmark: return "Dossier"
        case .custom: return "Custom Script"
        }
    }

    var defaultIcon: String {
        switch self {
        case .xcodeProject: return "hammer.fill"
        case .swiftPackage: return "swift"
        case .shellScript: return "terminal.fill"
        case .pythonScript: return "snake.fill"
        case .streamlitApp: return "chart.line.uptrend.xyaxis"
        case .nodeProject: return "node.fill"
        case .dockerCompose: return "cube.box.fill"
        case .webUrl: return "globe"
        case .folderBookmark: return "folder.fill"
        case .custom: return "gear"
        }
    }

    var defaultColor: Color {
        switch self {
        case .xcodeProject: return .blue
        case .swiftPackage: return .orange
        case .shellScript: return .purple
        case .pythonScript: return .yellow
        case .streamlitApp: return .red
        case .nodeProject: return .green
        case .dockerCompose: return .cyan
        case .webUrl: return .cyan
        case .folderBookmark: return .indigo
        case .custom: return .gray
        }
    }
}

struct ScriptTile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var type: ScriptType
    var iconName: String
    var color: String // Stocké en hex
    var projectPath: String
    var commandToRun: String
    var workingDirectory: String?
    var environment: [String: String]
    var isEnabled: Bool
    var lastRun: Date?
    var isFavorite: Bool

    init(
        name: String,
        description: String = "",
        type: ScriptType,
        iconName: String? = nil,
        color: Color? = nil,
        projectPath: String,
        commandToRun: String,
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        isEnabled: Bool = true,
        isFavorite: Bool = false,
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.iconName = iconName ?? type.defaultIcon
        self.color = (color ?? type.defaultColor).hexString
        self.projectPath = projectPath
        self.commandToRun = commandToRun
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.isEnabled = isEnabled
        self.isFavorite = isFavorite
        self.lastRun = nil
    }

    var colorValue: Color {
        Color(hex: color) ?? Color.gray
    }
}

struct TileGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var tiles: [ScriptTile]
    var isExpanded: Bool

    init(name: String, tiles: [ScriptTile] = [], id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.tiles = tiles
        self.isExpanded = false
    }

    var previewTiles: [ScriptTile] {
        Array(tiles.prefix(4)) // Afficher jusqu'à 4 tuiles dans la prévisualisation
    }

    var groupColor: Color {
        if let firstTile = tiles.first {
            return firstTile.colorValue
        }
        return .gray
    }
}

import SwiftUI
import UniformTypeIdentifiers

enum TileItem: Identifiable, Hashable {
    case tile(ScriptTile)
    case group(TileGroup)

    var id: UUID {
        switch self {
        case .tile(let tile):
            return tile.id
        case .group(let group):
            return group.id
        }
    }
}

// MARK: - Codable Conformance
extension TileItem: Codable {
    enum CodingKeys: CodingKey {
        case type
        case payload
    }
    
    enum ItemType: String, Codable {
        case tile, group
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        switch type {
        case .tile:
            let payload = try container.decode(ScriptTile.self, forKey: .payload)
            self = .tile(payload)
        case .group:
            let payload = try container.decode(TileGroup.self, forKey: .payload)
            self = .group(payload)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .tile(let tile):
            try container.encode(ItemType.tile, forKey: .type)
            try container.encode(tile, forKey: .payload)
        case .group(let group):
            try container.encode(ItemType.group, forKey: .type)
            try container.encode(group, forKey: .payload)
        }
    }
}

// MARK: - Transferable Conformance
extension TileItem: Transferable {
    static var typeIdentifier: String { "com.mrd.TileItem" }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .tileItem)
    }
}

extension UTType {
    static var tileItem: UTType { UTType(exportedAs: "com.mrd.TileItem") }
}