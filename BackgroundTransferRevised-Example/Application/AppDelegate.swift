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
    
    // MARK: - UIApplicationDelegate
    
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
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
