//
//  AppDelegate.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 26/03/2025.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    private var backgroundCompletionHandler: (() -> Void)?
    
    // MARK: - Background
    
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        self.backgroundCompletionHandler = completionHandler
    }
    
    func backgroundDownloadsComplete() {
        self.backgroundCompletionHandler?()
        self.backgroundCompletionHandler = nil
    }
}
