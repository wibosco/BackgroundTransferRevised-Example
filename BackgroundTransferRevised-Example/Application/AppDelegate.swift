//
//  AppDelegate.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 26/03/2025.
//

import UIKit
import OSLog

class AppDelegate: NSObject, UIApplicationDelegate {
    private var completionHandler: (() -> Void)?
    private let logger = Logger(subsystem: "com.williamboles",
                                category: "appDelegate")
    
    // MARK: - UIApplicationDelegate
    
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        logger.info("App relaunched to handle events from background URLSession")
        
        self.completionHandler = completionHandler
        
        Task {
            await BackgroundDownloadService.shared.setAppPreviewCompletionHandler { [weak self] in
                Task { @MainActor in
                    self?.backgroundDownloadsComplete()
                }
            }
        }
    }
    
    private func backgroundDownloadsComplete() {
        completionHandler?()
        completionHandler = nil
    }
}
