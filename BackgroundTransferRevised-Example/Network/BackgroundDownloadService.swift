//
//  BackgroundDownloadService.swift
//  BackgroundTransfer-Example
//
//  Created by William Boles on 26/03/2025.
//  Copyright © 2025 William Boles. All rights reserved.
//

import Foundation
import OSLog

enum BackgroundDownloadError: Error {
    case missingInstructionsError
    case fileSystemError(_ underlyingError: Error)
    case clientError(_ underlyingError: Error)
    case serverError(_ underlyingResponse: URLResponse?)
}

final class BackgroundDownloadService {
    var backgroundCompletionHandler: (() -> Void)? // TODO: Remove this as it has now been moved to delegator

    private static let identifier = "com.williamboles.background.download.session"
    private let session: URLSession
    private let store: BackgroundDownloadStore
    private let logger: Logger

    // MARK: - Singleton
    
    static let shared = BackgroundDownloadService()

    // MARK: - Init
    
    private init() {
        self.store = BackgroundDownloadStore()
        self.logger = Logger(subsystem: "com.williamboles",
                             category: "BackgroundDownload")
        
        let delegator = BackgroundDownloadDelegator(store: store,
                                                    logger: logger)
        let configuration = URLSessionConfiguration.background(withIdentifier: BackgroundDownloadService.identifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        self.session = URLSession(configuration: configuration,
                                  delegate: delegator,
                                  delegateQueue: nil)
    }

    // MARK: - Download
    
    func download(from fromURL: URL, to toURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            logger.info("Scheduling download: \(fromURL.absoluteString)")
            
            Task {
                await store.storeMetadata(from: fromURL,
                                          to: toURL,
                                          continuation: continuation)
                
                logger.info("Metadata stored for: \(fromURL.absoluteString)")
            }
            
            let downloadTask = session.downloadTask(with: fromURL)
            downloadTask.resume()
            
            logger.info("Download resumed for: \(fromURL.absoluteString)")
        }
    }
}

final class BackgroundDownloadDelegator: NSObject, URLSessionDownloadDelegate {
    var backgroundCompletionHandler: (() -> Void)? // TODO: Should this be reversed so that the app delegate is called instead?
    
    private let store: BackgroundDownloadStore
    
    private let logger: Logger
    
    // MARK: - Init
    
    init(store: BackgroundDownloadStore,
         logger: Logger) {
        self.store = store
        self.logger = logger
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
        
        logger.info("Moved file to temporary location: \(tempLocation) for: \(fromURL.absoluteString)")

        Task {
            defer {
                Task {
                    await store.removeMetadata(for: fromURL)
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
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error, let fromURL = task.originalRequest?.url else {
            return
        }

        logger.info("Download failed for: \(fromURL.absoluteString), error: \(error.localizedDescription)")

        Task {
            let (_, continuation) = await store.retrieveMetadata(for: fromURL)
            continuation?.resume(throwing: BackgroundDownloadError.clientError(error))
            await store.removeMetadata(for: fromURL)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

