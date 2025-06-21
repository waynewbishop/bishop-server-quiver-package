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
@testable import QuiverDBApp


//Per-test instances - deliberately not static to ensure test isolation
final class VectorStoreTests: XCTestCase {
    
    private var vectorStore: VectorStore?
    private var tempDataPath: String?
    
    // MARK: - Class-Level Setup

    //Called before each test
    override class func setUp() {
        super.setUp()
        
        // Pre-load the expensive embedding service asynchronously during class setup
        // This handles the 7-second GloVe initialization once for all tests
        Task {
            do {
                _ = try await ServiceActor.shared.getOrCreateService()
            } catch {
                print("Failed to initialize GloVe service during class setup: \(error)")
            }
        }
    }
    
    override class func tearDown() {
        // Clean up shared resources when all tests complete
        Task {
            await ServiceActor.shared.cleanup()
        }
        super.tearDown()
    }
    
    // MARK: - Per-Test Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Get the shared embedding service - actor ensures thread-safe access
        let embeddingService = try await ServiceActor.shared.getOrCreateService()
        
        // Create isolated temporary storage for this specific test
        tempDataPath = NSTemporaryDirectory() + "test_vectors_\(UUID().uuidString).json"
        
        guard let dataPath = tempDataPath else {
            throw XCTestError(.failureWhileWaiting,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to create temporary data path"])
        }
        
        // Each test gets a fresh VectorStore with shared service but isolated storage
        vectorStore = try await VectorStore(
            embeddingService: embeddingService,
            dataFilePath: dataPath
        )
    }
    
    override func tearDown() async throws {
        // Clean up test-specific resources - ensures no test interference
        if let tempPath = tempDataPath {
            try? FileManager.default.removeItem(atPath: tempPath)
        }
        
        vectorStore = nil
        tempDataPath = nil
        
        try await super.tearDown()
    }

        // MARK: - Count Property Tests

    func testCountWithRecords() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Start with empty store
        let initialCount = await store.count
        XCTAssertEqual(initialCount, 0)
        
        // Add records and verify count increases
        try await store.upsertText(id: "doc1", text: "machine learning", metadata: ["type": "AI"])
        let countAfterFirst = await store.count
        XCTAssertEqual(countAfterFirst, 1)
        
