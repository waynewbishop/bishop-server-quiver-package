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
    
    // MARK: Class-Level Setup

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
    
    // MARK: Per-Test Setup
    
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

    //MARK: Retrieval Tests

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

}
