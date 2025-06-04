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

public final class GloVeService {
    private let embeddings: [String: [Double]]
    private let dimensions: Int
    
    init(filePath: String) async throws {
        let content = try String(contentsOfFile: filePath)
        var loadedEmbeddings: [String: [Double]] = [:]
        var detectedDimensions = 0
        
        for line in content.components(separatedBy: .newlines) {
            let parts = line.split(separator: " ")
            guard parts.count > 1 else { continue }
            
            let word = String(parts[0])
            let vector = parts.dropFirst().compactMap { Double($0) }
            
            if detectedDimensions == 0 {
                detectedDimensions = vector.count
            }
            
            guard vector.count == detectedDimensions else { continue }
            loadedEmbeddings[word] = vector
        }
        
        self.embeddings = loadedEmbeddings
        self.dimensions = detectedDimensions
        
        // Validate all embeddings have consistent dimensions using new Quiver function
        let allVectors = Array(loadedEmbeddings.values)
        guard allVectors.areValidVectorDimensions() else {
            throw GloVeError.inconsistentDimensions
        }
    }
    
    /// Get vocabulary size
    var vocabularySize: Int {
        return embeddings.count
    }
    
    //Get dimensions
    var embeddingDimensions: Int {
        return dimensions
    }
    
    /// Convert text to vector using new Quiver averaged() function
    func embedText(_ text: String) -> [Double] {
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        let wordVectors = words.compactMap { word in embeddings[word] }
        
        guard !wordVectors.isEmpty else {
            // Return zero vector if no words found
            return [Double].zeros(dimensions)
        }
        
        // Use new Quiver instance method for safe vector averaging
        return wordVectors.averaged() ?? [Double].zeros(dimensions)
    }
    
    /// Get embedding for a single word
    func embedWord(_ word: String) -> [Double]? {
        return embeddings[word.lowercased()]
    }
    
}

enum GloVeError: Error {
    case inconsistentDimensions
    case fileNotFound
}
