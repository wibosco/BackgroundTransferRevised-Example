//
//  ViewModelProvider.swift
//  BackgroundTransfer-Example
//
//  Created by William Boles on 31/01/2023.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
class CatsViewModel: ObservableObject {
    enum CatsState {
        case empty
        case retrieving
        case retrieved(_ cats: [CatViewModel])
        case failed
    }
    
    @Published var state: CatsState = .empty
    
    private let networkService = NetworkService()
    
    // MARK: - Retrieval
    
    func retrieveCats() async {
        state = .retrieving
        
        do {
            let cats = try await networkService.retrieveCats()
            
            let viewModels = cats.map { CatViewModel(cat: $0) }
            state = .retrieved(viewModels)
        } catch {
            state = .failed
        }
    }
}

@MainActor
class CatViewModel: ObservableObject, Identifiable {
    enum CatState {
        case empty
        case retrieving
        case retrieved(_ image: Image)
    }
    
    @Published var state: CatState = .empty
    
    private let imageLoader = ImageLoader()
    private let cat: Cat
    
    let id: String
    
    // MARK: - Init
    
    init(cat: Cat) {
        self.cat = cat
        self.id = cat.id
    }
    
    // MARK: - Image
    
    func loadImage() async {
        state = .retrieving
        
        let uiImage = try? await imageLoader.loadImage(name: cat.id,
                                                       url: cat.url)
        
        guard let uiImage else {
            state = .empty
            return
        }
        
        state = .retrieved(Image(uiImage: uiImage))
    }
}
