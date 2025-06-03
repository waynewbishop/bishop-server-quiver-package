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
import Logging

struct LoggingMiddleware: AsyncMiddleware {
    let logger: Logger
    
    init(logger: Logger = Logger(label: "com.middleware.logging")) {
        self.logger = logger
    }
    
    /// Processes HTTP requests through middleware chain while logging request timing and status.
    /// Captures start time, forwards the request to the next responder, then logs completion details.
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let start = Date()
        logger.info("\(request.method) \(request.url.path) - Started")
        
        do {
            let response = try await next.respond(to: request)
            let elapsed = Date().timeIntervalSince(start)
            
            logger.info("\(request.method) \(request.url.path) - Completed \(response.status.code) (\(String(format: "%.2f", elapsed*1000))ms)")
            return response
        } catch {
            logger.error("\(request.method) \(request.url.path) - Failed: \(error)")
            throw error
        }
    }
}
