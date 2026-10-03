//
//  DoorCoreDataManager.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

#if canImport(CoreData)
import CoreData

public struct DoorCoreDataManager {
    let backgroundContext: NSManagedObjectContext

    public let container: NSPersistentContainer

    public enum PersistentStoreType {
        case inMemory
        case appGroup(String, fileManager: FileManager)
        case local
    }

    public init(persistentStoreType: PersistentStoreType) {
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [.module])!
        container = NSPersistentContainer(name: "Door", managedObjectModel: managedObjectModel)
        switch persistentStoreType {
        case .inMemory:
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        case let .appGroup(appGroup, fileManager):
            guard let fileContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
                fatalError("Could not get container url for appGroup.")
            }

            let url = fileContainer.appendingPathComponent("Door").appendingPathExtension("sqlite")

            let storeDescription = NSPersistentStoreDescription(url: url)
            container.persistentStoreDescriptions = [storeDescription]
        case .local:
            break
        }
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        container.viewContext.automaticallyMergesChangesFromParent = true

        backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    func insertUser(remoteUser: RemoteUser) async throws -> RemoteUser {
        try await backgroundContext.perform(schedule: .enqueued) {
            let user = User(context: backgroundContext)
            user.id = remoteUser.id
            user.doorId = remoteUser.doorId
            user.customDoorId = remoteUser.customDoorId
            user.phoneNumber = remoteUser.phoneNumber
            user.hashedPhoneNumber = remoteUser.hashedPhoneNumber
            user.imageFilterNextAvailableDate = remoteUser.imageFilterNextAvailableDate
            guard backgroundContext.hasChanges else {
                return remoteUser
            }
            do {
                try backgroundContext.save()
                return remoteUser
            } catch {
                throw DataManagerError.coreDataError(error)
            }
        }
    }

    nonisolated public static func userFetchRequest(userId: UUID) -> NSFetchRequest<User> {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \User.id, ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "%K == %@", "id", userId as CVarArg)
        fetchRequest.fetchLimit = 1
        return fetchRequest
    }

    public func getPhoneNumber(userId: UUID) async throws -> String? {
        try await backgroundContext.perform(schedule: .enqueued) {
            try backgroundContext.fetch(Self.userFetchRequest(userId: userId)).first?.phoneNumber
        }
    }

    public func getDoorId(userId: UUID) async throws -> UUID? {
        try await backgroundContext.perform(schedule: .enqueued) {
            try backgroundContext.fetch(Self.userFetchRequest(userId: userId)).first?.customDoorId
        }
    }

    func insertKnock(id: UUID, knockType: KnockType) async throws {
        try await backgroundContext.perform(schedule: .enqueued) {
            switch knockType {
            case let .sent(direction, date):
                let knock = Knock(context: backgroundContext)
                knock.id = id
                knock.sentDate = date
                knock.timestamp = date
                knock.sourceUserId = direction.sourceUserId
                knock.destinationUserId = direction.destinationUserId
                let sourceUser = try backgroundContext.fetch(
                    Self.userFetchRequest(userId: knockType.direction.sourceUserId)
                )
                .first
                sourceUser?.addToSentKnocks(knock)
                let destinationUser = try backgroundContext.fetch(
                    Self.userFetchRequest(userId: knockType.direction.destinationUserId)
                ).first
                destinationUser?.addToReceivedKnocks(knock)
                knock.sourceUser = sourceUser
                knock.destinationUser = destinationUser
            case let .received(direction, date):
                let knock = Knock(context: backgroundContext)
                knock.id = id
                knock.receivedDate = date
                knock.timestamp = date
                knock.sourceUserId = direction.sourceUserId
                knock.destinationUserId = direction.destinationUserId
                let sourceUser = try backgroundContext.fetch(
                    Self.userFetchRequest(userId: knockType.direction.sourceUserId)
                )
                .first
                sourceUser?.addToSentKnocks(knock)
                let destinationUser = try backgroundContext.fetch(
                    Self.userFetchRequest(userId: knockType.direction.destinationUserId)
                ).first
                destinationUser?.addToReceivedKnocks(knock)
                knock.sourceUser = sourceUser
                knock.destinationUser = destinationUser
            case let .acknowledged(direction, date):
                #warning("Do")
            }

            guard backgroundContext.hasChanges else {
                return
            }
            do {
                try backgroundContext.save()
                return
            } catch {
                throw DataManagerError.coreDataError(error)
            }
        }
    }

    func insertKnocks(_ remoteKnocks: [ApiGetKnockResponse]) async throws {
        try await backgroundContext.perform(schedule: .enqueued) {
            for remoteKnock in remoteKnocks {
                let knock = Knock(context: backgroundContext)
                knock.id = remoteKnock.id
                knock.sentDate = remoteKnock.createdAt
                knock.timestamp = remoteKnock.createdAt
                knock.sourceUserId = remoteKnock.sourceUserId
                knock.destinationUserId = remoteKnock.destinationUserId
                let sourceUser = try backgroundContext.fetch(Self.userFetchRequest(userId: remoteKnock.sourceUserId))
                    .first
                sourceUser?.addToSentKnocks(knock)

                let destinationUser = try remoteKnock.destinationUserId.flatMap { destinationUserId in
                    try backgroundContext.fetch(Self.userFetchRequest(userId: destinationUserId)).first
                }
                destinationUser?.addToReceivedKnocks(knock)
                knock.sourceUser = sourceUser
                knock.destinationUser = destinationUser
            }

            guard backgroundContext.hasChanges else {
                return
            }
            do {
                try backgroundContext.save()
                return
            } catch {
                throw DataManagerError.coreDataError(error)
            }
        }
    }

    func insertBlob(id: String, data: Data) async throws -> Data {
        try await backgroundContext.perform(schedule: .enqueued) {
            let blob = Blob(context: backgroundContext)
            blob.data = data
            blob.id = id
            guard backgroundContext.hasChanges else {
                return data
            }
            do {
                try backgroundContext.save()
                return data
            } catch {
                throw DataManagerError.coreDataError(error)
            }
        }
    }

    func getBlob(id: String) async throws -> Data? {
        try await backgroundContext.perform(schedule: .enqueued) {
            let fetchRequest: NSFetchRequest<Blob> = Blob.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Blob.id, ascending: false)]
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
            do {
                guard let result = try backgroundContext.fetch(fetchRequest).first else {
                    return nil
                }
                return result.data
            } catch {
                throw DataManagerError.coreDataError(error)
            }
        }
    }

    func insertUsers(remoteUsers: [RemoteUser], cnContactIdentifier: String?) async throws -> [RemoteUser] {
        try await backgroundContext.perform(schedule: .enqueued) {
            for remoteUser in remoteUsers {
                let userFetchRequest = Self.userFetchRequest(userId: remoteUser.id)
                let user: User
                if let existingUser = try backgroundContext.fetch(userFetchRequest).first {
                    user = existingUser
                } else {
                    user = User(context: backgroundContext)
                }

                user.doorId = remoteUser.doorId
                user.customDoorId = remoteUser.customDoorId
                user.id = remoteUser.id
                user.phoneNumber = remoteUser.phoneNumber
                user.hashedPhoneNumber = remoteUser.hashedPhoneNumber
                user.imageFilterNextAvailableDate = remoteUser.imageFilterNextAvailableDate
                if let cnContactIdentifier {
                    let contact = Contact(context: backgroundContext)
                    contact.cnContactIdentifier = cnContactIdentifier
                    user.addToContacts(contact)
                }
            }
            guard backgroundContext.hasChanges else {
                return remoteUsers
            }
            do {
                try backgroundContext.save()
                return remoteUsers
            } catch {
                throw DataManagerError.coreDataError(error)
            }
        }
    }

    func insertDoors(remoteDoors: [RemoteCustomDoor]) async throws -> [RemoteCustomDoor] {
        try await backgroundContext.perform(schedule: .enqueued) {
            for remoteDoor in remoteDoors {
                let door = CustomDoor(context: backgroundContext)
                door.id = remoteDoor.id
                door.prompt = remoteDoor.prompt
                door.sourceDoorId = remoteDoor.sourceDoorId
            }
            guard backgroundContext.hasChanges else {
                return remoteDoors
            }
            do {
                try backgroundContext.save()
                return remoteDoors
            } catch {
                throw DataManagerError.coreDataError(error)
            }
        }
    }

    func deleteAll() async throws {
        try await backgroundContext.perform(schedule: .enqueued) {
            for entity in [
                Knock.entity(),
                User.entity(),
                Door.entity(),
                CustomDoor.entity(),
                Blob.entity(),
                Contact.entity(),
            ] {
                guard let entityName = entity.name else { continue }
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                do {
                    try container.persistentStoreCoordinator.execute(deleteRequest, with: backgroundContext)
                } catch {
                    #warning("Maybe just delete the whole set of SQLite files")
                    throw DataManagerError.coreDataError(error)
                }
            }
        }
    }
}

public extension DoorCoreDataManager {
    static func userFetchedResultsController(
        managedObjectContext: NSManagedObjectContext,
        userEntityDescription: NSEntityDescription,
        phoneNumbers: [String]
    ) -> NSFetchedResultsController<User> {
        let fetchRequest = NSFetchRequest<User>()
        fetchRequest.entity = userEntityDescription
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \User.phoneNumber, ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "phoneNumber IN %@", phoneNumbers)
        return NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }

    static func userFetchedResultsController(
        managedObjectContext: NSManagedObjectContext,
        userEntityDescription: NSEntityDescription,
        userId: UserId
    ) -> NSFetchedResultsController<User> {
        let fetchRequest = NSFetchRequest<User>()
        fetchRequest.fetchLimit = 1
        fetchRequest.entity = userEntityDescription
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \User.id, ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "id == %@", userId.value as CVarArg)
        return NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }
}
#endif