        try await store.upsertText(id: "doc2", text: "swift programming", metadata: ["type": "code"])
        let finalCount = await store.count
        XCTAssertEqual(finalCount, 2)
    }

    func testCountAfterDeletion() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Add records
        try await store.upsertText(id: "doc1", text: "machine learning", metadata: ["type": "AI"])
        try await store.upsertText(id: "doc2", text: "swift programming", metadata: ["type": "code"])
        let countAfterAdding = await store.count
        XCTAssertEqual(countAfterAdding, 2)
        
        // Remove one and verify count decreases
        _ = try await store.removeAt(id: "doc1")
        let finalCount = await store.count
        XCTAssertEqual(finalCount, 1)
    }

    // MARK: - IsEmpty Property Tests

    func testIsEmptyInitially() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Store should start empty
        let initialEmpty = await store.isEmpty
        XCTAssertTrue(initialEmpty)
        
        // Add a record and verify not empty
        try await store.upsertText(id: "doc1", text: "test content", metadata: [:])
        let afterAdding = await store.isEmpty
        XCTAssertFalse(afterAdding)
    }

    func testIsEmptyAfterClear() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Add records
        try await store.upsertText(id: "doc1", text: "machine learning", metadata: ["type": "AI"])
        try await store.upsertText(id: "doc2", text: "swift programming", metadata: ["type": "code"])
        let beforeClear = await store.isEmpty
        XCTAssertFalse(beforeClear)
        
        // Clear all and verify empty
        try await store.removeAll()
        let afterClear = await store.isEmpty
        XCTAssertTrue(afterClear)
    }

    // MARK: - Exists Method Tests

    func testExistsWithValidID() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Add record
        try await store.upsertText(id: "doc1", text: "machine learning", metadata: ["type": "AI"])
        
        // Verify exists
        let exists = await store.exists(id: "doc1")
        let notExists = await store.exists(id: "nonexistent")
        XCTAssertTrue(exists)
        XCTAssertFalse(notExists)
    }

    func testExistsAfterRemoval() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Add and verify exists
        try await store.upsertText(id: "doc1", text: "machine learning", metadata: ["type": "AI"])
        let existsBeforeRemoval = await store.exists(id: "doc1")
        XCTAssertTrue(existsBeforeRemoval)
        
        // Remove and verify doesn't exist
        _ = try await store.removeAt(id: "doc1")
        let existsAfterRemoval = await store.exists(id: "doc1")
        XCTAssertFalse(existsAfterRemoval)
    }

    // MARK: - Upsert Method Tests

    func testUpsertNewRecord() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        let testVector = [0.1, 0.2, 0.3, 0.4, 0.5]
        try await store.upsert(id: "vec1", vector: testVector, text: "test content", metadata: ["category": "test"])
        
        let record = await store.get(id: "vec1")
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.vector, testVector)
        XCTAssertEqual(record?.text, "test content")
        XCTAssertEqual(record?.metadata["category"], "test")
    }

    func testUpsertUpdateRecord() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Initial upsert
        let vector1 = [0.1, 0.2, 0.3]
        try await store.upsert(id: "vec1", vector: vector1, text: "original", metadata: ["version": "1"])
        
        // Update same ID
        let vector2 = [0.4, 0.5, 0.6]
        try await store.upsert(id: "vec1", vector: vector2, text: "updated", metadata: ["version": "2"])
        
        let record = await store.get(id: "vec1")
        XCTAssertEqual(record?.vector, vector2)
        XCTAssertEqual(record?.text, "updated")
        XCTAssertEqual(record?.metadata["version"], "2")
    }

    // MARK: - UpsertText Method Tests

    func testUpsertTextSuccess() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        try await store.upsertText(id: "doc1", text: "machine learning algorithms", metadata: ["domain": "AI"])
        
        let record = await store.get(id: "doc1")
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.text, "machine learning algorithms")
        XCTAssertEqual(record?.metadata["domain"], "AI")
        XCTAssertFalse(record?.vector.isEmpty ?? true)
    }

    func testUpsertTextEmptyContent() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        try await store.upsertText(id: "empty", text: "", metadata: ["type": "empty"])
        
        let record = await store.get(id: "empty")
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.text, "")
        XCTAssertEqual(record?.metadata["type"], "empty")
    }

    // MARK: - BatchUpsertTexts Method Tests

    func testBatchUpsertTextsSuccess() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        let documents = [
            (id: "batch1", text: "machine learning", metadata: ["type": "AI"]),
            (id: "batch2", text: "swift programming", metadata: ["type": "code"]),
            (id: "batch3", text: "data science", metadata: ["type": "analytics"])
        ]
        
        let result = try await store.batchUpsertTexts(documents)
        
        XCTAssertEqual(result.successful, 3)
        XCTAssertEqual(result.failed, 0)
        
        let finalCount = await store.count
        XCTAssertEqual(finalCount, 3)
    }

    func testBatchUpsertTextsEmpty() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        let emptyDocuments: [(id: String, text: String, metadata: [String: String])] = []
        let result = try await store.batchUpsertTexts(emptyDocuments)
        
        XCTAssertEqual(result.successful, 0)
        XCTAssertEqual(result.failed, 0)
        
        let finalCount = await store.count
        XCTAssertEqual(finalCount, 0)
    }

    // MARK: - Get Method Tests

    func testGetVectorByID() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Create two test records
        try await store.upsertText(id: "doc1", text: "machine learning", metadata: ["type": "AI"])
        try await store.upsertText(id: "doc2", text: "swift programming", metadata: ["type": "code"])
        
        // Retrieve one record by ID
        let record = await store.get(id: "doc1")
        
        // Verify the essentials
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.id, "doc1")
        XCTAssertEqual(record?.text, "machine learning")
    }

    func testGetNonexistentVector() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Try to get record that doesn't exist
        let record = await store.get(id: "nonexistent")
        XCTAssertNil(record)
        
        // Add a record and try to get different ID
        try await store.upsertText(id: "doc1", text: "test", metadata: [:])
        let anotherRecord = await store.get(id: "doc2")
        XCTAssertNil(anotherRecord)
    }

    // MARK: - Query Method Tests

    func testQueryWithResults() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Create test records
        try await store.upsertText(id: "doc1", text: "machine learning", metadata: ["type": "AI"])
        try await store.upsertText(id: "doc2", text: "swift programming", metadata: ["type": "code"])
        
        // Get a vector to query with
        let targetRecord = await store.get(id: "doc1")
        guard let queryVector = targetRecord?.vector else {
            XCTFail("Should have vector for query")
            return
        }
        
        let results = await store.query(vector: queryVector, topK: 2)
        XCTAssertFalse(results.isEmpty)
        XCTAssertLessThanOrEqual(results.count, 2)
    }

    func testQueryEmptyStore() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        let queryVector = [0.1, 0.2, 0.3, 0.4, 0.5]
        let results = await store.query(vector: queryVector, topK: 5)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - QueryText Method Tests

    func testQuerySimilarVectors() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Create test records with different content
        try await store.upsertText(id: "doc1", text: "machine learning algorithms", metadata: ["type": "AI"])
        try await store.upsertText(id: "doc2", text: "swift programming language", metadata: ["type": "code"])
        try await store.upsertText(id: "doc3", text: "artificial intelligence models", metadata: ["type": "AI"])
        
        // Query for AI-related content
        let results = await store.queryText(text: "machine learning", topK: 2)
        
        // Verify query returns results
        XCTAssertFalse(results.isEmpty, "Query should return results")
        XCTAssertLessThanOrEqual(results.count, 2, "Should respect topK limit")
        
        // Verify results are sorted by similarity (highest first)
        if results.count > 1 {
            XCTAssertGreaterThanOrEqual(results[0].score, results[1].score, "Results should be sorted by similarity")
        }
        
        // Verify the most similar result
        XCTAssertEqual(results.first?.id, "doc1", "Most similar should be the exact match")
    }

    func testQueryTextWithTopK() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Create multiple records
        for i in 1...5 {
            try await store.upsertText(id: "doc\(i)", text: "content \(i)", metadata: ["index": "\(i)"])
        }
        
        let results = await store.queryText(text: "content", topK: 3)
        XCTAssertLessThanOrEqual(results.count, 3)
        XCTAssertGreaterThan(results.count, 0)
    }

    // MARK: - QueryAll Method Tests

    func testQueryAllWithRecords() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Add test records
        try await store.upsertText(id: "doc1", text: "machine learning", metadata: ["type": "AI"])
        try await store.upsertText(id: "doc2", text: "swift programming", metadata: ["type": "code"])
        
        let allRecords = await store.queryAll()
        XCTAssertEqual(allRecords.count, 2)
        
        let ids = allRecords.map { $0.id }
        XCTAssertTrue(ids.contains("doc1"))
        XCTAssertTrue(ids.contains("doc2"))
    }

    func testQueryAllEmpty() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        let allRecords = await store.queryAll()
        XCTAssertTrue(allRecords.isEmpty)
    }

    // MARK: - RemoveAt Method Tests

    func testRemoveAtExisting() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Add record
        try await store.upsertText(id: "doc1", text: "machine learning", metadata: ["type": "AI"])
        let countAfterAdd = await store.count
        XCTAssertEqual(countAfterAdd, 1)
        
        // Remove it
        let removed = try await store.removeAt(id: "doc1")
        XCTAssertTrue(removed)
        
        let countAfterRemove = await store.count
        XCTAssertEqual(countAfterRemove, 0)
        
        let record = await store.get(id: "doc1")
        XCTAssertNil(record)
    }

    func testRemoveAtNonexistent() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Try to remove from empty store
        let removed1 = try await store.removeAt(id: "nonexistent")
        XCTAssertFalse(removed1)
        
        // Add record and try to remove different ID
        try await store.upsertText(id: "doc1", text: "test", metadata: [:])
        let removed2 = try await store.removeAt(id: "doc2")
        XCTAssertFalse(removed2)
        
        let finalCount = await store.count
        XCTAssertEqual(finalCount, 1)
    }

    // MARK: - RemoveAll Method Tests

    func testRemoveAllWithRecords() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Add multiple records
        try await store.upsertText(id: "doc1", text: "machine learning", metadata: ["type": "AI"])
        try await store.upsertText(id: "doc2", text: "swift programming", metadata: ["type": "code"])
        let countAfterAdd = await store.count
        XCTAssertEqual(countAfterAdd, 2)
        
        // Remove all
        try await store.removeAll()
        let finalCount = await store.count
        XCTAssertEqual(finalCount, 0)
        
        let isEmpty = await store.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func testRemoveAllEmpty() async throws {
        guard let store = self.vectorStore else {
            XCTFail("VectorStore should be initialized")
            return
        }
        
        // Remove all from empty store
        let initialEmpty = await store.isEmpty
        XCTAssertTrue(initialEmpty)
        
        try await store.removeAll()
        
        let finalEmpty = await store.isEmpty
        XCTAssertTrue(finalEmpty)
        
        let finalCount = await store.count
        XCTAssertEqual(finalCount, 0)
    }

}
