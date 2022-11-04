import Contacts
import CloudKit
import CloudKit

class CloudKitUserPermisionModel {
    private var permissionStatus : Bool = false
    private var isSignedInToiCloud : Bool = false
    private var error : String = ""
    private var userName : String = ""
    
    init() {
        getiCloudStatus()
        requestPermision()
        fetchiCloudUserRecordID()
        print(permissionStatus)
        print(isSignedInToiCloud)
        print(userName)
    }
    
    private func getiCloudStatus() {
        CKContainer.default().accountStatus {[weak self] returnedStatus, returnedError in
            DispatchQueue.main.async {
                switch returnedStatus {
                case .available:
                    self?.isSignedInToiCloud = true
                case .noAccount :
                    self?.error = CloudKitError.iCloudAccountNotFound.localizedDescription
                case .couldNotDetermine:
                    self?.error = CloudKitError.iCloudAccountNotDeterminated.localizedDescription
                case .restricted  :
                    self?.error = CloudKitError.iCloudAccountRestricted.localizedDescription
                default :
                    self?.error = CloudKitError.iCloudAccountUnknown.localizedDescription
                }
            }
        }
    }
    
    enum CloudKitError : LocalizedError {
        case iCloudAccountNotFound
        case iCloudAccountNotDeterminated
        case iCloudAccountRestricted
        case iCloudAccountUnknown
    }
    
    func requestPermision() {
        CKContainer.default().requestApplicationPermission([.userDiscoverability]) { [weak self]returnedStarus, returneError in
            DispatchQueue.main.async {
                if returnedStarus == .granted {
                    self?.permissionStatus = true
                }
            }
        }
    }
    
    func fetchiCloudUserRecordID() {
        CKContainer.default().fetchUserRecordID { [weak self] returnedID, returnedError in
            if let id = returnedID {
                self?.discoveriCloudUser(id: id)
            }
        }
    }
    
    func discoveriCloudUser(id: CKRecord.ID) {
        CKContainer.default().discoverUserIdentity(withUserRecordID: id) { [weak self] returnedIdentity, returnedError in
            DispatchQueue.main.async {
                if let name = returnedIdentity?.nameComponents?.givenName {
                    self?.userName = name
                }
            }
        }
    }
    
}



@available(macOS 12.0, *)
public class PackageContactToCloud {
    
    
    private let cloudKitUserPermision =  CloudKitUserPermisionModel()
    public let contactStore = CNContactStore()
    public var allContact : [CNContact] = []
        
        
    public init() {
       // allContact = getContact()
        
    }
        
        
   private func getContact() -> [CNContact]
    {
        var results:[CNContact] = []
        
        let fetchRequest = CNContactFetchRequest(keysToFetch: [CNContactVCardSerialization.descriptorForRequiredKeys()])
        fetchRequest.sortOrder = CNContactSortOrder.userDefault
        do
        {
            try self.contactStore.enumerateContacts(with: fetchRequest, usingBlock: { (contact, stop) in
                results.append(contact)
            })
        }
        catch let error as NSError
        {
            print(error.localizedDescription)
        }
        return results
        
    }
    //MARK: - Function that save contacts form you iPhone to iCLoud with @name@ as parametr
    //PS: must be set the iCloud container and privacy to contacts
        //
    
    public func addContactsToiCloud( name: String) {
        allContact = getContact()
        do {
            let encodeDatavCard = try CNContactVCardSerialization.data(with: allContact)
            let newContactBook = CKRecord(recordType: "ContactBook")
            newContactBook["data"] = encodeDatavCard
            newContactBook["name"] = name
            saveToCloud(record: newContactBook)
        } catch {
            print("error during encoding data\(error)")
        }
    }
    
    
    
    private func saveToCloud(record: CKRecord) {
        CKContainer.default().publicCloudDatabase.save(record) { returnedRecord, returnedError in
            print("Record: \(String(describing: returnedRecord))")
            print("Error: \(String(describing: returnedError))")
            
        }
        
    }
    
    private func fetchItems() -> [CNContact] {
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "ContactBook", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.resultsLimit = 1
        
        var returnedItems = Data()
        
        if #available(iOS 15.0, *) {
            
            queryOperation.recordMatchedBlock = {(returnedRecordID,returnedResult) in
                switch returnedResult {
                case .success(let record):
                    guard let data = record["data"] as? Data else {return}
                    returnedItems = data
                case .failure(let error) :
                    print(error)
                    
                }
            }
        } else{
            queryOperation.recordFetchedBlock = { (returnedRecord) in
                guard let data = returnedRecord["data"] as? Data else {return}
                returnedItems = data
            }
        }
        
        if #available(iOS 15.0, *) {
            queryOperation.queryResultBlock = {[weak self] returnedResult in
                print("RETURNED queryResultBlock: \(returnedResult)")
                print(returnedItems)
                DispatchQueue.main.async {
                    do {
                        let contactStore = CNContactStore()
                        let saveRequest = CNSaveRequest()
                        let contacts : [CNContact] = try! CNContactVCardSerialization.contacts(with: returnedItems) as [CNContact]
                        self?.allContact = contacts
                        for person in contacts {
                            saveRequest.add(person.mutableCopy() as! CNMutableContact, toContainerWithIdentifier: nil)
                        }
                       try contactStore.execute(saveRequest)
                    } catch {
                        print("Erroro with serialization \(error)")
                    }
                }
            }
        } else{
            queryOperation.queryCompletionBlock = { [weak self] (returnedCursor, returnedError) in
                print("RETURNED queryComplitionBlock")
                //print(returnedItems)
                DispatchQueue.main.async {
                    let contacts : [CNContact] = try! CNContactVCardSerialization.contacts(with: returnedItems) as [CNContact]
                    self?.allContact = contacts
                    
                }
            }
        }
        
        addOperation(operation: queryOperation)
        return allContact
    }
    
    private func addOperation(operation: CKDatabaseOperation) {
        CKContainer.default().publicCloudDatabase.add(operation)
        
    }
    
    //MARK: - Fucntion that return array of CNContact items from you iPhone
    
    public func seeContact() -> [CNContact] {
        allContact = getContact()
        return allContact
    }
    
    //MARK: - Fucntion that delete all contacts from you iPhone
    
    public func deleteContacts() {
        do {
            
            let store = CNContactStore()
            let request = CNSaveRequest()
            let contacts = getContact()
            for person in contacts {
                
                request.delete(person.mutableCopy() as! CNMutableContact)
                
            }
            // print("after adding")
            try store.execute(request)
            // print("after save")
        } catch {
            print("Erroro with serialization \(error)")
        }
    }
    
    //MARK: - Fucntion that return array of CNContact items from you iCLoud and add it to you array of
    
    public func uploadFromiCloud() -> [CNContact] {
       let arrayCNContacts = fetchItems()
        return arrayCNContacts
    }
}
    


