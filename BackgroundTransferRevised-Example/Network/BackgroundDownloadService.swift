//
//  BackgroundDownloadService.swift
//  BackgroundTransfer-Example
//
//  Created by William Boles on 02/05/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation
import os

enum BackgroundDownloadError: Error {
    case missingInstructionsError
    case fileSystemError(_ underlyingError: Error)
    case clientError(_ underlyingError: Error)
    case serverError(_ underlyingResponse: URLResponse?)
}

class BackgroundDownloadService: NSObject, URLSessionDelegate {
    var backgroundCompletionHandler: (() -> Void)?
    
    private var session: URLSession!
    private let store = BackgroundDownloadStore()
    
    // MARK: - Singleton
    
    static let shared = BackgroundDownloadService()
    
    // MARK: - Init
    
    override init() {
        super.init()
        
        configureSession()
    }
    
    private func configureSession() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.williamboles.background.download.session")
        configuration.sessionSendsLaunchEvents = true
        let session = URLSession(configuration: configuration,
                                 delegate: self,
                                 delegateQueue: nil)
        self.session = session
    }
    
    // MARK: - Download
    
    func download(from fromURL: URL,
                  to toURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                os_log(.info, "Scheduling to download: %{public}@", fromURL.absoluteString)
                
                await store.storeMetadata(from: fromURL,
                                          to: toURL,
                                          continuation: continuation)
                
                let downloadTask = session.downloadTask(with: fromURL)
                downloadTask.earliestBeginDate = Date().addingTimeInterval(2) // Remove this in production, the delay was added for demonstration purposes only
                downloadTask.resume()
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundDownloadService: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let fromURL = downloadTask.originalRequest?.url else {
            os_log(.error, "Unexpected nil URL")
            // Unable to call the closure here as we use fromURL as the key to retrieve the closure
            return
        }
        
        let fromURLAsString = fromURL.absoluteString
        
        os_log(.info, "Download request completed for: %{public}@", fromURLAsString)
        
        let tempLocation = FileManager.default.temporaryDirectory.appendingPathComponent(location.lastPathComponent)
        try? FileManager.default.moveItem(at: location,
                                          to: tempLocation)
        
        Task {
            defer {
                Task {
                    await store.removeMetadata(for: fromURL)
                }
            }
            
            let (toURL, continuation) = await store.retrieveMetadata(for: fromURL)
            guard let toURL else {
                os_log(.error, "Unable to find existing download item for: %{public}@", fromURLAsString)
                continuation?.resume(throwing: BackgroundDownloadError.missingInstructionsError)
                return
            }
            
            guard let response = downloadTask.response as? HTTPURLResponse,
                        response.statusCode == 200 else {
                os_log(.error, "Unexpected response for: %{public}@", fromURLAsString)
                continuation?.resume(throwing: BackgroundDownloadError.serverError(downloadTask.response))
                return
            }
            
            os_log(.info, "Download successful for: %{public}@", fromURLAsString)
            
            do {
                try FileManager.default.moveItem(at: tempLocation,
                                                 to: toURL)
                
                continuation?.resume(returning: toURL)
            } catch {
                continuation?.resume(throwing: BackgroundDownloadError.fileSystemError(error))
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
            os_log(.error, "Unexpected nil URL")
            return
        }
        
        let fromURLAsString = fromURL.absoluteString
        
        os_log(.info, "Download failed for: %{public}@", fromURLAsString)
        
        Task {
            let (_, continuation) = await store.retrieveMetadata(for: fromURL)
            continuation?.resume(throwing: BackgroundDownloadError.clientError(error))
            
            await store.removeMetadata(for: fromURL)
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            // needs to be called on the main queue
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
