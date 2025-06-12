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
import Logging

/// Simple vector database that stores vectors with basic CRUD operations and JSON persistence.
public actor VectorStore {

    private var vectors: [String: VectorRecord] = [:]
    private let embeddingService: GloVeService
    private let dataFilePath: String = "vectors.json"
    private let logger = Logger(label: "bishop.server.quiver.package")
    
    /// Initialize with a GloVe service and load existing vectors from file.
    init(embeddingService: GloVeService) async throws {
        self.embeddingService = embeddingService
        try await loadFromFile()
    }
    
    /// Get total number of stored vectors.
    func count() async -> Int {
        return vectors.count
    }
    
    // MARK: - Basic Upsert Operations
    
    /// Store a vector with metadata and save to file.
    func upsert(id: String, vector: [Double], text: String, metadata: [String: String]) async throws {
        let record = VectorRecord(id: id, vector: vector, text: text, metadata: metadata, timestamp: Date())
        vectors[id] = record
        try await saveToFile()
    }
    
    /// Store text by converting it to a vector using GloVe and save to file.
    func upsertText(id: String, text: String, metadata: [String: String]) async throws {
        let vector = embeddingService.embedText(text)
        try await upsert(id: id, vector: vector, text: text, metadata: metadata)
    }
    
    /// Get a vector by identifier.
    func get(id: String) async throws -> VectorRecord? {
        return vectors[id]
    }
    
    // MARK: Basic Query Operations
    
    /// Find similar vectors using cosine similarity.
    func query(vector: [Double], topK: Int = 5) async throws -> [VectorMatch] {
        var matches: [VectorMatch] = []
        
        // Calculate similarity with each stored vector
        for (id, record) in vectors {
            let similarity = vector.cosineOfAngle(with: record.vector)
            matches.append(VectorMatch(id: id, score: similarity, text: record.text, metadata: record.metadata))
        }
        
        // Sort by similarity (highest first) and return top K
        return matches
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0 }
    }


    /// Search for similar text using semantic similarity.
    func queryText(text: String, topK: Int = 10) async throws -> [VectorMatch] {
        let queryVector = embeddingService.embedText(text)
        return try await self.query(vector: queryVector, topK: topK)
    }
    
    ///Returns all vector records
    func queryAll() async throws -> [VectorRecord] {
        return Array(vectors.values)
    }
    
    //MARK: Basic Delete Operations
    
    /// Delete a vector based on its identifier and save to file.
    func removeAt(id: String) async throws -> Bool {
        let existed = vectors.removeValue(forKey: id) != nil
        if existed {
            try await saveToFile()
        }
        return existed
    }
    
    
    // Delete all vector records
    func removeAll() async throws {
        vectors.removeAll()
        try await saveToFile()
    }
    
    
    // MARK: - Basic Persistence
    
    /// Save all vectors to JSON file.
    private func saveToFile() async throws {
        
        do {
            let records = Array(vectors.values)
            let data = try JSONEncoder().encode(records)
            try data.write(to: URL(fileURLWithPath: dataFilePath))
            logger.debug("Successfully saved \(records.count) vectors")
            
        } catch {
            logger.error("Failed to save vectors: \(error)")
        }
    }
    
    /// Load vectors from JSON file at startup.
    private func loadFromFile() async throws {
        
        guard FileManager.default.fileExists(atPath: dataFilePath) else {
            logger.info("No existing vectors file found, starting with empty database")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: dataFilePath))
            let records = try JSONDecoder().decode([VectorRecord].self, from: data)
            
            for record in records {
                vectors[record.id] = record
            }
            
            logger.info("Loaded \(records.count) vectors")
            
        } catch {
            logger.error("Failed to load vectors, starting with empty database: \(error)")
        }
    }
    
    // MARK: - Batch Processing
    
    /// Provides process for uploading multiple documents in JSONL format
    func batchUpsertTexts(_ documents: [(id: String, text: String, metadata: [String: String])]) async throws -> BatchResult {
        var successes = 0
        let failures: [String] = []
         
        for (id, text, metadata) in documents {
            // Process immediately - simpler than async queues
            let vector = embeddingService.embedText(text)
            let record = VectorRecord(id: id, vector: vector, text: text, metadata: metadata, timestamp: Date())
            vectors[id] = record
            successes += 1
         }
         
         try await saveToFile()
         return BatchResult(successful: successes, failed: failures.count, errors: failures)
    }
     
}
