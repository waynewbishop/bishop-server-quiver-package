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


/// Global actor that safely manages the expensive GloVe embedding service across all tests.
/// This prevents the 7-second initialization from happening multiple times while ensuring thread safety.
@globalActor
actor ServiceActor {
    
    static let shared = ServiceActor()    
    private var embeddingService: GloVeService?
    
    /// Lazy initialization pattern - creates service once and reuses it for all tests
    func getOrCreateService() throws -> GloVeService {
        if let existing = embeddingService {
            return existing
        }
        
        let service = try GloVeService()
        embeddingService = service
        print("GloVe service loaded successfully for testing")
        return service
    }
    
    func cleanup() {
        embeddingService = nil
    }
    
    func isServiceAvailable() -> Bool {
        return embeddingService != nil
    }
}