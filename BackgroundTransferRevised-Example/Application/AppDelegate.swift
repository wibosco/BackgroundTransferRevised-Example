//
//  AppDelegate.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 26/03/2025.
//

import UIKit
import OSLog

class AppDelegate: NSObject, UIApplicationDelegate {
    // MARK: - UIApplicationDelegate
    
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        Task {
            await BackgroundDownloadService.shared.saveBackgroundCompletionHandler(completionHandler)
        }
    }
}
