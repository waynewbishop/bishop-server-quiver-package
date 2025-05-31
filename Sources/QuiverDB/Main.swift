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
        
        // This will execute after Control-C and graceful shutdown
        try await serviceGroup.run()
        
        // Log after shutdown completes
        app.logger.notice("QuiverDB server shutdown completed successfully")
    }
}

// Simple service implementation
struct ServerService: Service {
    var app: Application
    
    func run() async throws {
        try await app.execute()
    }
}

/// Server configuration
func configServer() async throws -> (Application, ServiceGroup) {
    
    let logger = Logger(label: "bishop.server.quiver.package")
    logger.notice("[QuiverDB] Server started. Use Control+C to shut down gracefully.")
    
    let app = try await Vapor.Application.make()
    
    let serverService = ServerService(app: app)
    let serviceGroup = ServiceGroup(
        services: [serverService],
        gracefulShutdownSignals: [.sigint, .sigquit],
        cancellationSignals: [.sigterm],
        logger: logger
    )
    
    logger.notice("[QuiverDB] Starting service group")
    return (app, serviceGroup)
}
