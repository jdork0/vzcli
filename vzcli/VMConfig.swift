//
// Copyright © 2026 Jason Kelly. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// See LICENSE file
//

import Foundation

struct VMConfig {
    var vmName: String
    var cpus: Int
    var ramMB: UInt64
    var headless: Bool
    var resolution: String
    var vmDir: String
    var netConf: String
    var directoryShares: String
    var initImg: String
    var initDiskSizeGB: UInt64
    var recovery: Bool
    var captureSystemKeys: Bool
    var autoResizeDisplay: Bool
    var useTrackpad: Bool

    init(vmName: String = "", cpus: Int = 4, ramMB: UInt64 = 8192, headless: Bool = false,
         resolution: String = "1280x800x224", vmDir: String, netConf: String = "user",
         directoryShares: String = "", initImg: String = "", initDiskSizeGB: UInt64 = 64,
         recovery: Bool = false, captureSystemKeys: Bool = false, autoResizeDisplay: Bool = false,
         useTrackpad: Bool = false) {
        self.vmName = vmName
        self.cpus = cpus
        self.ramMB = ramMB
        self.headless = headless
        self.resolution = resolution
        self.vmDir = vmDir
        self.netConf = netConf
        self.directoryShares = directoryShares
        self.initImg = initImg
        self.initDiskSizeGB = initDiskSizeGB
        self.recovery = recovery
        self.captureSystemKeys = captureSystemKeys
        self.autoResizeDisplay = autoResizeDisplay
        self.useTrackpad = useTrackpad
    }
}
