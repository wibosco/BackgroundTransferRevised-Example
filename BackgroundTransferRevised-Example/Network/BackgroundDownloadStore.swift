//
//  BackgroundDownloadStore.swift
//  BackgroundTransfer-Example
//
//  Created by William Boles on 02/05/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

typealias BackgroundDownloadCompletion = (_ result: Result<URL, Error>) -> ()

actor BackgroundDownloadStore {
    private var inMemoryStore = [String: CheckedContinuation<URL, Error>]()
    private let persistentStore = UserDefaults.standard
    
    // MARK: - Store
    
    func storeMetadata(from fromURL: URL,
                       to toURL: URL,
                       continuation: CheckedContinuation<URL, Error>) {
        inMemoryStore[fromURL.absoluteString] = continuation
        persistentStore.set(toURL, forKey: fromURL.absoluteString)
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
        
        inMemoryStore[key] = nil
        persistentStore.removeObject(forKey: key)
    }
}
