import Foundation
import SQLite
import AppKit
import CryptoKit

struct PasteboardRepresentation: Codable {
    let type: String
    let data: Data
}

struct PasteboardItemData: Codable {
    let representations: [PasteboardRepresentation]
}

struct ClipboardItem: Identifiable, Hashable {
    let id: Int64
    let preview: String
}

final class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()
    
    private var db: Connection?
    
    private let historyTable = Table("history_v2")
    private let id = Expression<Int64>("id")
    private let hashStr = Expression<String>("hash")
    private let preview = Expression<String>("preview")
    private let rawData = Expression<Data>("rawData")
    private let timestamp = Expression<Date>("timestamp")
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let fileManager = FileManager.default
            let homeURL = fileManager.homeDirectoryForCurrentUser
            let dbURL = homeURL.appendingPathComponent(".clipboard_history.sqlite3")
            
            db = try Connection(dbURL.path)
            
            try db?.run(historyTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(hashStr, unique: true)
                t.column(preview)
                t.column(rawData)
                t.column(timestamp)
            })
            print("Database initialized at \(dbURL.path)")
        } catch {
            print("Failed to initialize database: \(error)")
        }
    }
    
    func saveItem(previewText: String, data: Data) {
        guard let db = db else { return }
        
        let dataHash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        
        let insert = historyTable.insert(or: .replace, hashStr <- dataHash, preview <- previewText, rawData <- data, timestamp <- Date())
        do {
            try db.run(insert)
        } catch {
            print("Failed to save item: \(error)")
        }
    }
    
    func fetchLatestItems(limit: Int = 50) -> [ClipboardItem] {
        guard let db = db else { return [] }
        
        var items: [ClipboardItem] = []
        do {
            let query = historyTable.select(id, preview).order(timestamp.desc).limit(limit)
            for row in try db.prepare(query) {
                items.append(ClipboardItem(id: row[id], preview: row[preview]))
            }
        } catch {
            print("Failed to fetch items: \(error)")
        }
        return items
    }
    
    func searchItems(query: String, limit: Int = 50) -> [ClipboardItem] {
        guard let db = db else { return [] }
        
        var items: [ClipboardItem] = []
        do {
            let filter = preview.like("%\(query)%")
            let searchQuery = historyTable.select(id, preview).filter(filter).order(timestamp.desc).limit(limit)
            for row in try db.prepare(searchQuery) {
                items.append(ClipboardItem(id: row[id], preview: row[preview]))
            }
        } catch {
            print("Failed to search items: \(error)")
        }
        return items
    }
    
    func fetchRawData(for itemId: Int64) -> Data? {
        guard let db = db else { return nil }
        do {
            let query = historyTable.filter(id == itemId).select(rawData)
            if let row = try db.pluck(query) {
                return row[rawData]
            }
        } catch {
            print("Fetch raw data error: \(error)")
        }
        return nil
    }
}
