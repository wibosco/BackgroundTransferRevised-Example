//
//  ImageLoader.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 11/03/2025.
//  Copyright © 2025 William Boles. All rights reserved.
//

import Foundation
import UIKit

enum ImageLoaderError: Error {
    case missingData
    case invalidImageData
}

actor ImageLoader {
    private let backgroundDownloader: BackgroundDownloadService
    
    // MARK: - Init
    
    init() {
        self.backgroundDownloader = BackgroundDownloadService()
    }
    
    // MARK: - Load
    
    func loadImage(name: String,
                   url: URL) async throws -> UIImage {
        let fileManager = FileManager.default
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectoryURL = paths[0]
        let localImageURL = documentsDirectoryURL.appendingPathComponent(name)
            
        if fileManager.fileExists(atPath: localImageURL.path) {
            let image = try await loadLocalImage(localImageURL: localImageURL)
            
            return image
        } else {
            let image = try await loadRemoteImage(remoteImageURL: url,
                                                  localImageURL: localImageURL)
            
            return image
        }
    }
    

    private func loadLocalImage(localImageURL: URL) async throws -> UIImage {
        guard let imageData = try? Data(contentsOf: localImageURL) else {
            throw ImageLoaderError.missingData
        }
        
        guard let image = UIImage(data: imageData) else {
            throw ImageLoaderError.invalidImageData
        }
        
        return image
    }
    
    private func loadRemoteImage(remoteImageURL: URL,
                                 localImageURL: URL) async throws -> UIImage {
        let url = try await backgroundDownloader.download(from: remoteImageURL,
                                                          to: localImageURL)
        let image = try await loadLocalImage(localImageURL: url)
        
        return image
    }
}
