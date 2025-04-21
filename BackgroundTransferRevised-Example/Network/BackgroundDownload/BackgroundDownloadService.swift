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
    case unknownDownload
    case fileSystemError(_ underlyingError: Error)
    case clientError(_ underlyingError: Error)
    case serverError(_ underlyingResponse: URLResponse?)
}

actor BackgroundDownloadService: NSObject {
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.williamboles.background.download.session")
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        let session = URLSession(configuration: configuration,
                                 delegate: self,
                                 delegateQueue: nil)
        
        return session
    }()
    
    private let metaStore = BackgroundDownloadMetaStore()
    private let logger = Logger(subsystem: "com.williamboles",
                                category: "background.download")
    
    private var backgroundCompletionHandler: (() -> Void)?
    
    // MARK: - Singleton
    
    static let shared = BackgroundDownloadService()
    
    // MARK: - Download
    
    func download(from fromURL: URL,
                  to toURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            logger.info("Scheduling download: \(fromURL.absoluteString)")
            
            // TODO: Investigate removing metastore in favour of two properties
            Task {
                let metadata = BackgroundDownloadMetadata(toURL: toURL,
                                                          continuation: continuation)
                await metaStore.storeMetadata(metadata,
                                              key: fromURL.absoluteString)
            }
                        
            let downloadTask = session.downloadTask(with: fromURL)
            downloadTask.earliestBeginDate = Date().addingTimeInterval(10) // Remove this in production, the delay was added for demonstration purposes only
            downloadTask.resume()
        }
    }
    
    // MARK: - CompletionHandler
    
    func saveBackgroundCompletionHandler(_ backgroundCompletionHandler: @escaping (() -> Void)) {
        self.backgroundCompletionHandler = backgroundCompletionHandler
    }
    
    private func backgroundDownloadsComplete() {
        logger.info("Triggering background session completion handler")
        
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
    
    // MARK: Download
    
    private func downloadFinished(task: URLSessionDownloadTask,
                                  downloadedTo location: URL) async {
        guard let fromURL = task.originalRequest?.url else {
            logger.error("Unexpected nil URL for download task.")
            return
        }
        
        logger.info("Download request completed for: \(fromURL.absoluteString)")
        
        defer {
            Task {
                await metaStore.removeMetadata(key: fromURL.absoluteString)
            }
        }
        
        do {
            let metadata = try await metaStore.retrieveMetadata(key: fromURL.absoluteString)
            
            guard let response = task.response as? HTTPURLResponse,
                  response.statusCode == 200 else {
                logger.error("Unexpected response for: \(fromURL.absoluteString)")
                metadata.continuation?.resume(throwing: BackgroundDownloadError.serverError(task.response))
                return
            }
            
            logger.info("Download successful for: \(fromURL.absoluteString)")
            
            do {
                try FileManager.default.moveItem(at: location,
                                                 to: metadata.toURL)
                metadata.continuation?.resume(returning: metadata.toURL)
            } catch {
                logger.error("File system error while moving file: \(error.localizedDescription)")
                metadata.continuation?.resume(throwing: BackgroundDownloadError.fileSystemError(error))
            }
        } catch {
            logger.error("Unable to find existing download for: \(fromURL.absoluteString)")
        }
    }
    
    private func downloadComplete(task: URLSessionTask,
                                  withError error: Error?) async {
        guard let error = error else {
            return
        }
        
        guard let fromURL = task.originalRequest?.url else {
            logger.error("Unexpected nil URL for task.")
            return
        }
        
        logger.info("Download failed for: \(fromURL.absoluteString), error: \(error.localizedDescription)")
        
        do {
            defer {
                Task {
                    await metaStore.removeMetadata(key: fromURL.absoluteString)
                }
            }
            
            let metadata = try await metaStore.retrieveMetadata(key: fromURL.absoluteString)
            
            metadata.continuation?.resume(throwing: BackgroundDownloadError.clientError(error))
            
        } catch {
            logger.error("Unable to find existing download for: \(fromURL.absoluteString)")
        }
    }
    
    private func backgroundDownloadsComplete() async {
        logger.info("All background downloads completed")
        
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
}

extension BackgroundDownloadService: URLSessionDownloadDelegate {
    // MARK: - URLSessionDownloadDelegate
    
    nonisolated
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // File needs moved before method exist as it only guaranteed to exist until that point
        let tempLocation = FileManager.default.temporaryDirectory.appendingPathComponent(location.lastPathComponent)
        try? FileManager.default.moveItem(at: location,
                                          to: tempLocation)
        
        Task {
            await downloadFinished(task: downloadTask,
                                   downloadedTo: tempLocation)
        }
    }
    
    nonisolated
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        Task {
            await downloadComplete(task: task,
                                   withError: error)
        }
    }
    
    nonisolated
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task {
            await backgroundDownloadsComplete()
        }
    }
}
