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
       
       app.logger.notice("[QuiverDB] Starting service group. Press ctrl+c to shutdown")
       try await serviceGroup.run()
       
       app.logger.notice("[QuiverDB] Server shutdown completed successfully")
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
   let app = try await Vapor.Application.make()
   
   // Configure middleware
   app.middleware.use(LoggingMiddleware(logger: logger))
   app.middleware.use(ErrorHandlingMiddleware())
   
   let serverService = ServerService(app: app)
   let serviceGroup = ServiceGroup(
       services: [serverService],
       gracefulShutdownSignals: [.sigint, .sigterm],
       cancellationSignals: [.sigquit],
       logger: logger
   )
   
   logger.notice("[QuiverDB] Server configured, ready to start")
   return (app, serviceGroup)
}
