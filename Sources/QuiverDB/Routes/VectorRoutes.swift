import Foundation
import Vapor
import Logging


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
