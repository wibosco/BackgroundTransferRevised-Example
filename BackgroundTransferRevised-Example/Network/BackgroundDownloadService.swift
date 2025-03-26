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

class BackgroundDownloadService: NSObject, URLSessionDelegate {
    var backgroundCompletionHandler: (() -> Void)?

    static let identifier = "com.williamboles.background.download.session"

    private var session: URLSession!
    private let store = BackgroundDownloadStore()

    private let logger = Logger(subsystem: "com.williamboles", category: "BackgroundDownloadService")

    // MARK: - Singleton
    static let shared = BackgroundDownloadService()

    // MARK: - Init
    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        let configuration = URLSessionConfiguration.background(withIdentifier: BackgroundDownloadService.identifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    // MARK: - Download
    func download(from fromURL: URL, to toURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                logger.info("Scheduling download: \(fromURL.absoluteString)")

                await store.storeMetadata(from: fromURL, to: toURL, continuation: continuation)

                let downloadTask = session.downloadTask(with: fromURL)
                downloadTask.earliestBeginDate = Date().addingTimeInterval(10) // Demonstration delay
                downloadTask.resume()
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension BackgroundDownloadService: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let fromURL = downloadTask.originalRequest?.url else {
            logger.error("Unexpected nil URL for download task.")
            return
        }

        logger.info("Download request completed for: \(fromURL.absoluteString)")

        let tempLocation = FileManager.default.temporaryDirectory.appendingPathComponent(location.lastPathComponent)
        try? FileManager.default.moveItem(at: location, to: tempLocation)

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

