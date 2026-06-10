# RecallCore — Setup Guide

The shared Swift package for the Recall app. Contains the Core Data + CloudKit
stack, the data model, and the capture pipeline value types.

## What's inside

```
RecallCore/
├── Package.swift
└── Sources/RecallCore/
    ├── Persistence/
    │   └── PersistenceController.swift   ← NSPersistentCloudKitContainer stack
    ├── Models/
    │   └── MemoryDraft.swift             ← Pipeline types + persist helpers
    └── Resources/
        └── Recall.xcdatamodeld/          ← 6-entity CloudKit-ready schema
```

## Wiring it into Xcode (one-time, ~15 minutes)

1. **Create the app project.** Xcode → New Project → iOS App → name it `Recall`.
   Interface: SwiftUI. Do NOT check "Use Core Data" (the package owns the stack).

2. **Add this package locally.** Drag the `RecallCore` folder into your project
   navigator (or File → Add Package Dependencies → Add Local). Then in the
   Recall target → General → Frameworks, add `RecallCore`.

3. **Add capabilities to the Recall target** (Signing & Capabilities):
   - **iCloud** → check CloudKit → container `iCloud.com.yourname.recall`
   - **App Groups** → `group.com.yourname.recall`
   - **Background Modes** → check "Background fetch" + "Background processing"
     (needed later for the EchoScheduler)

4. **Edit the two IDs** at the top of `PersistenceController.swift` to match
   the identifiers you just created.

5. **Inject the stack** in your App file:

   ```swift
   import SwiftUI
   import RecallCore

   @main
   struct RecallApp: App {
       let persistence = PersistenceController.shared

       var body: some Scene {
           WindowGroup {
               HomeView()
                   .environment(\.managedObjectContext, persistence.viewContext)
           }
       }
   }
   ```

6. **Smoke test.** Drop this in a temporary view and run on your iPhone 13:

   ```swift
   Button("Test save") {
       let draft = MemoryDraft(content: "First memory!", mode: .text)
       let enriched = EnrichedDraft(draft: draft, people: [],
                                    embedding: [], predictedTopic: "Test")
       let ctx = PersistenceController.shared.newBackgroundContext()
       ctx.perform { try? enriched.persist(in: ctx) }
   }
   ```

   Then check it syncs: install on a second device (or simulator signed into
   the same iCloud account) and watch the memory appear.

## Important CloudKit notes

- **First run must be on a real device** signed into iCloud — the simulator's
  CloudKit sync is unreliable. Your iPhone 13 is perfect.
- The CloudKit schema is created lazily in the **Development** environment the
  first time you save. Before App Store release, deploy the schema to
  Production in the CloudKit Console (one button click).
- All attributes in the model are optional or defaulted, all relationships
  have inverses, and there are no unique constraints — these are hard CloudKit
  requirements. Keep that pattern when you add fields.
- Codegen is set to `class` — Xcode auto-generates the `Memory`, `Topic`, etc.
  classes at build time. No manual NSManagedObject files needed.

## Build order (from our architecture session)

1. ✅ Core Data model + CloudKit container  ← you are here
2. CaptureSheet with text mode — get save/read working end to end
3. Voice capture (SFSpeechRecognizer, on-device)
4. OCR (DataScannerViewController)
5. JourneyView timeline (@FetchRequest sorted by createdAt)
6. IntelligenceService (NLTagger people → NLEmbedding vectors)
7. EchoScheduler + WidgetKit widget
8. Share Extension (App Group is already set up for it)
