//
//  BackgroundDownloadService.swift
//  BackgroundTransfer-Example
//
//  Created by William Boles on 26/03/2025.
//  Copyright © 2025 William Boles. All rights reserved.
//

import Foundation
import OSLog
import UIKit
import SwiftUI

enum BackgroundDownloadError: Error {
    case missingInstructionsError
    case fileSystemError(_ underlyingError: Error)
    case clientError(_ underlyingError: Error)
    case serverError(_ underlyingResponse: URLResponse?)
}

actor BackgroundDownloadService {
    private let session: URLSession
    private let store: BackgroundDownloadStore
    private let logger: Logger
    
    // MARK: - Init
    
    init() {
        self.store = BackgroundDownloadStore.shared
        self.logger = Logger(subsystem: "com.williamboles",
                             category: "background.download")
        
        let delegator = BackgroundDownloadDelegator(store: store,
                                                    logger: logger)
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.williamboles.background.download.session")
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        self.session = URLSession(configuration: configuration,
                                  delegate: delegator,
                                  delegateQueue: nil)
    }

    // MARK: - Download
    
    func download(from fromURL: URL,
                  to toURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            logger.info("Scheduling download: \(fromURL.absoluteString)")
            
            Task { [store, fromURL, toURL, continuation] in
                await store.storeMetadata(from: fromURL,
                                          to: toURL,
                                          continuation: continuation)
            }

            let downloadTask = session.downloadTask(with: fromURL)
            downloadTask.earliestBeginDate = Date().addingTimeInterval(10) // Remove this in production, the delay was added for demonstration purposes only
            downloadTask.resume()
        }
    }
}

actor ProcessingDownloadsStore {
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

final class BackgroundDownloadDelegator: NSObject, URLSessionDownloadDelegate {
    private let store: BackgroundDownloadStore
    private let logger: Logger
    private let processsingStore: ProcessingDownloadsStore
    
    // MARK: - Init
    
    init(store: BackgroundDownloadStore,
         logger: Logger,
         processsingStore: ProcessingDownloadsStore = ProcessingDownloadsStore()) {
        self.store = store
        self.logger = logger
        self.processsingStore = processsingStore
    }

    // MARK: - URLSessionDownloadDelegate
   
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let fromURL = downloadTask.originalRequest?.url else {
            logger.error("Unexpected nil URL for download task.")
            return
        }

        logger.info("Download request completed for: \(fromURL.absoluteString)")

        let tempLocation = FileManager.default.temporaryDirectory.appendingPathComponent(location.lastPathComponent)
        try? FileManager.default.moveItem(at: location, to: tempLocation)

        let processingTask = Task {
            defer {
                Task {
                    await store.removeMetadata(for: fromURL)
                    await processsingStore.remove(for: fromURL)
                }
            }

            let (toURL, continuation) = await store.retrieveMetadata(for: fromURL)
            guard let toURL else {
                logger.error("Unable to find existing download item for: \(fromURL.absoluteString)")
                continuation?.resume(throwing: BackgroundDownloadError.missingInstructionsError)
                return
            }

            guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 else {
                logger.error("Unexpected response for: \(fromURL.absoluteString)")
                continuation?.resume(throwing: BackgroundDownloadError.serverError(downloadTask.response))
                return
            }

            logger.info("Download successful for: \(fromURL.absoluteString)")

            do {
                try FileManager.default.moveItem(at: tempLocation, to: toURL)
                continuation?.resume(returning: toURL)
            } catch {
                logger.error("File system error while moving file: \(error.localizedDescription)")
                continuation?.resume(throwing: BackgroundDownloadError.fileSystemError(error))
            }
        }
        
        // TODO: Update processing to use a serial queue
        Task {
            await processsingStore.store(from: fromURL,
                                         task: processingTask)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error, let fromURL = task.originalRequest?.url else {
            return
        }

        logger.info("Download failed for: \(fromURL.absoluteString), error: \(error.localizedDescription)")

        let processingTask = Task {
            let (_, continuation) = await store.retrieveMetadata(for: fromURL)
            continuation?.resume(throwing: BackgroundDownloadError.clientError(error))
            await store.removeMetadata(for: fromURL)
            await store.removeMetadata(for: fromURL)
        }
        
        // TODO: Update processing to use a serial queue
        Task {
            await processsingStore.store(from: fromURL,
                                         task: processingTask)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        logger.info("Did finish events for background session")
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                for task in await processsingStore.retrieveAll() {
                    group.addTask {
                        await task.value
                    }
                }
                
                await group.waitForAll()
                
                logger.info("All tasks in group completed")
                
                await MainActor.run {
                    guard let appDelegate = AppDelegate.shared else {
                        logger.error("App delegate is nil")
                        return
                    }
                    
                    appDelegate.backgroundDownloadsComplete()
                }
            }
        }
    }
}

