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
    private var inMemoryStore = [String: BackgroundDownloadCompletion]()
    private let persistentStore = UserDefaults.standard
    
    // MARK: - Store
    
    func storeMetadata(from fromURL: URL,
                       to toURL: URL,
                       completionHandler: @escaping BackgroundDownloadCompletion) {
        inMemoryStore[fromURL.absoluteString] = completionHandler
        persistentStore.set(toURL, forKey: fromURL.absoluteString)
    }
    
    // MARK: - Retrieve
    
    func retrieveMetadata(for forURL: URL) -> (URL?, BackgroundDownloadCompletion?) {
        let key = forURL.absoluteString
        
        let toURL = persistentStore.url(forKey: key)
        let completionHandler = inMemoryStore[key]
        
        return (toURL, completionHandler)
    }
    
    // MARK: - Remove
    
    func removeMetadata(for forURL: URL) {
        let key = forURL.absoluteString
        
        inMemoryStore[key] = nil
        persistentStore.removeObject(forKey: key)
    }
}
