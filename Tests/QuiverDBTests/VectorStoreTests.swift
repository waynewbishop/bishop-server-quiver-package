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

import XCTest
@testable import QuiverDB

final class VectorStoreUnitTests: VectorStoreTestBase {
    
    // MARK: - Count Tests
    
    func testCountWithEmptyStore() async throws {
        let store = try await createTestVectorStore()
        
        let count = await store.count()
        XCTAssertEqual(count, 0)
    }
    
    func testCountWithStoredVectors() async throws {
        let store = try await createTestVectorStore()
        try await store.upsert(id: "test1", vector: [1.0, 2.0], text: "test", metadata: [:])
        
        let count = await store.count()
        XCTAssertEqual(count, 1)
    }
    
    // MARK: - Upsert Tests
    
    func testUpsertNewVector() async throws {
        let store = try await createTestVectorStore()
        try await store.upsert(id: "vec1", vector: [0.5, 0.8], text: "test vector", metadata: ["type": "test"])
        
        let retrieved = try await store.get(id: "vec1")
        XCTAssertNotNil(retrieved)
        
        if let retrieved = retrieved {
            XCTAssertEqual(retrieved.id, "vec1")
            XCTAssertEqual(retrieved.vector, [0.5, 0.8])
            XCTAssertEqual(retrieved.text, "test vector")
            XCTAssertEqual(retrieved.metadata["type"], "test")
        }
    }
    
    func testUpsertOverwritesExistingVector() async throws {
        let store = try await createTestVectorStore()
        try await store.upsert(id: "vec1", vector: [1.0, 2.0], text: "original", metadata: [:])
        try await store.upsert(id: "vec1", vector: [3.0, 4.0], text: "updated", metadata: ["status": "modified"])
        
        let retrieved = try await store.get(id: "vec1")
        if let retrieved = retrieved {
            XCTAssertEqual(retrieved.vector, [3.0, 4.0])
            XCTAssertEqual(retrieved.text, "updated")
            XCTAssertEqual(retrieved.metadata["status"], "modified")
        }
    }
    
    // MARK: - UpsertText Tests
    
    func testUpsertTextConvertsToVector() async throws {
        let store = try await createTestVectorStore()
        try await store.upsertText(id: "text1", text: "hello world", metadata: ["source": "test"])
        
        let retrieved = try await store.get(id: "text1")
        XCTAssertNotNil(retrieved)
        
        if let retrieved = retrieved {
            XCTAssertEqual(retrieved.text, "hello world")
            XCTAssertFalse(retrieved.vector.isEmpty)
            XCTAssertEqual(retrieved.metadata["source"], "test")
        }
    }
    
    func testUpsertTextCreatesNonZeroVector() async throws {
        let store = try await createTestVectorStore()
        try await store.upsertText(id: "text2", text: "machine learning algorithms", metadata: [:])
        
        let retrieved = try await store.get(id: "text2")
        if let retrieved = retrieved {
            let hasNonZeroElement = retrieved.vector.contains { $0 != 0.0 }
            XCTAssertTrue(hasNonZeroElement)
        }
    }
    
    // MARK: - BatchUpsertTexts Tests
    
    func testBatchUpsertTextsProcessesMultipleDocuments() async throws {
        let store = try await createTestVectorStore()
        let documents: [(id: String, text: String, metadata: [String: String])] = [
            (id: "doc1", text: "first document", metadata: ["batch": "1"]),
            (id: "doc2", text: "second document", metadata: ["batch": "1"]),
            (id: "doc3", text: "third document", metadata: ["batch": "1"])
        ]
        
        let result = try await store.batchUpsertTexts(documents)
        let finalCount = await store.count()
        
        XCTAssertEqual(result.successful, 3)
        XCTAssertEqual(result.failed, 0)
        XCTAssertEqual(finalCount, 3)
    }
    
    func testBatchUpsertTextsReturnsBatchResult() async throws {
        let store = try await createTestVectorStore()
        let documents: [(id: String, text: String, metadata: [String: String])] = [
            (id: "single", text: "lone document", metadata: [:])
        ]
        
        let result = try await store.batchUpsertTexts(documents)
        
        XCTAssertEqual(result.successful, 1)
        XCTAssertEqual(result.failed, 0)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertNotNil(result.timestamp)
    }
    
    // MARK: - Get Tests
    
    func testGetReturnsStoredVector() async throws {
        let store = try await createTestVectorStore()
        try await store.upsert(id: "get_test", vector: [0.1, 0.9], text: "findable", metadata: [:])
        
        let result = try await store.get(id: "get_test")
        XCTAssertNotNil(result)
        
        if let result = result {
            XCTAssertEqual(result.id, "get_test")
        }
    }
    
