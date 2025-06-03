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

struct ErrorHandlingMiddleware: AsyncMiddleware {
    let logger: Logger
    
    init(logger: Logger = Logger(label: "com.middleware.error-handling")) {
        self.logger = logger
    }
    
    /// Processes HTTP requests through middleware chain, catching and logging
    /// errors while transforming them into appropriate HTTP responses.
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            if let abort = error as? Abort {
                logger.error("Request aborted: \(abort.reason) (Status: \(abort.status.code))")
                return Response(status: abort.status,
                               body: .init(string: abort.reason))
            } else {
                logger.error("Unhandled server error: \(error)")
                return Response(status: .internalServerError,
                               body: .init(string: "An internal server error occurred"))
            }
        }
    }
}
