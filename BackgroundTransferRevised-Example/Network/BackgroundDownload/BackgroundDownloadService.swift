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
    case cancelled
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
    
    private var activeDownloads = [String: URLSessionDownloadTask]()
    private var inMemoryStore = [String: CheckedContinuation<URL, Error>]()
    private let persistentStore = UserDefaults.standard
    private let logger = Logger(subsystem: "com.williamboles",
                                category: "background.download")
    
    private var backgroundCompletionHandler: (() -> Void)?
    
    // MARK: - Singleton
    
    static let shared = BackgroundDownloadService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Download
    
    func download(from fromURL: URL,
                  to toURL: URL) async throws -> URL {
        if activeDownloads[fromURL.absoluteString] != nil {
            // cancel existing downloads for this URL
            cancelDownload(forURL: fromURL)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            logger.info("Scheduling download: \(fromURL.absoluteString)")
            
            inMemoryStore[fromURL.absoluteString] = continuation
            persistentStore.set(toURL, forKey: fromURL.absoluteString)
                        
            let downloadTask = session.downloadTask(with: fromURL)
            activeDownloads[fromURL.absoluteString] = downloadTask
            downloadTask.earliestBeginDate = Date().addingTimeInterval(10) // Remove this in production, the delay was added for demonstration purposes only
            downloadTask.resume()
        }
    }
    
    func cancelDownload(forURL url: URL) {
        logger.info("Cancelling download for: \(url.absoluteString)")
        
        inMemoryStore[url.absoluteString]?.resume(throwing: BackgroundDownloadError.cancelled)
        activeDownloads[url.absoluteString]?.cancel()
        
        cleanUpDownload(forURL: url)
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
            cleanUpDownload(forURL: fromURL)
        }
        
        guard let toURL = persistentStore.url(forKey: fromURL.absoluteString) else {
            logger.error("Unable to find existing download for: \(fromURL.absoluteString)")
            return
        }
        
        let continuation = inMemoryStore[fromURL.absoluteString]
        
        guard let response = task.response as? HTTPURLResponse,
              response.statusCode == 200 else {
            logger.error("Unexpected response for: \(fromURL.absoluteString)")
            continuation?.resume(throwing: BackgroundDownloadError.serverError(task.response))
            return
        }
        
        logger.info("Download successful for: \(fromURL.absoluteString)")
        
        do {
            try FileManager.default.moveItem(at: location,
                                             to: toURL)
            continuation?.resume(returning: toURL)
        } catch {
            logger.error("File system error while moving file: \(error.localizedDescription)")
            continuation?.resume(throwing: BackgroundDownloadError.fileSystemError(error))
        }
    }
    
    private func downloadComplete(task: URLSessionTask,
                                  withError error: Error?) async {
        guard let error = error else {
            return
        }
        
        if let error = error as? URLError,
           error.code == .cancelled {
            return
        }
        
        guard let fromURL = task.originalRequest?.url else {
            logger.error("Unexpected nil URL for task.")
            return
        }
        
        logger.info("Download failed for: \(fromURL.absoluteString), error: \(error.localizedDescription)")
        
        let continuation = inMemoryStore[fromURL.absoluteString]
        
        continuation?.resume(throwing: BackgroundDownloadError.clientError(error))
        
        cleanUpDownload(forURL: fromURL)
    }
    
    private func backgroundDownloadsComplete() async {
        logger.info("All background downloads completed")
        
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
    
    private func cleanUpDownload(forURL url: URL) {
        inMemoryStore.removeValue(forKey: url.absoluteString)
        persistentStore.removeObject(forKey: url.absoluteString)
        activeDownloads.removeValue(forKey: url.absoluteString)
        
        persistentStore.synchronize()
    }
}

extension BackgroundDownloadService: URLSessionDownloadDelegate {
    // MARK: - URLSessionDownloadDelegate
    
    nonisolated
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // File needs moved before method exits, as file is only guaranteed to exist during this method
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
