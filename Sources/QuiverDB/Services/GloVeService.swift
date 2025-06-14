// Copyright 2025 Wayne W Bishop. All rights reserved.
//
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License. You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
// ANY KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.

import Foundation
import Quiver
import Vapor

/// Service for converting text to vector embeddings using pre-trained GloVe word vectors.
/// GloVe (Global Vectors) provides semantic representations where similar words have similar vectors.
public final class GloVeService {
    private let embeddings: [String: [Double]]
    private let dimensions: Int
    private let logger = Logger(label: "bishop.server.quiver.package")
    
    /// The total number of words in the loaded vocabulary.
    /// Used for capacity planning and debugging embedding coverage.
    var vocabularySize: Int {
        embeddings.count
    }
        
    /// Initializes the service by loading GloVe embeddings from the bundled text file.
    /// Validates dimensional consistency and logs loading performance metrics.
    init() async throws {
        
        guard let url = Bundle.module.url(forResource: "glove.6B.50d", withExtension: "txt") else {
            throw GloVeError.fileNotFound
        }
        
        logger.info("Loading GloVe embeddings...")
        
        let content = try String(contentsOf: url, encoding: .utf8)
        let (loadedEmbeddings, detectedDimensions) = try Self.parse(content)
        
        self.embeddings = loadedEmbeddings
        self.dimensions = detectedDimensions
    }
    
    /// Parses GloVe text format into word-vector mappings with dimension validation.
    /// Returns the embeddings dictionary and detected vector dimensionality.
    private static func parse(_ content: String) throws -> ([String: [Double]], Int) {
        let logger = Logger(label: "bishop.server.quiver.package")
        
        let startTime = Date()
        var embeddings: [String: [Double]] = [:]
        var dimensions = 0
        
        for line in content.components(separatedBy: .newlines) {
            let parts = line.split(separator: " ")
            guard parts.count > 1 else { continue }
            
            let word = String(parts[0])
            let vector = parts.dropFirst().compactMap { Double($0) }
            
            if dimensions == 0 { dimensions = vector.count }
            guard vector.count == dimensions else { continue }
            
            embeddings[word] = vector
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        logger.info("GloVe parsing completed: \(embeddings.count) words with \(dimensions) dimensions in \(String(format: "%.2f", elapsed))s")
        
        return (embeddings, dimensions)
    }
    
    /// Converts text to a vector by averaging embeddings of constituent words.
    /// Unknown words are filtered out; returns zero vector if no words are found.
    func embedText(_ text: String) -> [Double] {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let wordVectors = words.compactMap { embeddings[$0] }
        
        guard !wordVectors.isEmpty else { return [Double].zeros(dimensions) }
        
        return (0..<dimensions).map { i in
            wordVectors.map { $0[i] }.mean() ?? 0.0
        }
    }
    
}

/// Errors that can occur during GloVe service initialization and operation.
enum GloVeError: Error {
    /// The GloVe embeddings file could not be found in the application bundle.
    case fileNotFound
}
