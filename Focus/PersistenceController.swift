import CoreData
import Foundation

final class PersistenceController {
    @MainActor static let shared = PersistenceController()

    nonisolated let container: NSPersistentContainer

    @MainActor
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DataModel")
        if inMemory {
            if let storeDesc = container.persistentStoreDescriptions.first {
                storeDesc.url = URL(fileURLWithPath: "/dev/null")
            }
        }

        // Enable automatic migrations
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // Don't crash in production - log the error and continue
                print("Core Data error: \(error), \(error.userInfo)")
                #if DEBUG
                assertionFailure("Core Data failed to load: \(error)")
                #endif
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
    }

    // URL state now uses UserDefaults for simplicity
    @MainActor
    func saveURLState(urlString: String, currentURL: String, webVolume: Double) {
        UserDefaults.standard.set(urlString, forKey: "Focus.urlString")
        UserDefaults.standard.set(currentURL, forKey: "Focus.currentURL")
        UserDefaults.standard.set(webVolume, forKey: "Focus.webVolume")
    }

    @MainActor
    func loadURLState() -> (urlString: String, currentURL: String, webVolume: Double) {
        let urlString = UserDefaults.standard.string(forKey: "Focus.urlString") ?? "https://www.google.com"
        let currentURL = UserDefaults.standard.string(forKey: "Focus.currentURL") ?? "https://www.google.com"
        let webVolume = UserDefaults.standard.object(forKey: "Focus.webVolume") as? Double ?? 1.0
        let normalizedWebVolume = min(max(webVolume, 0), 1)
        return (urlString, currentURL, normalizedWebVolume)
    }

    func saveTimers(_ timers: [ActiveTimer]) {
        // Capture viewContext before hopping off main actor
        let viewContext = container.viewContext

        container.performBackgroundTask { context in
            do {
                // Clear existing timers with proper merge handling
                let request: NSFetchRequest<NSFetchRequestResult> = CDTimer.fetchRequest()
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                deleteRequest.resultType = .resultTypeObjectIDs

                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult

                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
                }

                // Save new timers
                for activeTimer in timers {
                    let timer = CDTimer(context: context)
                    timer.id = activeTimer.id
                    timer.originalInput = activeTimer.originalInput
                    timer.endTime = activeTimer.endTime
                    timer.message = activeTimer.message
                }

                try context.save()
            } catch {
                print("Error saving timers: \(error)")
                #if DEBUG
                assertionFailure("Failed to save timers: \(error)")
                #endif
            }
        }
    }

    @MainActor
    func loadTimers() -> [ActiveTimer] {
        let context = container.viewContext
        let request: NSFetchRequest<CDTimer> = CDTimer.fetchRequest()

        do {
            let timers = try context.fetch(request)
            return timers.compactMap { timer in
                guard let id = timer.id,
                      let originalInput = timer.originalInput,
                      let endTime = timer.endTime else {
                    print("Warning: CDTimer with nil required attributes found, skipping")
                    return nil
                }
                return ActiveTimer(id: id, originalInput: originalInput, endTime: endTime, message: timer.message)
            }.filter { !$0.isExpired }
        } catch {
            print("Error loading timers: \(error)")
            #if DEBUG
            assertionFailure("Failed to load timers: \(error)")
            #endif
            return []
        }
    }
}
