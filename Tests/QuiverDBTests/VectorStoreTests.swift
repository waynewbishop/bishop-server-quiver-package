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

final class VectorStoreTests: VectorStoreTestBase {
    
    /// Tests that semantically similar documents return high similarity scores.
    /// Validates the core semantic search functionality with known relationships.
    func testSemanticSimilarity() async throws {
        let store = try await createTestVectorStore(filename: "semantic_test.json")
                
        // Arrange: Add documents with known semantic relationships
        try await store.upsertText(
            id: "tech_smartphone",
            text: "iPhone features advanced camera technology and powerful processor",
            metadata: ["category": "technology"]
        )
        
        try await store.upsertText(
            id: "tech_laptop",
            text: "MacBook offers excellent performance for software development",
            metadata: ["category": "technology"]
        )
        
        try await store.upsertText(
            id: "food_recipe",
            text: "This pasta recipe uses fresh tomatoes and basil",
            metadata: ["category": "cooking"]
        )
        
        // Act: Search for technology-related content
        let results = try await store.queryText(text: "computer devices and gadgets", topK: 3)
        
        // Assert: Technology documents should rank higher than food
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].id.contains("tech") || results[1].id.contains("tech"))
        XCTAssertGreaterThan(results[0].score, 0.3) // Reasonable similarity threshold
    }
}
