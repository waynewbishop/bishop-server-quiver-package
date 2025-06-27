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
import Vapor

final class VectorRoutes: Sendable {
    private let vectorStore: VectorStore
    private let logger = Logger(label: "bishop.server.quiver.package")
    
    init(vectorStore: VectorStore) {
        self.vectorStore = vectorStore
    }
    
    func routes(_ app: Application) {
        // Simple route: GET /vectors/{id}
        app.get("vectors", ":id") { req in
            try await self.getVector(req: req)
        }        
    }    

    /// GET /vectors/{id} - Retrieve vector by ID
    func getVector(req: Request) async throws -> VectorRecord {
        // 1. Extract the ID from the URL path
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Missing vector ID")
        }
        
        // 2. Query the vector store (this calls your actor method)
        guard let record = await vectorStore.get(id: id) else {
            throw Abort(.notFound, reason: "Vector with ID '\(id)' not found")
        }
        
        // 3. Return the record (Vapor automatically converts to JSON)
        return record
    }

    
}
