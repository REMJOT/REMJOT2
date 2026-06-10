//
//  MemoryDraft.swift
//  RecallCore
//
//  The value type that flows through the pipeline:
//  CaptureEngine → IntelligenceService → PersistenceController
//

import CoreData
import Foundation

// MARK: - Capture pipeline value types

public enum CaptureMode: String, Codable, Sendable {
    case voice, photo, text, share
}

/// Raw output of the CaptureEngine, before AI enrichment.
public struct MemoryDraft: Sendable {
    public var content: String
    public var mode: CaptureMode
    public var rawMediaFilename: String?   // audio/image saved in App Group

    public init(content: String, mode: CaptureMode, rawMediaFilename: String? = nil) {
        self.content = content
        self.mode = mode
        self.rawMediaFilename = rawMediaFilename
    }
}

/// Output of the IntelligenceService — ready to persist.
public struct EnrichedDraft: Sendable {
    public var draft: MemoryDraft
    public var people: [String]            // extracted person names
    public var embedding: [Float]          // semantic vector for search
    public var predictedTopic: String?     // Core ML classifier output

    public init(draft: MemoryDraft, people: [String],
                embedding: [Float], predictedTopic: String?) {
        self.draft = draft
        self.people = people
        self.embedding = embedding
        self.predictedTopic = predictedTopic
    }
}

// MARK: - Persisting an enriched draft

public extension EnrichedDraft {

    /// Creates the Memory plus its Topic/Person links in one transaction.
    /// Call on a background context from PersistenceController.
    @discardableResult
    func persist(in context: NSManagedObjectContext) throws -> Memory {
        let memory = Memory(context: context)
        memory.id = UUID()
        memory.content = draft.content
        memory.captureMode = draft.mode.rawValue
        memory.rawMediaFilename = draft.rawMediaFilename
        memory.createdAt = Date()
        memory.embedding = embedding.asData

        // Topic: find-or-create by name
        if let topicName = predictedTopic, !topicName.isEmpty {
            let request = Topic.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[cd] %@", topicName)
            request.fetchLimit = 1
            let topic = try context.fetch(request).first ?? {
                let t = Topic(context: context)
                t.id = UUID()
                t.name = topicName
                return t
            }()
            memory.addToTopics(topic)
        }

        // People: find-or-create each
        for name in people {
            let request = Person.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[cd] %@", name)
            request.fetchLimit = 1
            let person = try context.fetch(request).first ?? {
                let p = Person(context: context)
                p.id = UUID()
                p.name = name
                return p
            }()
            memory.addToPeople(person)
        }

        try context.save()
        return memory
    }
}

// MARK: - Embedding <-> Data helpers

public extension Array where Element == Float {
    var asData: Data {
        withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

public extension Memory {
    /// Decoded embedding vector for vDSP cosine-similarity search.
    var embeddingVector: [Float]? {
        guard let data = embedding else { return nil }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}
