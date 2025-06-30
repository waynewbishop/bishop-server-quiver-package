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
    private let logger = Logger(label: "bishop.server.quiver.package.routes")
    private let container: GloVeContainer
    private let path: String = "vectors.json"
    
    init(container: GloVeContainer) {
        self.container = container
    }
    
    func routes(_ app: Application) {
        app.get("vectors", ":id") { req in
            try await self.getVector(req: req)
        }
    }
    
    func getVector(req: Request) async throws -> VectorRecord {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Missing vector ID")
        }
        
        // Create VectorStore using stored container
        let vectorStore = try await VectorStore(
            embeddingService: container.embeddingService,
            dataFilePath: self.path
        )
        
        guard let record = await vectorStore.get(id: id) else {
            throw Abort(.notFound, reason: "Vector with ID '\(id)' not found")
        }
        
        return record
    }
}