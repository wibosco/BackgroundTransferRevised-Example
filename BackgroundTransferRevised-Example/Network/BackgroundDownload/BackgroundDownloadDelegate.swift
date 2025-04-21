//
//  BackgroundDownloadDelegator.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 16/04/2025.
//

import Foundation
import OSLog

enum BackgroundDownloadError: Error {
    case fileSystemError(_ underlyingError: Error)
    case clientError(_ underlyingError: Error)
    case serverError(_ underlyingResponse: URLResponse?)
}

final class BackgroundDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let metaStore: BackgroundDownloadMetaStore
    private let logger: Logger
    private let processingGroup: DispatchGroup
    private let urlSessionDidFinishEventsCompletionHandler: (@Sendable () -> Void)
    
    // MARK: - Init
    
    init(metaStore: BackgroundDownloadMetaStore,
         urlSessionDidFinishEventsCompletionHandler: @escaping (@Sendable () -> Void)) {
        self.metaStore = metaStore
        self.logger = Logger(subsystem: "com.williamboles",
                             category: "background.download.delegate")
        self.processingGroup = DispatchGroup()
        self.urlSessionDidFinishEventsCompletionHandler = urlSessionDidFinishEventsCompletionHandler
    }

    // MARK: - URLSessionDownloadDelegate
   
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let fromURL = downloadTask.originalRequest?.url else {
            logger.error("Unexpected nil URL for download task.")
            return
        }

        logger.info("Download request completed for: \(fromURL.absoluteString)")

        let tempLocation = FileManager.default.temporaryDirectory.appendingPathComponent(location.lastPathComponent)
        try? FileManager.default.moveItem(at: location,
                                          to: tempLocation)

        processingGroup.enter()
        metaStore.retrieveMetadata(key: fromURL.absoluteString) { [weak self] metadata in
            defer {
                self?.metaStore.removeMetadata(key: fromURL.absoluteString)
                self?.processingGroup.leave()
            }
            
            guard let metadata else {
                self?.logger.error("Unable to find existing download item for: \(fromURL.absoluteString)")
                return
            }

            guard let response = downloadTask.response as? HTTPURLResponse,
                  response.statusCode == 200 else {
                self?.logger.error("Unexpected response for: \(fromURL.absoluteString)")
                metadata.continuation?.resume(throwing: BackgroundDownloadError.serverError(downloadTask.response))
                return
            }

            self?.logger.info("Download successful for: \(fromURL.absoluteString)")

            do {
                try FileManager.default.moveItem(at: tempLocation,
                                                 to: metadata.toURL)
                metadata.continuation?.resume(returning: metadata.toURL)
            } catch {
                self?.logger.error("File system error while moving file: \(error.localizedDescription)")
                metadata.continuation?.resume(throwing: BackgroundDownloadError.fileSystemError(error))
            }
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let error = error else {
            return
        }
        
        guard let fromURL = task.originalRequest?.url else {
            logger.error("Unexpected nil URL for task.")
            return
        }

        logger.info("Download failed for: \(fromURL.absoluteString), error: \(error.localizedDescription)")

        processingGroup.enter()
        metaStore.retrieveMetadata(key: fromURL.absoluteString) { [weak self] metadata in
            defer {
                self?.metaStore.removeMetadata(key: fromURL.absoluteString)
                self?.processingGroup.leave()
            }
            
            metadata?.continuation?.resume(throwing: BackgroundDownloadError.clientError(error))
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        logger.info("Did finish events for background session")
                
        processingGroup.notify(queue: .global()) { [weak self] in
            self?.logger.info("Processing group has finished")
            
            self?.urlSessionDidFinishEventsCompletionHandler()
        }
    }
}

