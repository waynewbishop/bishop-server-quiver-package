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

struct BatchResult: Codable {
    let successful: Int
    let failed: Int
    let errors: [String]
    let timestamp: Date
    
    init(successful: Int, failed: Int, errors: [String]) {
        self.successful = successful
        self.failed = failed
        self.errors = errors
        self.timestamp = Date()
    }
}
