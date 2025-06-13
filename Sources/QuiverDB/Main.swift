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

import Vapor
import OpenAPIRuntime
import OpenAPIVapor
import Logging
import ServiceLifecycle

@main
struct Entrypoint {
   static func main() async throws {
       let (app, serviceGroup) = try await configServer()
       
       app.logger.notice("Starting service group. Press ctrl+c to shutdown")
       try await serviceGroup.run()
       
       app.logger.notice("Server shutdown completed successfully")
   }
}

// Simple service implementation
struct ServerService: Service {
   var app: Application
   
   func run() async throws {
       try await app.execute()
   }
}


func configServer() async throws -> (Application, ServiceGroup) {
    let logger = Logger(label: "bishop.server.quiver.package")
    let app = try await Vapor.Application.make()
    
    // Configure middleware
    app.middleware.use(LoggingMiddleware(logger: logger))
    app.middleware.use(ErrorHandlingMiddleware())
    
    //load GloVeService
    logger.info("Loading GloVeService..")
    let glove = try await GloVeService()

    //start persistent store
    logger.info("Staring VectorStore..")
    let vectorStore = try await VectorStore(embeddingService: glove)
    
    // Test with unique IDs
    try await vectorStore.upsertText(
        id: "doc1",
        text: "parrots and budgies are birds and pets",
        metadata: ["category": "animals"]
    )

    try await vectorStore.upsertText(
        id: "doc2",  // Different ID
        text: "cars and trucks are vehicles",
        metadata: ["category": "transportation"]
    )

    try await vectorStore.upsertText(
        id: "doc3",  // Different ID
        text: "roses and tulips are flowers",
        metadata: ["category": "plants"]
    )
    
    
    try await vectorStore.upsertText(
        id: "doc4",  // Different ID
        text: "Addidas and Nike are sports brands",
        metadata: ["category": "shoes"]
    )
    

    let count = await vectorStore.count()
    logger.info("Total documents: \(count)")
    
    
    let results = try await vectorStore.queryText(text: "cars", topK: 2)

    for match in results {
        print("ID: \(match.id)")
        print("Score: \(match.score)")
        print("Text: \(match.text)")
        print("Metadata: \(match.metadata)")
        print("---")
    }
    
    //remove an vectorStore item
    let result = try await vectorStore.removeAt(id: "doc1")
    
    if result {
        logger.info("Deleted document 'doc1'")
    } else {
        logger.warning("Failed to delete document 'doc1'")
    }
    
    
    // Add a simple test route so the server has something to serve
    app.get("health") { req in
        return "QuiverDB Server is running!"
    }
            
    let serverService = ServerService(app: app)
    let serviceGroup = ServiceGroup(
        services: [serverService],
        gracefulShutdownSignals: [.sigint, .sigterm],
        cancellationSignals: [.sigquit],
        logger: logger
    )
    
    logger.notice("Server configured, ready to start")
    return (app, serviceGroup)
}

