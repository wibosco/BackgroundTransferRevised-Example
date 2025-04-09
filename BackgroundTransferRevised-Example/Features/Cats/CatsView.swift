//
//  ContentView.swift
//  BackgroundTransferRevised-Example
//
//  Created by William Boles on 11/03/2025.
//

import SwiftUI

struct CatsView: View {
    @StateObject var viewModel: CatsViewModel
    
    // MARK: - View
    
    var body: some View {
        NavigationStack {
            VStack {
                switch viewModel.state {
                case .empty:
                    Text("We have no cats to show you! 🙀")
                case .retrieving:
                    ProgressView("Retrieving Cats! 😺")
                case .retrieved(let cats):
                    GeometryReader { geometryReader in
                        let columns = GridItem.threeFlexibleColumns()
                        let sideLength = geometryReader.size.width / CGFloat(columns.count)
                        ScrollView {
                            LazyVGrid(columns: columns, alignment: .center, spacing: 4) {
                                ForEach(cats) { catViewModel in
                                    CatImageCell(viewModel: catViewModel)
                                        .frame(width: sideLength, height: sideLength)
                                        .task {
                                            await catViewModel.loadImage()
                                        }
                                }
                            }
                        }
                    }
                case .failed:
                    Text("Failed to retrieve Cats! 😿")
                }
            }
            .padding()
            .navigationTitle("Cats 😻")
        }
        .task {
            await viewModel.retrieveCats()
        }
    }
}

struct CatImageCell: View {
    @StateObject var viewModel: CatViewModel
    
    // MARK: - View
    
    var body: some View {
        switch viewModel.state {
        case .empty:
            Image(systemName: "photo")
        case .retrieving:
            ProgressView()
        case .retrieved(let image):
            image.resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
        }
    }
}
