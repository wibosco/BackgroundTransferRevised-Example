//
//  BackgroundDownloadStore.swift
//  BackgroundTransfer-Example
//
//  Created by William Boles on 26/03/2025.
//  Copyright © 2025 William Boles. All rights reserved.
//

import Foundation

struct BackgroundDownloadMetadata {
    let toURL: URL
    let continuation: CheckedContinuation<URL, Error>?
}

actor BackgroundDownloadMetaStore {
    private var inMemoryStore = [String: CheckedContinuation<URL, Error>]()
    private let persistentStore =  UserDefaults.standard
    
    // MARK: - Store
    
    func storeMetadata(_ metadata: BackgroundDownloadMetadata,
                       key: String) {
        inMemoryStore[key] = metadata.continuation
        persistentStore.set(metadata.toURL, forKey: key)
    }
    
    func retrieveMetadata(key: String) throws -> BackgroundDownloadMetadata {
        guard let toURL = persistentStore.url(forKey: key) else {
            throw BackgroundDownloadError.unknownDownload
        }
        
        let continuation = inMemoryStore[key]
        
        let metadata = BackgroundDownloadMetadata(toURL: toURL,
                                                  continuation: continuation)
        
        return metadata
    }
    
    // MARK: - Remove
    
    func removeMetadata(key: String) {
        inMemoryStore.removeValue(forKey: key)
        persistentStore.removeObject(forKey: key)
    }
}
