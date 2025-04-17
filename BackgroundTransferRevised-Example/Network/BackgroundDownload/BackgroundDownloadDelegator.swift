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
    private let taskStore: BackgroundDownloadTaskStore
    private let logger: Logger
    
    // MARK: - Init
    
    init(metaStore: BackgroundDownloadMetaStore,
         logger: Logger) {
        self.metaStore = metaStore
        self.logger = logger
        self.taskStore = BackgroundDownloadTaskStore()
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
        try? FileManager.default.moveItem(at: location, to: tempLocation)

        let processingTask = Task {
            defer {
                cleanUpDownload(forURL: fromURL)
            }

            let metaData = await metaStore.retrieveMetadata(key: fromURL.absoluteString)
            guard let metaData else {
                logger.error("Unable to find existing download item for: \(fromURL.absoluteString)")
                return
            }

            guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 else {
                logger.error("Unexpected response for: \(fromURL.absoluteString)")
                metaData.continuation?.resume(throwing: BackgroundDownloadError.serverError(downloadTask.response))
                return
            }

            logger.info("Download successful for: \(fromURL.absoluteString)")

            do {
                try FileManager.default.moveItem(at: tempLocation,
                                                 to: metaData.toURL)
                metaData.continuation?.resume(returning: metaData.toURL)
            } catch {
                logger.error("File system error while moving file: \(error.localizedDescription)")
                metaData.continuation?.resume(throwing: BackgroundDownloadError.fileSystemError(error))
            }
        }
        
        // TODO: Update processing to use a serial queue
        Task {
            await taskStore.storeTask(processingTask,
                                             key: fromURL.absoluteString)
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let error = error,
              let fromURL = task.originalRequest?.url else {
            return
        }

        logger.info("Download failed for: \(fromURL.absoluteString), error: \(error.localizedDescription)")

        let processingTask = Task {
            defer {
                cleanUpDownload(forURL: fromURL)
            }
            
            let metaData = await metaStore.retrieveMetadata(key: fromURL.absoluteString)
            metaData?.continuation?.resume(throwing: BackgroundDownloadError.clientError(error))
        }
        
        // TODO: Update processing to use a serial queue
        Task {
            await taskStore.storeTask(processingTask,
                                             key: fromURL.absoluteString)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        logger.info("Did finish events for background session")
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                for task in await taskStore.retrieveAll() {
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
    
    private func cleanUpDownload(forURL url: URL) {
        Task {
            let key = url.absoluteString
            
            await metaStore.removeMetadata(key: key)
            await taskStore.removeTask(key: key)
        }
    }
}

