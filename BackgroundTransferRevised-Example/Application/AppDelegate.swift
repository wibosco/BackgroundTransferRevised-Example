//
//  AppDelegate.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 26/03/2025.
//

import UIKit
import OSLog

class AppDelegate: NSObject, UIApplicationDelegate {
    static var shared: AppDelegate?
    
    private var backgroundCompletionHandler: (() -> Void)?
    private let logger = Logger(subsystem: "com.williamboles",
                                category: "appDelegate")
                    
    // MARK: - Background
    
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        self.backgroundCompletionHandler = completionHandler
    }
    
    func backgroundDownloadsComplete() {
        logger.info("Triggering background session completion handler")
        
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
}
