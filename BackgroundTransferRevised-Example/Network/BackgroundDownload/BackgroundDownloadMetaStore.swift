//
//  BackgroundDownloadStore.swift
//  BackgroundTransfer-Example
//
//  Created by William Boles on 26/03/2025.
//  Copyright © 2025 William Boles. All rights reserved.
//

import Foundation

struct BackgroundDownloadMetaData {
    let toURL: URL
    let continuation: CheckedContinuation<URL, Error>?
}

actor BackgroundDownloadMetaStore {
    private var inMemoryStore: [String: CheckedContinuation<URL, Error>]
    private let persistentStore: UserDefaults
    
    // MARK: - Init
    
    init() {
        self.inMemoryStore = [String: CheckedContinuation<URL, Error>]()
        self.persistentStore = UserDefaults.standard
    }
    
    // MARK: - Store
    
    func storeMetadata(_ metaData: BackgroundDownloadMetaData,
                       key: String) {
        inMemoryStore[key] = metaData.continuation
        persistentStore.set(metaData.toURL, forKey: key)
    }
    
    // MARK: - Retrieve
    
    func retrieveMetadata(key: String) -> BackgroundDownloadMetaData? {
        guard let toURL = persistentStore.url(forKey: key) else {
            return nil
        }
        
        let continuation = inMemoryStore[key]
        
        let metaData = BackgroundDownloadMetaData(toURL: toURL,
                                                  continuation: continuation)
        
        return metaData
    }
    
    // MARK: - Remove
    
    func removeMetadata(key: String) {
        inMemoryStore.removeValue(forKey: key)
        persistentStore.removeObject(forKey: key)
    }
}
