//
//  BackgroundDownloadProcessingStore.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 16/04/2025.
//

import Foundation

actor BackgroundDownloadProcessingStore {
    private var processingDownloads = [String: Task<Void, Never>]()
    
    // MARK: - Add
    
    func store(from fromURL: URL,
               task: Task<Void, Never>) {
        let key = fromURL.absoluteString
        
        processingDownloads[key] = task
    }
    
    // MARK: - Retrieve
    
    func retrieveAll() -> [Task<Void, Never>] {
        Array(processingDownloads.values)
    }
    
    // MARK: - Remove
    
    func remove(for forURL: URL) {
        let key = forURL.absoluteString
        
        processingDownloads[key] = nil
    }
}
