//
//  BackgroundTransferRevised_ExampleApp.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 11/03/2025.
//

import SwiftUI
import OSLog

@main
struct BackgroundTransferRevised_ExampleApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private let logger = Logger(subsystem: "com.williamboles",
                                category: "app")

    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            //As `CatsViewModel` will make a network request on launch which we don't want
            //when completing background transfers, we show an empty view to prevent that
            //happening. In a production app you'd want a more robust solution.
            if scenePhase == .background {
                EmptyView()
            } else {
                let catsViewModel = CatsViewModel()
                CatsView(viewModel: catsViewModel)
            }
        }
        .onChange(of: scenePhase) { (_, newPhase) in
            guard newPhase == .background else {
                return
            }
            
            logger.info("Files will be downloaded to: \(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].absoluteString)")

            //Exit app to test restoring app from a terminated state.
            Task {
                logger.info("Simulating app termination by exit(0)")

                exit(0)
            }
        }
    }
}
