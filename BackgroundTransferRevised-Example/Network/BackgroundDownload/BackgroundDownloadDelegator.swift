//
//  BackgroundDownloadDelegator.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 16/04/2025.
//

import Foundation
import OSLog

final class BackgroundDownloadDelegator: NSObject, URLSessionDownloadDelegate {
    private let metaStore: BackgroundDownloadMetaStore
    private let logger: Logger
    private let processsingStore: BackgroundDownloadProcessingStore
    
    // MARK: - Init
    
    init(metaStore: BackgroundDownloadMetaStore,
         logger: Logger) {
        self.metaStore = metaStore
        self.logger = logger
        self.processsingStore = BackgroundDownloadProcessingStore()
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
                    await metaStore.removeMetadata(for: fromURL)
                    await processsingStore.remove(for: fromURL)
                }
            }

            let (toURL, continuation) = await metaStore.retrieveMetadata(for: fromURL)
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
            let (_, continuation) = await metaStore.retrieveMetadata(for: fromURL)
            continuation?.resume(throwing: BackgroundDownloadError.clientError(error))
            await metaStore.removeMetadata(for: fromURL)
            await metaStore.removeMetadata(for: fromURL)
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

