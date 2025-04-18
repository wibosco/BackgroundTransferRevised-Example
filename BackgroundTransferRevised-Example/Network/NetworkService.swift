//
//  NetworkService.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 11/03/2025.
//  Copyright © 2025 William Boles. All rights reserved.
//

import Foundation
import OSLog

struct Cat: Decodable, Equatable {
    let id: String
    let url: URL
}

enum NetworkServiceError: Error {
    case networkError
    case decodingErrror
}

actor NetworkService {
    private let logger: Logger
    
    // MARK: - Init
    
    init() {
        self.logger = Logger(subsystem: "com.williamboles",
                             category: "NetworkService")
    }
    
    // MARK: - Cats
    
    func retrieveCats() async throws -> [Cat] {
        let APIKey = "live_yzNvM2rsrxvWpSwtsAWzbSiGoGW175yNLmnO1u5Fh5GMFxbZ9l4C01t9BcP2v6WQ"
        
        assert(!APIKey.isEmpty, "Replace this empty string with your API key from: https://thecatapi.com/")
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "50")
        let sizeQueryItem = URLQueryItem(name: "size", value: "thumb")
        
        let queryItems = [limitQueryItem, sizeQueryItem]
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.thecatapi.com"
        components.path = "/v1/images/search"
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw NetworkServiceError.networkError
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.addValue(APIKey, forHTTPHeaderField: "x-api-key")
        
        logger.info("Retrieving cats...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
               throw NetworkServiceError.networkError
            }
            
            guard let cats = try? JSONDecoder().decode([Cat].self, from: data) else {
                throw NetworkServiceError.decodingErrror
            }
            
            logger.info("Cats successfully retrieved!")
            
           return cats
        } catch let error as NetworkServiceError {
            throw error
        } catch {
            throw NetworkServiceError.networkError
        }
    }
}
