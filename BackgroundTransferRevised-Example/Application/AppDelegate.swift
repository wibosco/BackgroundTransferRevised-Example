//
//  AppDelegate.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 26/03/2025.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    // MARK: - Background
    
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
//        BackgroundDownloadService.shared.backgroundCompletionHandler = completionHandler
    }
}
