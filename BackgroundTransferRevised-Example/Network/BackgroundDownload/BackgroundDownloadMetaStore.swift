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

final class BackgroundDownloadMetaStore: @unchecked Sendable {
    private var inMemoryStore: [String: CheckedContinuation<URL, Error>]
    private let persistentStore: UserDefaults
    private let queue: DispatchQueue
    
    // MARK: - Init
    
    init() {
        self.inMemoryStore = [String: CheckedContinuation<URL, Error>]()
        self.persistentStore = UserDefaults.standard
        self.queue = DispatchQueue(label: "com.williamboles.background.download.service",
                                   qos: .userInitiated,
                                   attributes: .concurrent)
    }
    
    // MARK: - Store
    
    func storeMetadata(_ metadata: BackgroundDownloadMetadata,
                       key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.inMemoryStore[key] = metadata.continuation
            self?.persistentStore.set(metadata.toURL, forKey: key)
        }
    }
    
    // MARK: - Retrieve
    
    func retrieveMetadata(key: String,
                          completionHandler: @escaping (@Sendable (BackgroundDownloadMetadata?) -> ())) {
        return queue.async { [weak self] in
            guard let toURL = self?.persistentStore.url(forKey: key) else {
                completionHandler(nil)
                return
            }
            
            let continuation = self?.inMemoryStore[key]
            
            let metadata = BackgroundDownloadMetadata(toURL: toURL,
                                                      continuation: continuation)
            
            completionHandler(metadata)
        }
    }
    
    // MARK: - Remove
    
    func removeMetadata(key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.inMemoryStore.removeValue(forKey: key)
            self?.persistentStore.removeObject(forKey: key)
        }
    }
}
