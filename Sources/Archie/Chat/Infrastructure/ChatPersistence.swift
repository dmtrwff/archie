import Foundation
import SwiftData

enum ChatPersistence {
    static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            ChatSessionRecord.self,
            ChatMessageRecord.self,
        ])
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = appSupport.appendingPathComponent("com.typekit.archie", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let storeURL = folder.appendingPathComponent("chat.store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func inMemoryFallbackContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema([
                ChatSessionRecord.self,
                ChatMessageRecord.self,
            ]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Attach orphaned messages to a session (migration from older schema).
    static func bootstrapIfNeeded(modelContext: ModelContext) throws {
        let sessions = try modelContext.fetch(FetchDescriptor<ChatSessionRecord>())
        let orphans = try modelContext.fetch(FetchDescriptor<ChatMessageRecord>())
        guard !orphans.isEmpty else { return }
        let session = sessions.first ?? ChatSessionRecord(name: String(archie: "session.fallback.name"))
        if sessions.isEmpty { modelContext.insert(session) }
        for row in orphans where row.session == nil {
            row.session = session
        }
        try modelContext.save()
    }
}
