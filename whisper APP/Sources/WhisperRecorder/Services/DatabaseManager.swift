import Foundation
import SQLite

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: Connection?
    
    // Tables
    private let sessions = Table("sessions")
    private let messages = Table("messages")
    
    // Colonnes sessions
    private let sessionId = Expression<String>("id")
    private let sessionTitle = Expression<String>("title")
    private let sessionCreatedAt = Expression<Date>("created_at")
    private let sessionUpdatedAt = Expression<Date>("updated_at")
    
    // Colonnes messages
    private let messageId = Expression<String>("id")
    private let messageSessionId = Expression<String>("session_id")
    private let messageRole = Expression<String>("role")
    private let messageContent = Expression<String>("content")
    private let messageCreatedAt = Expression<Date>("created_at")
    private let messageAudioPath = Expression<String?>("audio_path")
    
    private init() {
        setupDatabase()
    }
    
    private var databasePath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("WhisperByMrD")
        
        // Créer le dossier si nécessaire
        try? FileManager.default.createDirectory(at: appFolder,
                                                  withIntermediateDirectories: true)
        
        // Note: Utilise SQLite temporairement, architecture prête pour DuckDB
        return appFolder.appendingPathComponent("data.sqlite").path
    }
    
    private func setupDatabase() {
        do {
            db = try Connection(databasePath)
            createTables()
            print("✅ Database initialized at: \(databasePath)")
        } catch {
            print("❌ Failed to initialize database: \(error)")
        }
    }
    
    private func createTables() {
        guard let db = db else { return }
        
        do {
            try db.execute("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                );
            """)
            
            try db.execute("""
                CREATE TABLE IF NOT EXISTS messages (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    content TEXT NOT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    audio_path TEXT,
                    tool_calls TEXT,
                    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
                );
            """)
            
            print("✅ Tables created successfully (if they didn't exist).")
        } catch {
            print("❌ Failed to create tables: \(error)")
        }
    }
    
    // MARK: - Session Management
    
    func createSession(title: String) -> String {
        guard let db = db else {
            fatalError("Database not initialized.")
        }
        
        let newId = UUID().uuidString
        let now = Date()
        
        let insert = sessions.insert(
            sessionId <- newId,
            sessionTitle <- title,
            sessionCreatedAt <- now,
            sessionUpdatedAt <- now
        )
        
        do {
            try db.run(insert)
            print("✅ New session created with ID: \(newId)")
            return newId
        } catch {
            print("❌ Failed to create session: \(error)")
            // Fallback or rethrow
            return ""
        }
    }
    
    func getSessions() -> [(id: String, title: String, createdAt: Date)] {
        guard let db = db else { return [] }
        
        var result: [(id: String, title: String, createdAt: Date)] = []
        
        do {
            for session in try db.prepare(sessions.order(sessionCreatedAt.desc)) {
                result.append((
                    id: session[sessionId],
                    title: session[sessionTitle],
                    createdAt: session[sessionCreatedAt]
                ))
            }
        } catch {
            print("❌ Failed to get sessions: \(error)")
        }
        
        return result
    }

    // MARK: - Message Management
    func addMessage(sessionId: String, role: String, content: String, audioPath: String? = nil, toolCalls: [[String: Any]]? = nil) {
        guard let db = db else { return }
        
        let newId = UUID().uuidString
        let now = Date()
        
        var toolCallsString: String?
        if let toolCalls = toolCalls,
           let data = try? JSONSerialization.data(withJSONObject: toolCalls, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            toolCallsString = jsonString
        }

        let insert = messages.insert(
            messageId <- newId,
            messageSessionId <- sessionId,
            messageRole <- role,
            messageContent <- content,
            messageCreatedAt <- now,
            messageAudioPath <- audioPath,
            Expression<String?>("tool_calls") <- toolCallsString
        )
        
        do {
            try db.run(insert)
        } catch {
            print("❌ Failed to add message: \(error)")
        }
    }

    func getMessages(sessionId: String) -> [(role: String, content: String, audioPath: String?, toolCalls: [[String: Any]]?)] {
        guard let db = db else { return [] }
        
        var result: [(role: String, content: String, audioPath: String?, toolCalls: [[String: Any]]?)] = []
        
        do {
            for message in try db.prepare(messages.filter(messageSessionId == sessionId).order(messageCreatedAt)) {
                var toolCalls: [[String: Any]]?
                if let toolCallsString = message[Expression<String?>("tool_calls")],
                   let data = toolCallsString.data(using: .utf8) {
                    toolCalls = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                }

                result.append((
                    role: message[messageRole],
                    content: message[messageContent],
                    audioPath: message[messageAudioPath],
                    toolCalls: toolCalls
                ))
            }
        } catch {
            print("❌ Failed to get messages for session \(sessionId): \(error)")
        }
        
        return result
    }
    
    // MARK: - Export
    
    func exportSessionToMarkdown(sessionId: String) -> String? {
        guard let db = db else { return nil }
        
        do {
            // Récupérer le titre de la session
            let query = sessions.filter(self.sessionId == sessionId)
            
            guard let session = try db.pluck(query) else {
                return nil
            }
            
            let title = session[sessionTitle]
            let createdAt = session[sessionCreatedAt]
            
            // Récupérer les messages
            let messages = getMessages(sessionId: sessionId)
            
            // Construire le Markdown
            var markdown = "# \(title)\n\n"
            markdown += "_Session du \(createdAt.formatted())_\n\n"
            markdown += "---\n\n"
            
            for message in messages {
                let roleEmoji = message.role == "user" ? "👤" : "🤖"
                markdown += "## \(roleEmoji) \(message.role.capitalized)\n\n"
                markdown += "\(message.content)\n\n"
                if let audioPath = message.audioPath {
                    markdown += "_[Audio: \(audioPath)]_\n\n"
                }
                markdown += "---\n\n"
            }
            
            return markdown
        } catch {
            print("❌ Failed to export session: \(error)")
            return nil
        }
    }
    
    // MARK: - Cleanup
    
    func deleteSession(sessionId: String) -> Bool {
        guard let db = db else { return false }
        
        do {
            // Récupérer les chemins audio avant suppression
            let query = messages
                .filter(messageSessionId == sessionId)
                .filter(messageAudioPath != nil)
            
            for message in try db.prepare(query) {
                if let audioPath = message[messageAudioPath] {
                    try? FileManager.default.removeItem(atPath: audioPath)
                }
            }
            
            // Supprimer la session (cascade supprimera les messages)
            let session = sessions.filter(self.sessionId == sessionId)
            try db.run(session.delete())
            
            return true
        } catch {
            print("❌ Failed to delete session: \(error)")
            return false
        }
    }
}