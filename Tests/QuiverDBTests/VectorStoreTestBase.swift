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

/// Base class providing isolated temporary directory setup for VectorStore testing.
/// Ensures each test runs with a clean file system environment and automatic cleanup.
class VectorStoreTestBase: XCTestCase {
    var testDirectory: URL?
    
    /// Creates a unique temporary directory for test file isolation.
    /// Establishes a clean testing environment with UUID-based directory naming.
    override func setUpWithError() throws {
        
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuiverDBTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDir,
                                               withIntermediateDirectories: true)
        self.testDirectory = tempDir
    }
    
    /// Removes the temporary test directory and all contained files.
    /// Ensures no test artifacts persist between test runs.
    override func tearDownWithError() throws {
        if let testDirectory = testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
    }
    
    /// Creates a VectorStore instance with GloVe embeddings in the isolated test directory.
    /// Provides a fully configured vector database for semantic search testing.
    func createTestVectorStore(filename: String = "test_vectors.json") async throws -> VectorStore {
        guard let testDirectory = testDirectory else {
            throw TestError.testDirectoryNotInitialized
        }
        
        let testFilePath = testDirectory.appendingPathComponent(filename).path
        let glove = try await GloVeService()
        return try await VectorStore(embeddingService: glove, dataFilePath: testFilePath)
    }
}

/// Errors that can occur during VectorStore test setup and execution.
/// Provides clear error handling for test infrastructure failures.
enum TestError: Error {
    /// Thrown when attempting to use test directory before proper initialization.
    /// Indicates a test setup failure that prevents VectorStore creation.
    case testDirectoryNotInitialized
}
