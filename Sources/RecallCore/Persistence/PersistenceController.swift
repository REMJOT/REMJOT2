//
//  PersistenceController.swift
//  RecallCore
//
//  The single Core Data + CloudKit stack shared by every target:
//  main app, Share Extension, Widget, and Watch app.
//
//  Key decisions:
//  • NSPersistentCloudKitContainer = free iCloud sync, zero backend code
//  • Store lives in the App Group container so the Share Extension and
//    Widget read/write the SAME database as the main app
//  • Persistent history tracking is ON (required for cross-process sync)
//

import CoreData
import Foundation

public final class PersistenceController {

    // MARK: - Configuration (edit these two to match your setup)

    /// Your App Group identifier — create it in Signing & Capabilities
    /// for EVERY target (app, share extension, widget, watch).
    public static let appGroupID = "group.com.yourname.recall"

    /// Your CloudKit container — created automatically when you add the
    /// iCloud capability with CloudKit checked in the main app target.
    public static let cloudKitContainerID = "iCloud.com.yourname.recall"

    // MARK: - Shared instance

    public static let shared = PersistenceController()

    /// In-memory store for SwiftUI previews and unit tests.
    public static let preview = PersistenceController(inMemory: true)

    public let container: NSPersistentCloudKitContainer

    /// Main-thread context for SwiftUI @FetchRequest and UI work.
    public var viewContext: NSManagedObjectContext { container.viewContext }

    // MARK: - Init

    public init(inMemory: Bool = false) {
        // Load the model from the package bundle (it ships inside RecallCore).
        guard
            let modelURL = Bundle.module.url(forResource: "Recall", withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("RecallCore: could not load Recall.momd from package bundle")
        }

        container = NSPersistentCloudKitContainer(name: "Recall", managedObjectModel: model)

        let description: NSPersistentStoreDescription
        if inMemory {
            description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
        } else {
            // Store the database in the App Group so extensions can reach it.
            let storeURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)!
                .appendingPathComponent("Recall.sqlite")
            description = NSPersistentStoreDescription(url: storeURL)
            description.cloudKitContainerOptions =
                NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainerID)
        }

        // Required for CloudKit sync + cross-process change tracking.
        description.setOption(true as NSNumber,
                              forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber,
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                // In development, crash loudly. In production, surface a
                // recovery UI instead.
                fatalError("RecallCore: store failed to load — \(error)")
            }
        }

        // Merge CloudKit changes into the UI context automatically,
        // and let in-memory (newer) changes win on conflict.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Background work

    /// Use for saves coming from the CaptureEngine / IntelligenceService
    /// so heavy writes never block the UI.
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    /// Convenience save that ignores empty saves and logs errors.
    public func save(_ context: NSManagedObjectContext? = nil) {
        let ctx = context ?? viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
        } catch {
            assertionFailure("RecallCore: save failed — \(error)")
        }
    }
}
