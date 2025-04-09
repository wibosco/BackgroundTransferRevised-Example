//
//  BackgroundDownloadStore.swift
//  BackgroundTransfer-Example
//
//  Created by William Boles on 26/03/2025.
//  Copyright © 2025 William Boles. All rights reserved.
//

import Foundation

actor BackgroundDownloadStore {
    private var inMemoryStore: [String: CheckedContinuation<URL, Error>]
    private let persistentStore: UserDefaults
    
    // MARK: - Singleton
    
    static let shared = BackgroundDownloadStore()
    
    // MARK: - Init
    
    private init() {
        self.inMemoryStore = [String: CheckedContinuation<URL, Error>]()
        self.persistentStore = UserDefaults.standard
    }
    
    // MARK: - Store
    
    func storeMetadata(from fromURL: URL,
                       to toURL: URL,
                       continuation: CheckedContinuation<URL, Error>) {
        let key = fromURL.absoluteString
        
        inMemoryStore[key] = continuation
        persistentStore.set(toURL, forKey: key)
    }
    
    // MARK: - Retrieve
    
    func retrieveMetadata(for forURL: URL) -> (URL?, CheckedContinuation<URL, Error>?) {
        let key = forURL.absoluteString
        
        let toURL = persistentStore.url(forKey: key)
        let continuation = inMemoryStore[key]
        
        return (toURL, continuation)
    }
    
    // MARK: - Remove
    
    func removeMetadata(for forURL: URL) {
        let key = forURL.absoluteString
        
        inMemoryStore.removeValue(forKey: key)
        persistentStore.removeObject(forKey: key)
    }
}
