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

/*
    TODO: Build Vapor routes for VectorStore
    TODO: Implement Swift-Otel for metrics
    TODO: Write, test and deploy and implement Docker 
    TODO: Write DocC documentation
 */

/// Simple vector database that stores vectors with basic CRUD operations and JSON persistence.
public actor VectorStore {

    private var vectors: [String: VectorRecord] = [:]
    private let embeddingService: GloVeService
    private let dataFilePath: String
    
    private let logger = Logger(label: "bishop.server.quiver.package")
    
    /// Initialize with a GloVe service and optional custom data file path.
    init(embeddingService: GloVeService, dataFilePath: String = "vectors.json") async throws {

        self.embeddingService = embeddingService
        self.dataFilePath = dataFilePath
        try await loadFromFile()
    }
    
    // MARK: - Synchronous Properties and Simple State Access
    
    /// Total number of stored vectors
    var count: Int {
        vectors.count
    }
    
    /// Whether the store contains any vectors
    var isEmpty: Bool {
        vectors.isEmpty
    }
    
    /// Check if a vector exists without retrieving it
    func exists(id: String) -> Bool {
        vectors[id] != nil
    }
    
    // MARK: - Asynchronous Upsert Operations
    
    /// Store a vector with metadata and save to file
    func upsert(id: String, vector: [Double], text: String, metadata: [String: String] = [:]) async throws {

        let record = VectorRecord(id: id, vector: vector, text: text, metadata: metadata, timestamp: Date())
        vectors[id] = record
        try await saveToFile()
    }
    
    /// Store text by converting it to a vector using GloVe and save to file
    func upsertText(id: String, text: String, metadata: [String: String]) async throws {

        let vector = embeddingService.embedText(text)
        try await upsert(id: id, vector: vector, text: text, metadata: metadata)
    }
    
    // MARK: - Batch Processing
    
    /// Process multiple documents efficiently with single persistence call
    func batchUpsertTexts(_ documents: [(id: String, text: String, metadata: [String: String])]) async throws -> BatchResult {

        var successes = 0
        let failures: [String] = []
         
        for (id, text, metadata) in documents {
            let vector = embeddingService.embedText(text)
            let record = VectorRecord(id: id, vector: vector, text: text, metadata: metadata, timestamp: Date())
            vectors[id] = record
            successes += 1
        }
         
        try await saveToFile()
        return BatchResult(successful: successes, failed: failures.count, errors: failures)
    }
    
    // MARK: - Asynchronous Query Operations
    
    /// Get a vector by identifier
    func get(id: String) async -> VectorRecord? {
        return vectors[id]
    }

    /// Find similar vectors using cosine similarity
    func query(vector: [Double], topK: Int = 5) async -> [VectorMatch] {

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

    /// Search for similar text using semantic similarity
    func queryText(text: String, topK: Int = 10) async -> [VectorMatch] {

        let queryVector = embeddingService.embedText(text)
        return await query(vector: queryVector, topK: topK)
    }
    
    /// Returns all vector records
    func queryAll() async -> [VectorRecord] {
        return Array(vectors.values)
    }
    
    // MARK: - Asynchronous Delete Operations
    
    /// Delete a vector based on its identifier and save to file
    func removeAt(id: String) async throws -> Bool {
        
        let existed = vectors.removeValue(forKey: id) != nil
        if existed {
            try await saveToFile()
        }
        return existed
    }
    
    /// Delete all vector records
    func removeAll() async throws {

        let wasEmpty = vectors.isEmpty
        vectors.removeAll()
        
        // Only save if there were actually vectors to remove
        if !wasEmpty {
            try await saveToFile()
        }
    }
    
    // MARK: - Basic Persistence
    
    /// Save all vectors to JSON file
    private func saveToFile() async throws {
        
        do {
            let records = Array(vectors.values)
            let data = try JSONEncoder().encode(records)
            try data.write(to: URL(fileURLWithPath: dataFilePath))
            logger.debug("Successfully saved \(records.count) vectors")
            
        } catch {
            logger.error("Failed to save vectors: \(error)")
            throw error
        }
    }
    
    /// Load vectors from JSON file at startup
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
            
            logger.info("VectorStore loaded successfully")
            logger.info("Loaded \(records.count) vectors")
        } catch {
            logger.error("Failed to load vectors, starting with empty database: \(error)")
            throw error
        }
    }
}
