import Contacts
import CloudKit

@available(macOS 12.0, *)
public class PackageContactToCloud {
    
    
        
    public let contactStore = CNContactStore()
    public var allContact : [CNContact] = []
    public var uploadContact: [CNContact] = []
        
        
    public init() {
        allContact = getContact()
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
    //MARK: - Function that save contacts form you iPhone to iCLoud
    //PS: must be set the iCloud container and privacy to contacts

    
    public func addContactsToiCloud( name: String) {
        allContact = getContact()
        //print("allContact \(allContact)")
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
                    print(data)
                case .failure(let error) :
                    print(error)
                    
                }
            }
        } else{
            queryOperation.recordFetchedBlock = { (returnedRecord) in
                guard let data = returnedRecord["data"] as? Data else {return}
                returnedItems = data
                print(data)
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
                        // print("after adding")
                        try contactStore.execute(saveRequest)
                        // print("after save")
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
    
    //MARK: - Fucntion that return arra of CNContact items from you iPhone
    
    public func seeContact() -> [CNContact] {
        return getContact()
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
            try contactStore.execute(request)
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
    


