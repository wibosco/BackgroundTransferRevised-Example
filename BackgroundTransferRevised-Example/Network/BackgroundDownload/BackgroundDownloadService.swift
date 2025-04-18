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
    case fileSystemError(_ underlyingError: Error)
    case clientError(_ underlyingError: Error)
    case serverError(_ underlyingResponse: URLResponse?)
}

actor BackgroundDownloadService {
    private let session: URLSession
    private let metaStore: BackgroundDownloadMetaStore
    private let logger: Logger
    
    // MARK: - Singleton
    
    static let shared = BackgroundDownloadService()
    
    // MARK: - Init
    
    private init() {
        self.metaStore = BackgroundDownloadMetaStore()
        self.logger = Logger(subsystem: "com.williamboles",
                             category: "background.download")
        
        let delegator = BackgroundDownloadDelegator(metaStore: metaStore,
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
            
            let metaData = BackgroundDownloadMetaData(toURL: toURL,
                                                      continuation: continuation)
            metaStore.storeMetadata(metaData,
                                    key: fromURL.absoluteString)
            
            let downloadTask = session.downloadTask(with: fromURL)
            downloadTask.earliestBeginDate = Date().addingTimeInterval(10) // Remove this in production, the delay was added for demonstration purposes only
            downloadTask.resume()
        }
    }
}