    func testGetReturnsNilForNonexistentVector() async throws {
        let store = try await createTestVectorStore()
        let result = try await store.get(id: "nonexistent")
        XCTAssertNil(result)
    }
    
    // MARK: - Query Tests
    
    func testQueryReturnsSimilarVectors() async throws {
        let store = try await createTestVectorStore()
        try await store.upsert(id: "similar", vector: [1.0, 0.0], text: "similar vector", metadata: [:])
        try await store.upsert(id: "different", vector: [0.0, 1.0], text: "different vector", metadata: [:])
        
        let results = try await store.query(vector: [1.0, 0.0], topK: 2)
        
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].id, "similar") // Should be most similar
        XCTAssertGreaterThan(results[0].score, results[1].score)
    }
    
    func testQueryRespectsTopKLimit() async throws {
        let store = try await createTestVectorStore()
        try await store.upsert(id: "vec1", vector: [1.0, 0.0], text: "first", metadata: [:])
        try await store.upsert(id: "vec2", vector: [0.8, 0.2], text: "second", metadata: [:])
        try await store.upsert(id: "vec3", vector: [0.0, 1.0], text: "third", metadata: [:])
        
        let results = try await store.query(vector: [1.0, 0.0], topK: 2)
        XCTAssertEqual(results.count, 2)
    }
    
    // MARK: - QueryText Tests
    
    func testQueryTextFindsSemanticallySimilarContent() async throws {
        let store = try await createTestVectorStore()
        try await store.upsertText(id: "tech", text: "computer programming software", metadata: [:])
        try await store.upsertText(id: "food", text: "cooking recipes ingredients", metadata: [:])
        
        let results = try await store.queryText(text: "coding development", topK: 2)
        
        XCTAssertEqual(results.count, 2)
        // Technology content should be more similar to "coding development"
        XCTAssertEqual(results[0].id, "tech")
    }
    
    func testQueryTextReturnsOrderedResults() async throws {
        let store = try await createTestVectorStore()
        try await store.upsertText(id: "exact", text: "machine learning", metadata: [:])
        try await store.upsertText(id: "related", text: "artificial intelligence", metadata: [:])
        
        let results = try await store.queryText(text: "machine learning", topK: 2)
        
        XCTAssertGreaterThanOrEqual(results[0].score, results[1].score)
    }
    
    // MARK: - QueryAll Tests
    
    func testQueryAllReturnsAllStoredVectors() async throws {
        let store = try await createTestVectorStore()
        try await store.upsert(id: "vec1", vector: [1.0, 0.0], text: "first", metadata: [:])
        try await store.upsert(id: "vec2", vector: [0.0, 1.0], text: "second", metadata: [:])
        
        let results = try await store.queryAll()
        XCTAssertEqual(results.count, 2)
        
        let ids = results.map { $0.id }.sorted()
        XCTAssertEqual(ids, ["vec1", "vec2"])
    }
    
    func testQueryAllReturnsEmptyArrayWhenEmpty() async throws {
        let store = try await createTestVectorStore()
        let results = try await store.queryAll()
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - RemoveAt Tests
    
    func testRemoveAtDeletesExistingVector() async throws {
        let store = try await createTestVectorStore()
        try await store.upsert(id: "to_delete", vector: [1.0, 2.0], text: "deletable", metadata: [:])
        
        let deleted = try await store.removeAt(id: "to_delete")
        XCTAssertTrue(deleted)
        
        let retrieved = try await store.get(id: "to_delete")
        XCTAssertNil(retrieved)
    }
    
    func testRemoveAtReturnsFalseForNonexistent() async throws {
        let store = try await createTestVectorStore()
        let deleted = try await store.removeAt(id: "nonexistent")
        XCTAssertFalse(deleted)
    }
    
    // MARK: - RemoveAll Tests
    
    func testRemoveAllClearsAllVectors() async throws {
        let store = try await createTestVectorStore()
        try await store.upsert(id: "vec1", vector: [1.0, 0.0], text: "first", metadata: [:])
        try await store.upsert(id: "vec2", vector: [0.0, 1.0], text: "second", metadata: [:])
        
        try await store.removeAll()
        
        let finalCount = await store.count()
        let results = try await store.queryAll()
        
        XCTAssertEqual(finalCount, 0)
        XCTAssertTrue(results.isEmpty)
    }
    
    func testRemoveAllOnEmptyStore() async throws {
        let store = try await createTestVectorStore()
        try await store.removeAll()
        
        let finalCount = await store.count()
        XCTAssertEqual(finalCount, 0)
    }
}
