//
//  BackgroundDownloadTaskStore.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 16/04/2025.
//

import Foundation

actor BackgroundDownloadTaskStore {
    private var tasks = [String: Task<Void, Never>]()
    
    // MARK: - Add
    
    func storeTask(_ task: Task<Void, Never>,
                   key: String) {
        tasks[key] = task
    }
    
    // MARK: - Retrieve
    
    func retrieveAll() -> [Task<Void, Never>] {
        Array(tasks.values)
    }
    
    // MARK: - Remove
    
    func removeTask(key: String) {
        tasks[key] = nil
    }
}
